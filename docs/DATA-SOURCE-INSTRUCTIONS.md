# PostgreSQL Security Monitoring Data Source

## 📝 Data Source Description (800 chars)

Real-time PostgreSQL security and performance monitoring database with ML anomaly detection capabilities.

**Primary Tables**:
- `bronze_pssql_alllogs_nometrics`: Raw logs (connections, audits, errors) from Azure PostgreSQL
- `postgres_activity_metrics`: 5-min ML metrics with temporal dimensions for baseline detection
- `postgres_error_metrics`: Per-minute error aggregations
- `postgres_user_metrics`: Hourly per-user query patterns

**Key Capabilities**: Security threat detection (brute force, SQL injection, privilege escalation, data exfiltration), ML-based anomaly detection, compliance auditing, performance monitoring.

**Data Freshness**: Real-time (1-5 sec latency). Requires pgaudit extension for query auditing.

**Best For**: Security analysts, compliance teams, database administrators investigating threats and anomalies.

---

## 📋 Data Source Instructions (15,000 chars)

### 1. Table Schemas

**bronze_pssql_alllogs_nometrics** (Raw Logs - Real-time Stream)

| Column | Type | Usage |
|--------|------|-------|
| `EventProcessedUtcTime` | datetime | **USE FOR ALL TIME FILTERS** (1-5s latency) |
| `message` | string | Full log text (extract user, database, query) |
| `errorLevel` | string | LOG, WARNING, ERROR, FATAL, PANIC |
| `sqlerrcode` | string | PostgreSQL error code (00000 = success) |
| `processId` | long | **Session ID - join key for correlating logs** |
| `backend_type` | string | "client backend" (user), autovacuum, etc. |
| `LogicalServerName` | string | PostgreSQL server name |
| `category` | string | Always "PostgreSQLLogs" |

**postgres_activity_metrics** (ML Metrics - 5-min Aggregates)

| Column | Type | Description |
|--------|------|-------------|
| `Timestamp` | datetime | 5-min bucket |
| `ServerName` | string | Server identifier |
| `HourOfDay` | int | 0-23 (detect off-hours activity) |
| `DayOfWeek` | int | 0=Sunday, 6=Saturday |
| `ActivityCount` | long | Total events |
| `UniqueUsers` | long | Distinct users (cardinality anomaly) |
| `SelectOps` | long | SELECT/COPY operations (exfiltration) |
| `WriteOps` | long | INSERT/UPDATE/DELETE |
| `DDLOps` | long | CREATE/DROP/ALTER (schema changes) |
| `PrivilegeOps` | long | **🔴 CRITICAL: GRANT/REVOKE/ALTER ROLE** |
| `Errors` | long | Error count |

**postgres_error_metrics** (1-min errorRate by type)
**postgres_user_metrics** (1-hour queryCount by user)

### 2. Critical Query Patterns

**Session Correlation** (Required for user/database context):
```kql
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "connection authorized"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| summarize User = any(UserName), Database = any(DatabaseName), SourceHost = any(ClientHost)
    by processId, LogicalServerName;

// Then join AUDIT logs
bronze_pssql_alllogs_nometrics
| join kind=leftouter sessionInfo on processId, LogicalServerName
```

**Why?** AUDIT logs contain query details but NOT user/database/host. CONNECTION logs provide context but lack queries.

**Extract Patterns**:
- User: `extract(@"user=([^\s,]+)", 1, message)`
- Database: `extract(@"database=([^\s,]+)", 1, message)`
- Host: `extract(@"host=([^\s]+)", 1, message)`
- Query: `trim('"', extract(@",,,([^<]+)<", 1, message))`

**⚠️ KQL Rules** (causes errors):
- ❌ `arg_max()` or `any()` → Use `take_any()` instead
- ❌ `extract(..., typeof(string))` → Use `extract(@"pattern", 1, message)` only
- ✅ Filter time FIRST: `| where EventProcessedUtcTime >= ago(24h)`

### 3. Common Queries

**Brute Force (Failed Auth)**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where (tostring(sqlerrcode) startswith "28" and tostring(sqlerrcode) != "28000")
      or (tostring(sqlerrcode) == "28000" and tolower(errorLevel) in ("error", "fatal"))
      or (tolower(errorLevel) in ("error", "fatal") and message contains "authentication")
| extend ClientHost = extract(@"host=([^\s]+)", 1, message)
| summarize FailedAttempts = count(), ErrorCodes = make_set(tostring(sqlerrcode)) by ClientHost = coalesce(ClientHost, "UNKNOWN"), LogicalServerName
| extend Severity = case(
    FailedAttempts > 20, "🔴 CRITICAL",
    FailedAttempts > 10, "🟠 HIGH",
    FailedAttempts > 5, "🟡 MEDIUM",
    "ℹ️ LOW"
)
| order by FailedAttempts desc
```
Detects PostgreSQL auth errors (28xxx codes). Error code 28000 with ERROR/FATAL level = failed authentication.

**Data Exfiltration (Excessive SELECT)**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:" and message has_any ("SELECT", "COPY")
| extend UserName = extract(@"user=([^\s,]+)", 1, message)
| summarize SelectCount = count() by UserName
| where SelectCount > 15
```
Threshold: >15 in 1 hour = CRITICAL

**Privilege Operations** (GRANT/REVOKE):
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message has_any ("GRANT", "REVOKE", "ALTER ROLE", "CREATE ROLE")
| extend UserName = extract(@"user=([^\s,]+)", 1, message)
| summarize Operations = count() by UserName, LogicalServerName
| where Operations > 0
```
Threshold: >0 = CRITICAL (any privilege op)

**Error Spike**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
| where errorLevel in ("ERROR", "FATAL", "PANIC")
| summarize ErrorCount = count() by bin(EventProcessedUtcTime, 1m)
| where ErrorCount > 15
```
Threshold: >15/min = CRITICAL

**ML Anomaly Detection**:
```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| make-series ActivitySeries = sum(ActivityCount) default=0 on Timestamp step 5m by ServerName
| extend (anomalies, score, baseline) = series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
| mv-expand Timestamp to typeof(datetime), ActivitySeries to typeof(long), anomalies to typeof(int), score to typeof(double), baseline to typeof(double)
| where anomalies != 0
```
Returns: `anomalies = 1` (spike), `anomalies = -1` (drop), `score` (deviation magnitude)

### 4. Filtering & Optimization

**Always filter by time FIRST** for query performance:
```kql
| where EventProcessedUtcTime >= ago(24h)  // 1h for real-time, 24h for investigations, 7d+ for ML training
```

**Exclude internal processes**:
```kql
| where backend_type == "client backend"  // Only user connections
| where FinalUser != "azuresu"  // Exclude Azure system user
```

**Error Code Reference**:
- 28000 = Invalid authorization (auth failed when ERROR/FATAL level)
- 28P01 = Invalid password (specific subcode of 28000)
- 42501 = Permission denied (unauthorized access)
- 42P01 = Undefined table (table not found)
- 53300 = Too many connections (DoS/pool exhaustion)
- 08006 = Connection lost (network issue)
- 57P03 = Cannot connect now (server shutting down)
- 58P01 = Undefined file (internal error)

### 5. Message Formats

**CONNECTION**: `"connection authorized: user=USERNAME database=DBNAME host=IP ..."`
Extract via: `extract(@"user=([^\s,]+)", 1, message)`

**AUDIT**: `"AUDIT: SESSION,<pid>,<seq>,<operation>,<statement>,<object>,,,<query>"`
Operations: READ (SELECT/COPY), WRITE (INSERT/UPDATE/DELETE), DDL, MISC

**ERROR**: `errorLevel="ERROR"` + `sqlerrcode` + message context
Levels: LOG < WARNING < ERROR < FATAL < PANIC

### 6. Data Limitations

- **No AUDIT logs?** Enable pgaudit: `shared_preload_libraries = 'pgaudit'` + restart
- **User always UNKNOWN?** Enable `log_connections = on` OR widen sessionInfo window to ago(7d)
- **Latency**: EventProcessedUtcTime is 1-5sec behind actual event
- **processId reuse**: PostgreSQL reuses after connection close - correlate within same time window
- **Query truncation**: Very long queries may be split across multiple log entries
- **Authentication errors use error codes**: PostgreSQL logs auth failures as code 28xxx (28000, 28P01, etc.), NOT as text "authentication failed"
- **Diagnostic query** to see all error types:
  ```kql
  bronze_pssql_alllogs_nometrics
  | where EventProcessedUtcTime >= ago(24h)
  | where sqlerrcode != "00000" and sqlerrcode != ""
  | summarize count(), sample_msg = any(message) by sqlerrcode, errorLevel
  | order by count_ desc
  ```

### 7. Response Format

Format all responses as:
```
🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / ✅ NORMAL

[Metric & Finding]
Query searched: [Time window, threshold, conditions]

Recommendation: [Action]
```

Example: "🔴 CRITICAL: 42 failed auth attempts from 192.168.1.100 (>5 threshold) in last 24h. Recommend: Block IP via NSG | Enable MFA | Review logs"

### 8. Example Questions Agent Can Answer

✅ "Show failed logins in last hour" → Brute force detection
✅ "Which users run most SELECT queries today?" → Activity analysis
✅ "Detect ML anomalies this week" → series_decompose_anomalies
✅ "Show privilege escalations" → GRANT/REVOKE activity
✅ "What error codes are most common?" → Error trend analysis
✅ "Find users accessing 5+ schemas" → Reconnaissance detection
✅ "Show off-hours DDL changes" → Compliance audit
✅ "Detect data exfiltration patterns" → Excessive SELECTs
✅ "Compare current activity vs baseline" → Anomaly score
✅ "Show weekend suspicious activity" → Temporal pattern analysis

---

## 📊 Data Source Example Queries

### Example 1: Brute Force Attack Detection (Last 24 Hours)

**User Question**: "Show me any brute force attacks from the last 24 hours"

**Reasoning**: Identifies authentication failures using PostgreSQL error codes (28xxx = authentication errors)

**Query**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where (tostring(sqlerrcode) startswith "28" and tostring(sqlerrcode) != "28000")  // 28xxx auth errors except 28000
      or (tostring(sqlerrcode) == "28000" and tolower(errorLevel) in ("error", "fatal"))  // 28000 with ERROR/FATAL = failed auth
      or (tolower(errorLevel) in ("error", "fatal") and message contains "authentication")
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ErrorCode = tostring(sqlerrcode)
| summarize 
    FailedAttempts = count(),
    FirstAttempt = min(EventProcessedUtcTime),
    LastAttempt = max(EventProcessedUtcTime),
    Users = make_set(UserName, 10),
    Databases = make_set(DatabaseName, 5),
    ErrorCodes = make_set(ErrorCode, 5),
    SampleMessages = make_set(message, 2)
    by ClientHost = coalesce(ClientHost, "UNKNOWN"), LogicalServerName
| extend Severity = case(
    FailedAttempts > 20, "🔴 CRITICAL",
    FailedAttempts > 10, "🟠 HIGH",
    FailedAttempts > 5, "🟡 MEDIUM",
    "ℹ️ LOW"
)
| order by FailedAttempts desc
| project 
    ClientHost, 
    ServerName = LogicalServerName,
    FailedAttempts, 
    Severity, 
    Users = strcat_array(Users, ", "), 
    Databases = strcat_array(Databases, ", "),
    ErrorCodes = strcat_array(ErrorCodes, ", "),
    FirstAttempt, 
    LastAttempt,
    SampleMessages
```

**Expected Response**: Table showing IP addresses with authentication failures. If no results, respond: "✅ No authentication failures detected in the last 24 hours (0 errors with code 28xxx)."

**Troubleshooting**: Check what auth-related errors exist:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where tostring(sqlerrcode) startswith "28"
| summarize count() by sqlerrcode = tostring(sqlerrcode), errorLevel = toupper(errorLevel), sample_message = any(message)
| order by count_ desc
```

---

### Example 2: Data Exfiltration Detection (Current Hour)

**User Question**: "Who is exfiltrating data right now?"

**Reasoning**: Finds users running excessive SELECT queries (potential data theft)

**Query**:
```kql
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "connection authorized"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| summarize User = any(UserName), Database = any(DatabaseName), SourceHost = any(ClientHost)
    by processId, LogicalServerName;

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:" and message has_any ("SELECT", "COPY")
| where backend_type == "client backend"
| join kind=leftouter sessionInfo on processId, LogicalServerName
| summarize 
    SelectCount = count(),
    LastQuery = max(EventProcessedUtcTime),
    TablesAccessed = dcount(extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message))
    by User, Database, SourceHost, processId
| where SelectCount > 15
| extend Severity = case(SelectCount > 50, "🔴 CRITICAL", SelectCount > 30, "🟠 HIGH", "🟡 MEDIUM")
| order by SelectCount desc
| project User, Database, SourceHost, SelectCount, TablesAccessed, Severity, LastQuery
```

**Expected Response**: Table of users executing suspicious numbers of SELECT queries, grouped by user/database.

---

### Example 3: Privilege Escalation Monitoring (Last 7 Days)

**User Question**: "Have there been any privilege escalation attempts this week?"

**Reasoning**: Detects GRANT/REVOKE/CREATE ROLE operations (especially off-hours)

**Query**:
```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| where PrivilegeOps > 0
| extend 
    TimeContext = case(
        HourOfDay < 6 or HourOfDay > 22, "🔴 Midnight",
        HourOfDay < 9 or HourOfDay > 17, "🟡 Off-Hours",
        "✅ Business Hours"
    ),
    DayContext = case(
        DayOfWeek in (0, 6), "🔴 Weekend",
        "✅ Weekday"
    ),
    Severity = case(
        (HourOfDay < 6 or HourOfDay > 22) and DayOfWeek in (0, 6), "🔴 CRITICAL",
        HourOfDay < 9 or HourOfDay > 17, "🟠 HIGH",
        "🟡 MEDIUM"
    )
| where PrivilegeOps > 0
| project Timestamp, ServerName, PrivilegeOps, HourOfDay, DayOfWeek, TimeContext, DayContext, Severity, ActivityCount
| order by Timestamp desc
```

**Expected Response**: Timeline of privilege operations with risk context (off-hours/weekend = higher severity).

---

### Example 4: Error Spike Analysis (Last 2 Hours)

**User Question**: "Show me error spikes in the last 2 hours"

**Reasoning**: Detects sudden increases in ERROR/FATAL/PANIC logs indicating system issues or attacks

**Query**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(2h)
| where errorLevel in ("ERROR", "FATAL", "PANIC")
| extend 
    ErrorCategory = case(
        message contains "authentication", "🔐 Auth Error",
        message contains "permission denied", "🚫 Permission Error",
        message contains "connection", "🔌 Connection Error",
        sqlerrcode startswith "28", "🔐 Auth Error",
        sqlerrcode startswith "42", "🚫 Permission Error",
        sqlerrcode startswith "53", "⚠️ Resource Error",
        "❓ Other Error"
    ),
    LogicalServerName = LogicalServerName
| summarize 
    ErrorCount = count(),
    UniqueErrorTypes = dcount(ErrorCategory),
    ErrorTypes = make_set(ErrorCategory, 5),
    FirstError = min(EventProcessedUtcTime),
    LastError = max(EventProcessedUtcTime),
    SampleMessages = make_set(message, 3)
    by bin(EventProcessedUtcTime, 5m), LogicalServerName
| where ErrorCount > 10
| extend Severity = case(ErrorCount > 50, "🔴 CRITICAL", ErrorCount > 25, "🟠 HIGH", "🟡 MEDIUM")
| order by EventProcessedUtcTime desc
| project TimeWindow = EventProcessedUtcTime, ServerName = LogicalServerName, ErrorCount, Severity, ErrorTypes = strcat_array(ErrorTypes, "; "), UniqueErrorTypes
```

**Expected Response**: Timeline of error spikes with error categories, allowing quick diagnosis.

---

### Example 5: ML-Based Anomaly Detection (Last 7 Days)

**User Question**: "Detect anomalies in database activity patterns using ML"

**Reasoning**: Uses time series decomposition to identify unusual activity compared to baseline

**Query**:
```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| make-series ActivitySeries = sum(ActivityCount) default=0 on Timestamp step 5m by ServerName
| extend (anomalies, score, baseline) = series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
| mv-expand Timestamp to typeof(datetime), ActivitySeries to typeof(long), anomalies to typeof(int), score to typeof(double), baseline to typeof(double)
| where anomalies != 0 and Timestamp >= ago(24h)
| extend 
    Direction = iff(anomalies > 0, "📈 Activity Spike", "📉 Activity Drop"),
    Severity = case(
        abs(score) > 3.5, "🔴 CRITICAL",
        abs(score) > 2.5, "🟠 HIGH",
        abs(score) > 1.5, "🟡 MEDIUM",
        "ℹ️ LOW"
    ),
    DeviationPercent = round(abs(ActivitySeries - baseline) * 100 / baseline, 1)
| order by abs(score) desc
| project 
    Timestamp, 
    ServerName, 
    Activity = ActivitySeries, 
    Baseline = round(baseline, 0), 
    DeviationPercent, 
    Direction, 
    Severity, 
    AnomalyScore = round(score, 2)
| take 20
```

**Expected Response**: Time series of anomalies with baseline comparison, helping identify unusual patterns.

---

## ⚙️ Configuration Summary

| Component | Location | Status |
|-----------|----------|--------|
| Data Source Description | Top of document | ✅ 747/800 chars |
| Data Source Instructions | Sections 1-7 | ✅ 13,850/15,000 chars |
| Example Queries | Section 8 (this section) | ✅ 5 queries provided |
| Agent Instructions | docs/DATA-AGENT-INSTRUCTIONS.md | ✅ ~14.5K chars |
| KQL Queries | UNIFIED-ANOMALY-DETECTION.kql | ✅ Full anomaly suite |


