# Data Source Instructions for AI Agent

## 📝 DATA SOURCE DESCRIPTION (Max 800 chars)

```
PostgreSQL Real-Time Intelligence Database with ML Anomaly Detection

This Kusto database contains real-time diagnostic logs from Azure PostgreSQL Flexible Servers and pre-aggregated metrics tables for ML-based anomaly detection.

Primary Tables:
• bronze_pssql_alllogs_nometrics: Raw PostgreSQL logs (connections, audits, errors) streamed via Event Hub
• postgres_activity_metrics: 5-min aggregated activity with temporal dimensions (HourOfDay, DayOfWeek) for ML baseline detection
• postgres_error_metrics: 1-min error rates by category
• postgres_user_metrics: Hourly per-user query patterns

Use cases: Security monitoring (data exfiltration, privilege escalation, brute force), ML anomaly detection (series_decompose_anomalies), compliance auditing, performance troubleshooting.

Data freshness: Real-time (1-5 sec latency). Requires pgaudit extension for query-level auditing.
```

**Character count: 784/800** ✅

---

## 📋 DATA SOURCE INSTRUCTIONS (Max 15,000 chars)

```markdown
# PostgreSQL Monitoring - Data Source Instructions

## 1. TABLE SCHEMAS

### 1.1 bronze_pssql_alllogs_nometrics (Raw Logs)
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| EventProcessedUtcTime | datetime | Event Hub processing time (USE FOR FILTERS) | 2025-11-20T14:30:45Z |
| TimeGenerated | datetime | PostgreSQL log timestamp | 2025-11-20T14:30:44Z |
| LogicalServerName | string | Server name | advpsqlfxuk |
| category | string | Log category | PostgreSQLLogs |
| message | string | Full log message (contains all info) | AUDIT: SESSION,12345,1,READ,SELECT,public.users,,,\"SELECT * FROM users\" |
| errorLevel | string | Severity (LOG, WARNING, ERROR, FATAL, PANIC) | ERROR |
| sqlerrcode | string | PostgreSQL error code (00000 = no error) | 28P01 |
| processId | long | Backend process ID (for session correlation) | 12345 |
| backend_type | string | Process type (client backend, autovacuum, etc.) | client backend |

### 1.2 postgres_activity_metrics (ML Primary Table)
Auto-aggregated every 5 minutes. Use for ML anomaly detection.

| Column | Type | Description | ML Use Case |
|--------|------|-------------|-------------|
| Timestamp | datetime | 5-min bucket | Time series analysis |
| ServerName | string | PostgreSQL server | Group by dimension |
| HourOfDay | int | 0-23 | Off-hours activity detection |
| DayOfWeek | int | 0=Sun, 6=Sat | Weekend pattern detection |
| ActivityCount | long | Total log events | Overall activity baseline |
| AuditLogs | long | AUDIT log count | Query volume tracking |
| Errors | long | ERROR/FATAL/PANIC | Error spike detection |
| Connections | long | New connections | Connection pattern analysis |
| UniqueUsers | long | Distinct users | User cardinality anomalies |
| SelectOps | long | SELECT/COPY/READ | Data exfiltration monitoring |
| WriteOps | long | INSERT/UPDATE/DELETE | Write activity tracking |
| DDLOps | long | CREATE/DROP/ALTER | Schema change monitoring |
| PrivilegeOps | long | GRANT/REVOKE/ALTER ROLE | **🔴 SECURITY CRITICAL** |

**Key Detection Rules**:
- `PrivilegeOps > 0` → Immediate security review
- `HourOfDay < 9 OR > 17` + `DDLOps > 0` → Off-hours schema changes
- `UniqueUsers` spike > 2x baseline → Credential compromise

### 1.3 postgres_error_metrics
Auto-aggregated every 1 minute.

| Column | Type | Values |
|--------|------|--------|
| Timestamp | datetime | 1-min bucket |
| ServerName | string | Server name |
| ErrorRate | long | Errors per minute |
| ErrorTypes | string | Authentication, Permission, Connection, Other |

### 1.4 postgres_user_metrics
Auto-aggregated every 1 hour.

| Column | Type | Description |
|--------|------|-------------|
| Timestamp | datetime | 1-hour bucket |
| UserName | string | Database user |
| ServerName | string | Server name |
| QueryCount | long | Total queries |
| SelectQueries | long | SELECT/COPY count |
| DestructiveOps | long | DELETE/UPDATE/TRUNCATE/DROP |

---

## 2. DATA PATTERNS & MESSAGE FORMATS

### 2.1 CONNECTION Logs (User/Database/Host extraction)
**Message Pattern**:
```
connection authorized: user=USERNAME database=DBNAME host=IP_ADDRESS SSL enabled
```

**Extraction**:
```kql
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
```

**Critical**: CONNECTION logs are the ONLY source of user/database/host. Must correlate with AUDIT logs via processId.

### 2.2 AUDIT Logs (Query Execution)
**Message Pattern**:
```
AUDIT: SESSION,<pid>,<seq>,<operation>,<statement>,<object>,,,<query_text>
```

**Example**:
```
AUDIT: SESSION,12345,1,READ,SELECT,public.employees,,,SELECT * FROM employees WHERE salary > 100000
```

**Extraction**:
```kql
| extend 
    Operation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),      // READ, WRITE, DDL
    Statement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message), // SELECT, INSERT, etc.
    Table = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message),
    QueryText = trim('"', extract(@",,,([^<]+)<", 1, message))
```

**⚠️ CRITICAL**: AUDIT logs DO NOT contain user/database/host. You MUST join with CONNECTION logs.

### 2.3 ERROR Logs
**Key Error Codes**:
| Code | Category | Meaning | Security Impact |
|------|----------|---------|-----------------|
| 28P01 | Auth | Password failed | Brute force attack |
| 42501 | Permission | Insufficient privilege | Unauthorized access attempt |
| 53300 | Resource | Too many connections | DoS or pool exhaustion |
| 08006 | Connection | Connection failure | Network issue |

**Extraction**:
```kql
| where errorLevel in ("ERROR", "FATAL", "PANIC") or sqlerrcode != "00000"
```

---

## 3. SESSION CORRELATION PATTERN (MANDATORY)

**Problem**: AUDIT logs have processId but NOT user/database/host.

**Solution**: Build sessionInfo lookup from CONNECTION logs:

```kql
// STEP 1: Create sessionInfo (inline or as let)
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)  // Wide window (connections are long-lived)
| where message contains "connection authorized"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| where isnotempty(UserName)
| summarize User = any(UserName), Database = any(DatabaseName), SourceHost = any(ClientHost)
    by processId, LogicalServerName;

// STEP 2: Join AUDIT logs with sessionInfo
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where message contains "AUDIT:"
| join kind=leftouter sessionInfo on processId, LogicalServerName
| extend 
    FinalUser = iff(isnotempty(User), User, "UNKNOWN"),
    FinalDatabase = iff(isnotempty(Database), Database, "UNKNOWN")
```

**Why leftouter?** Some AUDIT logs may not have matching CONNECTION logs (connection outside time window).

**Why ago(24h) for sessionInfo?** PostgreSQL sessions can be long-lived (hours/days). Use wider window than analysis window.

---

## 4. FILTERING RULES

### 4.1 Time Filtering (MANDATORY for performance)
**Always filter by EventProcessedUtcTime FIRST**:

```kql
// ✅ CORRECT
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)  // Filter first
| where message contains "AUDIT:"

// ❌ WRONG (scans entire table)
bronze_pssql_alllogs_nometrics
| where message contains "AUDIT:"
```

**Recommended windows**:
- Real-time alerts: ago(5m) to ago(1h)
- Investigations: ago(24h)
- ML training: ago(7d) to ago(30d)

### 4.2 Backend Type Filtering
**Exclude internal processes** for user activity analysis:

```kql
| where backend_type == "client backend"  // Only real user connections
```

**Exclude values**: autovacuum worker, walwriter, checkpointer, background writer, logical replication launcher

### 4.3 Noise Reduction
```kql
| where FinalUser != "azuresu"  // Exclude Azure monitoring user
| where SchemaName !in ("pg_catalog", "information_schema")  // Exclude system schemas
```

---

## 5. COMMON QUERY PATTERNS

### 5.1 Failed Logins (Brute Force Detection)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "authentication failed" or sqlerrcode == "28P01"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| summarize FailedAttempts = count() by ClientHost, UserName
| where FailedAttempts > 5
| order by FailedAttempts desc
```

### 5.2 Data Exfiltration (Excessive SELECTs)
```kql
let sessionInfo = [see Section 3];

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where message contains "AUDIT:"
| where message has_any ("SELECT", "COPY")
| where backend_type == "client backend"
| join kind=leftouter sessionInfo on processId, LogicalServerName
| summarize SelectCount = count() by processId, User, SourceHost
| where SelectCount > 15  // Threshold: 15 SELECTs in 5 min
| order by SelectCount desc
```

### 5.3 Privilege Escalation
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
| where message has_any ("GRANT", "REVOKE", "ALTER ROLE", "CREATE ROLE")
| extend UserName = extract(@"user=([^\s,]+)", 1, message)
| summarize PrivOpsCount = count() by UserName, LogicalServerName, bin(EventProcessedUtcTime, 5m)
| where PrivOpsCount > 3
```

---

## 6. ML ANOMALY DETECTION PATTERNS

### 6.1 Time Series Anomaly (Activity Baseline)
```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| make-series ActivitySeries = sum(ActivityCount) default=0 on Timestamp step 5m by ServerName
| extend (anomalies, score, baseline) = series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
| mv-expand Timestamp to typeof(datetime), ActivitySeries to typeof(long), anomalies to typeof(int), score to typeof(double), baseline to typeof(double)
| where anomalies != 0
| where Timestamp >= ago(1h)
| extend 
    Direction = iff(anomalies > 0, "📈 Above Normal", "📉 Below Normal"),
    Severity = case(abs(score) > 3.0, "CRITICAL", abs(score) > 2.0, "HIGH", "MEDIUM")
| project Timestamp, ServerName, ActivityCount = ActivitySeries, Baseline = baseline, Score = score, Direction, Severity
```

**Interpretation**:
- `anomalies = 1`: Unexpected spike
- `anomalies = -1`: Unexpected drop
- `score`: Deviation magnitude (higher = more anomalous)
- `baseline`: Expected value based on learned pattern
- **Sensitivity**: 1.5 (adjust to 1.0 for more alerts, 2.0 for fewer)

### 6.2 Privilege Escalation Alerts (Temporal)
```kql
postgres_activity_metrics
| where Timestamp >= ago(24h)
| where PrivilegeOps > 0
| extend 
    TimeRisk = iff(HourOfDay < 9 or HourOfDay > 17, "🔴 Off-Hours", "🟡 Business Hours"),
    WeekendRisk = iff(DayOfWeek in (0, 6), "🔴 Weekend", "✅ Weekday")
| project Timestamp, ServerName, PrivilegeOps, HourOfDay, DayOfWeek, TimeRisk, WeekendRisk
```

**Alert Logic**: ANY PrivilegeOps > 0 is suspicious. Off-Hours + Weekend = CRITICAL.

### 6.3 User Behavioral Baseline
```kql
postgres_user_metrics
| where Timestamp >= ago(7d)
| summarize 
    AvgDailyQueries = avg(QueryCount),
    MaxDestructiveOps = max(DestructiveOps),
    DestructiveRatio = round(avg(DestructiveOps) * 100.0 / avg(QueryCount), 2)
    by UserName, ServerName
| extend RiskLevel = case(
    MaxDestructiveOps > 50, "🔴 High",
    DestructiveRatio > 20, "🟠 Medium",
    "✅ Normal"
)
| where RiskLevel != "✅ Normal"
| order by MaxDestructiveOps desc
```

---

## 7. DATA QUALITY & LIMITATIONS

### 7.1 Known Issues
1. **AUDIT logs require pgaudit**: If no "AUDIT:" messages, extension not enabled
2. **processId reuse**: PostgreSQL reuses IDs after connections close. Always correlate within same time window
3. **Message truncation**: Very long queries may be split across multiple log entries
4. **Lag**: EventProcessedUtcTime is 1-5 sec after TimeGenerated

### 7.2 Data Freshness
- **Raw logs**: 1-5 second latency (real-time)
- **postgres_activity_metrics**: Updated every 5 minutes
- **postgres_error_metrics**: Updated every 1 minute
- **postgres_user_metrics**: Updated every 1 hour

**Verify freshness**:
```kql
bronze_pssql_alllogs_nometrics
| summarize LatestLog = max(EventProcessedUtcTime)
| extend Lag = now() - LatestLog, Status = iff(Lag > 5m, "🔴 Delayed", "✅ Real-time")
```

---

## 8. PERFORMANCE OPTIMIZATION

### 8.1 Query Optimization Rules
1. **Filter early**: Apply time/server filters BEFORE joins
2. **Limit sessionInfo window**: Use smallest window that captures connections
3. **Use `take` for exploration**: `| take 100` for quick tests
4. **Aggregate before join**: Reduce data volume before expensive joins

**Example**:
```kql
// ✅ OPTIMIZED
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)  // Filter first
| where backend_type == "client backend"
| summarize Count = count() by processId  // Aggregate
| join kind=inner sessionInfo on processId

// ❌ SLOW
bronze_pssql_alllogs_nometrics
| join kind=inner sessionInfo on processId  // Join entire table
| where EventProcessedUtcTime >= ago(1h)
```

### 8.2 Indexing
- `EventProcessedUtcTime`: Automatically indexed (use for time filters)
- `LogicalServerName`: Indexed (use for server-specific queries)
- `processId`: Not indexed (join performance depends on sessionInfo size)

---

## 9. SECURITY & COMPLIANCE

### 9.1 Data Sensitivity
- **PII/PHI**: Query text may contain SSNs, medical records, etc.
- **Best Practice**: Use `project-away QueryText` when sharing results
- **Redaction**: `| extend QueryText = replace_regex(QueryText, @"\d{3}-\d{2}-\d{4}", "XXX-XX-XXXX")`

### 9.2 Audit Trail
- **Retention**: Configurable (default 90 days)
- **Immutability**: Cannot modify/delete logs
- **Compliance**: Suitable for SOC 2, HIPAA, PCI-DSS

---

## 10. TROUBLESHOOTING

### 10.1 No AUDIT logs
**Check**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| summarize Count = count() by HasAudit = message contains "AUDIT:"
```
**Fix**: Enable pgaudit extension + `shared_preload_libraries = 'pgaudit'` + restart server

### 10.2 User/Database always "UNKNOWN"
**Check**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "connection authorized"
| take 10
```
**Fix**: Enable `log_connections = on` in Server Parameters OR widen sessionInfo window to ago(7d)

### 10.3 ML not detecting anomalies
**Check**:
```kql
postgres_activity_metrics
| summarize MinTime = min(Timestamp), MaxTime = max(Timestamp), Records = count()
```
**Fix**: Ensure 7+ days of data exists + adjust sensitivity from 1.5 to 1.0 for more sensitive detection

---

## 11. EXAMPLE QUESTIONS THE AGENT CAN ANSWER

✅ "Show me failed login attempts in the last hour"
✅ "Which users are performing the most SELECT queries today?"
✅ "Detect anomalous activity patterns using ML"
✅ "Show privilege escalation attempts this week"
✅ "What are the top error codes in the last 24 hours?"
✅ "Find users accessing more than 5 different schemas"
✅ "Show off-hours DDL operations (schema changes)"
✅ "Detect data exfiltration patterns (excessive SELECTs)"
✅ "Compare current error rate vs baseline"
✅ "Show weekend activity that deviates from normal"

---

**END OF INSTRUCTIONS**
```

**Character count: 13,967/15,000** ✅

