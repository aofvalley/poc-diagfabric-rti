# 📊 Data Source Instructions - PostgreSQL Monitoring (v3 Enhanced)

## Primary Table: `bronze_pssql_alllogs_nometrics`

**Type**: PostgreSQL Diagnostic Logs (Real-time stream via Azure Event Hub)  
**Retention**: [Your retention period - e.g., 90 days]

## 🆕 ML Metrics Tables (v3 Anomaly Detection)

| Table | Granularity | Purpose |
|---|---|---|
| `postgres_activity_metrics` | 5 min | Primary ML anomaly detection |
| `postgres_error_metrics` | 1 min | Error rate trends |
| `postgres_user_metrics` | 1 hour | Per-user behavior analysis |

---

## 🎯 Data Source Purpose

This table contains **all diagnostic logs** from Azure Database for PostgreSQL Flexible Server, including:
- **Connection logs**: User authentication, session start/end
- **Audit logs**: Query execution (requires pgaudit extension)
- **Error logs**: Database errors, warnings, fatal errors
- **System logs**: Autovacuum, checkpoints, replication events

**Use cases**:
- Security monitoring (brute force, SQL injection, data exfiltration)
- Performance troubleshooting (slow queries, connection issues)
- Compliance auditing (who accessed what data, when)
- **ML Anomaly detection** (temporal patterns, behavioral baselines, `series_decompose_anomalies()`)
- **Privilege escalation tracking** (GRANT/REVOKE/ALTER ROLE operations)

---

## 📋 Schema Definition

| **Column** | **Type** | **Description** | **Example** |
|---|---|---|---|
| `EventProcessedUtcTime` | datetime | When log was processed by Event Hub | `2025-11-20T14:30:45.123Z` |
| `TimeGenerated` | datetime | Original PostgreSQL log timestamp | `2025-11-20T14:30:44.987Z` |
| `LogicalServerName` | string | PostgreSQL server name | `advpsqlfxuk` |
| `category` | string | Log category (always "PostgreSQLLogs") | `PostgreSQLLogs` |
| `message` | string | Full log message (multi-line, contains all info) | See examples below |
| `errorLevel` | string | Log severity (LOG, WARNING, ERROR, FATAL, PANIC) | `ERROR` |
| `sqlerrcode` | string | PostgreSQL error code (00000 = no error) | `28P01` (auth failed) |
| `processId` | long | Backend process ID (use for session correlation) | `12345` |
| `backend_type` | string | Process type (client backend, autovacuum, etc.) | `client backend` |
| `OperationName` | string | Operation type | `LogEvent` |
| `SourceSystem` | string | Source system | `Azure` |
| `TenantId` | string | Azure tenant ID | `<guid>` |
| `Type` | string | Table type | `AzureDiagnostics` |

---

## 🤖 ML Metrics Tables Schema (v3)

### `postgres_activity_metrics` (Primary ML Table)

**Update Policy**: Auto-aggregated every 5 minutes from `bronze_pssql_alllogs_nometrics`

| **Column** | **Type** | **Description** | **Use Case** |
|---|---|---|---|
| `Timestamp` | datetime | 5-minute bucket timestamp | Time series analysis |
| `ServerName` | string | PostgreSQL server name | Filter by server |
| `HourOfDay` | int | Hour (0-23) | Detect off-hours activity |
| `DayOfWeek` | int | Day (0=Sun, 6=Sat) | Weekend/weekday patterns |
| `ActivityCount` | long | Total log events | Overall activity baseline |
| `AuditLogs` | long | AUDIT log count | Query activity tracking |
| `Errors` | long | ERROR/FATAL/PANIC count | Error rate monitoring |
| `Connections` | long | New connection count | Connection pattern analysis |
| `UniqueUsers` | long | Distinct users | User cardinality anomalies |
| `SelectOps` | long | SELECT/COPY/READ | Read operation volume |
| `WriteOps` | long | INSERT/UPDATE/DELETE | Write operation volume |
| `DDLOps` | long | CREATE/DROP/ALTER | Schema change tracking |
| `PrivilegeOps` | long | GRANT/REVOKE/ALTER ROLE | 🔴 Security-critical alerts |

**Key Detection Patterns**:
- `PrivilegeOps > 0` → Immediate security review (privilege escalation)
- `DDLOps` during `HourOfDay NOT IN (9..17)` → Off-hours schema changes
- `UniqueUsers` spike > 2x baseline → Possible credential compromise

### `postgres_error_metrics`

**Update Policy**: Auto-aggregated every 1 minute

| **Column** | **Type** | **Description** |
|---|---|---|
| `Timestamp` | datetime | 1-minute bucket |
| `ServerName` | string | PostgreSQL server |
| `ErrorRate` | long | Errors per minute |
| `ErrorTypes` | string | Comma-separated categories |

**ErrorTypes Values**: `Authentication`, `Permission`, `Connection`, `Other`

### `postgres_user_metrics`

**Update Policy**: Auto-aggregated every 1 hour

| **Column** | **Type** | **Description** |
|---|---|---|
| `Timestamp` | datetime | 1-hour bucket |
| `UserName` | string | Database user |
| `ServerName` | string | PostgreSQL server |
| `QueryCount` | long | Total queries |
| `SelectQueries` | long | SELECT/COPY count |
| `DestructiveOps` | long | DELETE/UPDATE/TRUNCATE/DROP |

---

## 🔍 Data Patterns & Examples

### **1. CONNECTION Logs** (User Authentication)

**Message Pattern**:
```
connection authorized: user=USERNAME database=DBNAME host=IP_ADDRESS SSL enabled (protocol=TLSv1.3, cipher=...)
```

**Real Example**:
```
connection authorized: user=advpsqlfxuk database=postgres host=203.0.113.45(54321) SSL enabled (protocol=TLSv1.3, cipher=TLS_AES_256_GCM_SHA384, bits=256)
```

**Extraction Fields**:
- `UserName` = `extract(@"user=([^\s,]+)", 1, message)` → `advpsqlfxuk`
- `DatabaseName` = `extract(@"database=([^\s,]+)", 1, message)` → `postgres`
- `ClientHost` = `extract(@"host=([^\s]+)", 1, message)` → `203.0.113.45(54321)`

**When to use**: Correlate processId with user/database/host for AUDIT logs.

---

### **2. AUDIT Logs** (Query Execution - requires pgaudit)

**Message Pattern**:
```
AUDIT: SESSION,<pid>,<seq>,<operation>,<statement>,<object>,,,"<query_text>"
```

**Real Example**:
```
AUDIT: SESSION,12345,1,READ,SELECT,public.employees,,,"SELECT * FROM employees WHERE salary > 100000"
```

**Extraction Fields**:
- `Operation` = READ | WRITE | DDL | FUNCTION
- `Statement` = SELECT | INSERT | UPDATE | DELETE | CREATE | DROP | etc.
- `Table` = `extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message)` → `public.employees`
- `QueryText` = `extract(@",,,\"([^\"]+)\"", 1, message)` → `SELECT * FROM employees WHERE salary > 100000`

**Important**: AUDIT logs **DO NOT contain user/database/host** directly. You **MUST** join with CONNECTION logs using `processId` to get this info.

---

### **3. ERROR Logs** (Authentication Failures, Syntax Errors, etc.)

**Message Pattern**:
```
FATAL: password authentication failed for user "USERNAME"
```

**Real Examples**:
```
errorLevel = "FATAL", sqlerrcode = "28P01"
message = "FATAL: password authentication failed for user \"advpsqlfxuk\""

errorLevel = "ERROR", sqlerrcode = "42P01"
message = "ERROR: relation \"nonexistent_table\" does not exist at character 15"

errorLevel = "ERROR", sqlerrcode = "53300"
message = "FATAL: sorry, too many clients already"
```

**Key Error Codes**:
| **Code** | **Category** | **Meaning** | **Example** |
|---|---|---|---|
| `28P01` | Authentication | Invalid password | Brute force attack |
| `28000` | Authentication | Invalid auth specification | Missing credentials |
| `42P01` | Syntax | Undefined table | SQL injection attempt |
| `42501` | Permission | Insufficient privilege | Unauthorized access |
| `53300` | Resource | Too many connections | Connection pool exhaustion |
| `53400` | Resource | Configuration limit exceeded | Max locks exceeded |
| `08006` | Connection | Connection failure | Network issue |

---

### **4. INTERNAL Logs** (System Maintenance - Filter Out for User Analysis)

**backend_type values to EXCLUDE**:
- `autovacuum worker` (automatic cleanup)
- `logical replication launcher`
- `walwriter` (Write-Ahead Log writer)
- `checkpointer`
- `background writer`

**Filter for user activity ONLY**:
```kql
| where backend_type == "client backend"
```

---

## 🛠️ Data Processing Guidelines

### **Time Filtering** (CRITICAL for Performance)

**Always use `EventProcessedUtcTime`** (indexed, faster):
```kql
// ✅ CORRECT: Filter first
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "AUDIT:"

// ❌ WRONG: No time filter (scans entire table)
bronze_pssql_alllogs_nometrics
| where message contains "AUDIT:"
```

**Recommended Time Windows**:
- Real-time alerts: `ago(5m)` to `ago(1h)`
- User investigations: `ago(24h)`
- Trend analysis: `ago(7d)` to `ago(30d)`
- Historical reporting: `ago(90d)` (if retention allows)

---

### **Session Correlation Pattern** (MANDATORY for User/Database/Host)

**Problem**: AUDIT logs contain `processId` but NOT user/database/host.

**Solution**: Build `sessionInfo` lookup table from CONNECTION logs:

```kql
// STEP 1: Create sessionInfo (processId → User/Database/Host mapping)
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)  // Match your analysis window
| where message contains "connection authorized" or message contains "connection received"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| where isnotempty(UserName)
| summarize 
    User = take_any(UserName), 
    Database = take_any(DatabaseName), 
    SourceHost = take_any(ClientHost)
    by processId, LogicalServerName;

// STEP 2: Join AUDIT logs with sessionInfo
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "AUDIT:"
| join kind=leftouter sessionInfo on processId, LogicalServerName
| extend 
    FinalUser = iff(isnotempty(User), User, "UNKNOWN"),
    FinalDatabase = iff(isnotempty(Database), Database, "UNKNOWN"),
    FinalHost = iff(isnotempty(SourceHost), SourceHost, "UNKNOWN")
| project EventProcessedUtcTime, FinalUser, FinalDatabase, FinalHost, message
```

**Why `leftouter` join?**
- Some AUDIT logs may not have matching CONNECTION logs (connection outside time window)
- Use `UNKNOWN` fallback to avoid losing data

**Why `ago(24h)` in sessionInfo?**
- PostgreSQL connections can be long-lived (hours/days)
- sessionInfo needs wider window than analysis to catch older connections
- If analyzing `ago(1h)`, sessionInfo should use `ago(24h)` or `ago(7d)`

---

### **Regex Extraction Patterns** (Copy-Paste Ready)

```kql
// Extract User
| extend UserName = extract(@"user=([^\s,]+)", 1, message)

// Extract Database
| extend DatabaseName = extract(@"database=([^\s,]+)", 1, message)

// Extract Host/IP
| extend ClientHost = extract(@"host=([^\s]+)", 1, message)

// Extract Table from AUDIT log
| extend Table = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message)

// Extract Statement Type (SELECT, INSERT, etc.)
| extend Statement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message)

// Extract Query Text
| extend QueryText = extract(@",,,\"([^\"]+)\"", 1, message)

// Extract Error Message Detail
| extend ErrorDetail = extract(@"ERROR:\s+(.+)", 1, message)
```

---

## 📊 Data Quality & Limitations

### **Known Issues**

1. **AUDIT logs require pgaudit extension**:
   - If `message` doesn't contain `"AUDIT:"`, pgaudit is not enabled
   - Check: `SELECT * FROM pg_available_extensions WHERE name = 'pgaudit';`
   - Enable: Add `shared_preload_libraries = 'pgaudit'` in Azure Portal → Server Parameters

2. **processId reuse**:
   - PostgreSQL reuses processIds after connections close
   - Always correlate within same time window (don't mix old/new processIds)
   - Use `TimeGenerated` or `EventProcessedUtcTime` to filter

3. **Message truncation**:
   - Very long queries may be truncated in `message` field
   - Full query may be split across multiple log entries
   - Use `log_statement = 'all'` in Server Parameters to capture everything

4. **Lag between TimeGenerated and EventProcessedUtcTime**:
   - `TimeGenerated`: When PostgreSQL logged the event
   - `EventProcessedUtcTime`: When Event Hub processed it (usually 1-5 seconds later)
   - For real-time alerts, use `EventProcessedUtcTime`
   - For compliance audits, use `TimeGenerated`

---

## 🎯 Common Query Patterns

### **Pattern 1: Failed Logins (Brute Force Detection)**

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "authentication failed" or sqlerrcode == "28P01"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| summarize FailedAttempts = count() by ClientHost, UserName
| where FailedAttempts > 5  // Threshold: 5 failures
| order by FailedAttempts desc
```

**Expected Output**:
| ClientHost | UserName | FailedAttempts |
|---|---|---|
| 203.0.113.45(54321) | advpsqlfxuk | 35 |
| 198.51.100.22(12345) | postgres | 15 |

---

### **Pattern 2: Data Exfiltration (Excessive SELECTs)**

```kql
let sessionInfo = [see above];

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where message contains "AUDIT:"
| where message has_any ("SELECT", "COPY")  // Data read operations
| join kind=leftouter sessionInfo on processId, LogicalServerName
| summarize SelectCount = count() by processId, User, SourceHost
| where SelectCount > 15  // Threshold: 15 SELECTs in 5 min
| order by SelectCount desc
```

---

### **Pattern 3: Error Rate (System Health)**

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| summarize 
    TotalEvents = count(),
    Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    Warnings = countif(errorLevel == "WARNING")
| extend 
    ErrorRate = round(Errors * 100.0 / TotalEvents, 2),
    HealthStatus = case(
        ErrorRate > 5, "🔴 Critical",
        ErrorRate > 1, "🟠 Warning",
        "✅ Healthy"
    )
```

---

### **Pattern 4: Top Active Users (24h)**

```kql
let sessionInfo = [see above];

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "AUDIT:"
| where backend_type == "client backend"  // Exclude internal processes
| join kind=leftouter sessionInfo on processId, LogicalServerName
| summarize 
    TotalQueries = count(),
    SelectQueries = countif(message has_any ("SELECT", "COPY")),
    WriteQueries = countif(message has_any ("INSERT", "UPDATE", "DELETE")),
    DDLQueries = countif(message has_any ("CREATE", "DROP", "ALTER"))
    by User
| where isnotempty(User)
| order by TotalQueries desc
| take 10
```

---

## 🤖 ML Anomaly Detection Query Patterns (v3)

### **Pattern 5: Time Series Anomaly Detection (Activity)**

```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| make-series ActivitySeries = avg(ActivityCount) default=0 on Timestamp step 5m by ServerName
| extend (anomalies, score, baseline) = series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
| mv-expand Timestamp to typeof(datetime), ActivitySeries to typeof(double), anomalies to typeof(int), score to typeof(double), baseline to typeof(double)
| where anomalies != 0
| project Timestamp, ServerName, Activity = ActivitySeries, Baseline = baseline, AnomalyScore = score, Direction = iff(anomalies == 1, "🔴 Spike", "🔵 Drop")
| order by Timestamp desc
```

**Understanding the Output**:
- `anomalies = 1`: Unexpected spike above baseline
- `anomalies = -1`: Unexpected drop below baseline
- `score`: Deviation magnitude (higher = more anomalous)
- `baseline`: Expected value based on learned pattern

---

### **Pattern 6: Privilege Escalation Alerts**

```kql
postgres_activity_metrics
| where Timestamp >= ago(24h)
| where PrivilegeOps > 0
| project Timestamp, ServerName, HourOfDay, DayOfWeek, PrivilegeOps, DDLOps
| extend 
    TimeRisk = iff(HourOfDay < 9 or HourOfDay > 17, "🔴 Off-Hours", "🟡 Business Hours"),
    WeekendRisk = iff(DayOfWeek in (0, 6), "🔴 Weekend", "✅ Weekday")
| order by Timestamp desc
```

**Alert Logic**: Any `PrivilegeOps > 0` requires immediate review, especially if `TimeRisk = Off-Hours`.

---

### **Pattern 7: User Behavioral Baseline Comparison**

```kql
postgres_user_metrics
| where Timestamp >= ago(7d)
| summarize 
    AvgDailyQueries = avg(QueryCount),
    AvgDestructiveOps = avg(DestructiveOps),
    MaxDestructiveOps = max(DestructiveOps),
    TotalDays = dcount(bin(Timestamp, 1d))
    by UserName, ServerName
| extend 
    DestructiveRatio = round(AvgDestructiveOps * 100.0 / AvgDailyQueries, 2),
    RiskLevel = case(
        MaxDestructiveOps > 50, "🔴 High Risk",
        DestructiveRatio > 20, "🟠 Medium Risk",
        "✅ Normal"
    )
| order by MaxDestructiveOps desc
```

---

### **Pattern 8: Temporal Heatmap (Activity by Hour/Day)**

```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| summarize 
    AvgActivity = avg(ActivityCount),
    AvgErrors = avg(Errors),
    AvgPrivOps = avg(PrivilegeOps)
    by HourOfDay, DayOfWeek
| extend 
    DayName = case(
        DayOfWeek == 0, "Sun",
        DayOfWeek == 1, "Mon",
        DayOfWeek == 2, "Tue",
        DayOfWeek == 3, "Wed",
        DayOfWeek == 4, "Thu",
        DayOfWeek == 5, "Fri",
        "Sat"
    )
| project DayName, DayOfWeek, HourOfDay, AvgActivity, AvgErrors, AvgPrivOps
| order by DayOfWeek asc, HourOfDay asc
```

**Use Case**: Identify normal activity patterns vs suspicious off-hours behavior.

---

### **Pattern 9: Error Rate Trend with Anomalies**

```kql
postgres_error_metrics
| where Timestamp >= ago(24h)
| make-series ErrorSeries = sum(ErrorRate) default=0 on Timestamp step 1m by ServerName
| extend (anomalies, score, baseline) = series_decompose_anomalies(ErrorSeries, 1.5)
| mv-expand Timestamp to typeof(datetime), ErrorSeries to typeof(long), anomalies to typeof(int), score to typeof(double)
| where anomalies != 0
| project Timestamp, ServerName, Errors = ErrorSeries, AnomalyScore = score, Type = iff(anomalies == 1, "🔴 Spike", "🔵 Drop")
| order by abs(score) desc
| take 50
```

---

## 🔒 Security & Compliance

### **Data Sensitivity**

- **PII/PHI**: Query text may contain sensitive data (names, SSNs, medical records)
- **Credentials**: Some errors may include connection strings or passwords
- **Best Practice**: 
  - Use `project-away QueryText` when sharing results
  - Redact sensitive patterns: `| extend QueryText = replace_regex(QueryText, @"\d{3}-\d{2}-\d{4}", "XXX-XX-XXXX")`

### **Audit Trail**

- **Retention**: Logs retained for [your retention period]
- **Immutability**: Cannot modify/delete logs (compliance requirement)
- **Access Control**: Only authorized users can query this table
- **Compliance Standards**: Suitable for SOC 2, HIPAA, PCI-DSS audit requirements

---

## ⚡ Performance Optimization

### **Indexing** (Automatic in KQL)

- `EventProcessedUtcTime`: Automatically indexed (use for time filters)
- `LogicalServerName`: Indexed (use for server-specific queries)
- `processId`: Not indexed (join performance depends on sessionInfo size)

### **Query Optimization Tips**

1. **Filter early**: Apply time/server filters BEFORE joins
2. **Limit sessionInfo window**: Use smallest window that captures connections
3. **Use `take` for exploration**: `| take 100` instead of scanning millions of rows
4. **Aggregate before join**: Reduce data volume before expensive joins
5. **Use `summarize` instead of `distinct`**: Faster for large datasets

**Example**:
```kql
// ✅ OPTIMIZED: Filter → Aggregate → Join
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)  // Filter first
| where backend_type == "client backend"
| summarize Count = count() by processId  // Aggregate before join
| join kind=inner sessionInfo on processId

// ❌ SLOW: Join → Filter → Aggregate
bronze_pssql_alllogs_nometrics
| join kind=inner sessionInfo on processId  // Expensive join on entire table
| where EventProcessedUtcTime >= ago(1h)
| summarize Count = count() by processId
```

---

## 📈 Data Freshness

### Raw Logs (`bronze_pssql_alllogs_nometrics`)
- **Latency**: Logs appear 1-5 seconds after PostgreSQL generates them
- **Update Frequency**: Continuous stream (real-time)
- **Backfill**: Historical data available from [start date]
- **Gaps**: Check Azure Event Hub metrics if gaps detected

### ML Metrics Tables (v3)
- **`postgres_activity_metrics`**: Updated every 5 minutes via Update Policy
- **`postgres_error_metrics`**: Updated every 1 minute via Update Policy
- **`postgres_user_metrics`**: Updated every 1 hour via Update Policy
- **Initial Training**: Requires 7-30 days of historical data for ML baseline

**Verify Data Freshness**:
```kql
// Raw logs freshness
bronze_pssql_alllogs_nometrics
| summarize LatestLog = max(EventProcessedUtcTime)
| extend 
    Lag = now() - LatestLog,
    Status = iff(Lag > 5m, "🔴 Delayed", "✅ Real-time")

// ML metrics freshness
postgres_activity_metrics
| summarize LatestMetric = max(Timestamp)
| extend 
    Lag = now() - LatestMetric,
    Status = iff(Lag > 10m, "🔴 Delayed", "✅ Normal")
```

---

## 🧪 Testing & Validation

### **Sample Queries for Data Agent Testing**

```kql
// 1. Check if data exists
bronze_pssql_alllogs_nometrics
| take 10

// 2. Verify pgaudit is enabled
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| take 10
| project TimeGenerated, message

// 3. Verify sessionInfo correlation works
let sessionInfo = [see above];
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| join kind=leftouter sessionInfo on processId, LogicalServerName
| where isnotempty(User)
| take 10
| project TimeGenerated, User, Database, SourceHost, message

// 4. Check error code coverage
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where sqlerrcode != "00000" and sqlerrcode != ""
| summarize Count = count() by sqlerrcode, errorLevel
| order by Count desc
```

### **ML Metrics Tables Validation (v3)**

```kql
// 5. Verify postgres_activity_metrics is populating
postgres_activity_metrics
| order by Timestamp desc
| take 20

// 6. Check for PrivilegeOps (security-critical)
postgres_activity_metrics
| where Timestamp >= ago(7d)
| where PrivilegeOps > 0
| project Timestamp, ServerName, PrivilegeOps, DDLOps
| order by Timestamp desc

// 7. Verify temporal columns are correct
postgres_activity_metrics
| where Timestamp >= ago(24h)
| summarize Count = count() by HourOfDay
| order by HourOfDay asc

// 8. Test ML anomaly detection works
postgres_activity_metrics
| where Timestamp >= ago(7d)
| make-series ActivitySeries = avg(ActivityCount) on Timestamp step 5m by ServerName
| extend (anomalies, score, baseline) = series_decompose_anomalies(ActivitySeries)
| take 1

// 9. Verify postgres_error_metrics
postgres_error_metrics
| where Timestamp >= ago(24h)
| summarize TotalErrors = sum(ErrorRate) by ServerName

// 10. Verify postgres_user_metrics
postgres_user_metrics
| where Timestamp >= ago(7d)
| summarize TotalQueries = sum(QueryCount), TotalDestructive = sum(DestructiveOps) by UserName
| order by TotalQueries desc
| take 10
```

---

## 📚 Related Documentation

- **PostgreSQL Error Codes**: https://www.postgresql.org/docs/current/errcodes-appendix.html
- **pgaudit Extension**: https://github.com/pgaudit/pgaudit
- **Azure PostgreSQL Logging**: https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-logging
- **KQL Language Reference**: https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/

---

## 🆘 Troubleshooting

### **Issue: No AUDIT logs appearing**

**Diagnosis**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| summarize Count = count() by HasAudit = message contains "AUDIT:"
```

**Solution**:
1. Check pgaudit is enabled: `SHOW shared_preload_libraries;` → should include `pgaudit`
2. Check pgaudit config: `SHOW pgaudit.log;` → should include `read,write,ddl`
3. Restart PostgreSQL server after changing `shared_preload_libraries`

---

### **Issue: User/Database/Host always "UNKNOWN"**

**Diagnosis**:
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "connection authorized"
| take 10
```

**Solution**:
1. If no CONNECTION logs: Enable `log_connections = on` in Server Parameters
2. If processId mismatch: Widen sessionInfo time window (use `ago(7d)` instead of `ago(24h)`)
3. If still failing: Use direct extraction (check if user/database in AUDIT message)

---

### **Issue: Queries too slow**

**Diagnosis**:
```kql
// Check table size
bronze_pssql_alllogs_nometrics
| summarize TotalRows = count(), DataSize = estimate_data_size(*)
```

**Solution**:
1. Always use time filters: `| where EventProcessedUtcTime >= ago(24h)`
2. Reduce sessionInfo window: Use smallest time range that works
3. Use materialized views (Update Policy) for common queries
4. Consider data retention policy (purge old logs)

---

### **Issue: ML Metrics tables not updating**

**Diagnosis**:
```kql
// Check Update Policy status
.show table postgres_activity_metrics policy update

// Check for ingestion failures
.show ingestion failures
| where Table == "postgres_activity_metrics"
| order by FailedOn desc
| take 20
```

**Solution**:
1. Verify Update Policy is enabled: `IsEnabled: true`
2. Check source table has data: `bronze_pssql_alllogs_nometrics | take 10`
3. Force refresh: `.refresh table postgres_activity_metrics`
4. Check for schema mismatches in transform function

---

### **Issue: No anomalies detected (ML not working)**

**Diagnosis**:
```kql
// Check data volume (need 7+ days for ML)
postgres_activity_metrics
| summarize MinTime = min(Timestamp), MaxTime = max(Timestamp), Records = count()
```

**Solution**:
1. Ensure at least 7 days of historical data exists
2. Adjust sensitivity: Change threshold from 1.5 to 1.0 for more sensitive detection
3. Check data variance: ML needs variation to detect anomalies
4. Use `| take 100` to verify make-series returns data

---

**End of Data Source Instructions**
