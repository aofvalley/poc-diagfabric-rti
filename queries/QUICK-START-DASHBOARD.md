# 🚀 Quick Start - Queries for Real-Time Dashboard

This file contains the most important queries ready to copy and paste directly into your Microsoft Fabric Real-Time Intelligence dashboard.

---

## 📊 DASHBOARD 1: Real-Time Anomalies

### Main Query: All Anomalies (Top 100)
```kql
// ============================================================================
// MAIN DASHBOARD - ALL ANOMALIES
// ============================================================================

let suspiciousDataAccess = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where category == "PostgreSQLLogs"
| where message contains "AUDIT:"
| where message has_any ("SELECT", "COPY", "pg_dump")
| where backend_type == "client backend"
| extend 
    AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    DirectUser = extract(@"user=([^\s,]+)", 1, message),
    DirectDatabase = extract(@"database=([^\s,]+)", 1, message),
    DirectHost = extract(@"host=([^\s]+)", 1, message),
    TableName = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| where FinalUser != "azuresu"
| summarize 
    SelectCount = count(),
    FirstSeen = min(EventProcessedUtcTime),
    LastSeen = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, processId
| where SelectCount > 15
| extend 
    AnomalyType = "Data Exfiltration",
    Severity = case(SelectCount > 50, "CRITICAL", SelectCount > 30, "HIGH", "MEDIUM")
| project TimeGenerated = LastSeen, AnomalyType, Severity, ServerName = LogicalServerName, User, SelectCount;

let destructiveOperations = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
| where category == "PostgreSQLLogs"
| where message contains "AUDIT:"
| where message has_any ("DELETE", "UPDATE", "TRUNCATE", "DROP")
| where backend_type == "client backend"
| extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| summarize 
    OperationCount = count(),
    FirstOp = min(EventProcessedUtcTime),
    LastOp = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, bin(EventProcessedUtcTime, 2m)
| where OperationCount > 5
| extend 
    AnomalyType = "Destructive Operations",
    Severity = case(OperationCount > 20, "CRITICAL", OperationCount > 10, "HIGH", "MEDIUM")
| project TimeGenerated = LastOp, AnomalyType, Severity, ServerName = LogicalServerName, User, OperationCount;

let errorSpike = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(15m)
| where category == "PostgreSQLLogs"
| where errorLevel in ("ERROR", "FATAL", "PANIC")
| extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| summarize 
    ErrorCount = count(),
    FirstError = min(EventProcessedUtcTime),
    LastError = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, bin(EventProcessedUtcTime, 1m)
| where ErrorCount > 3
| extend 
    AnomalyType = "Error Spike",
    Severity = case(ErrorCount > 15, "CRITICAL", ErrorCount > 8, "HIGH", "MEDIUM")
| project TimeGenerated = LastError, AnomalyType, Severity, ServerName = LogicalServerName, User, ErrorCount;

let privilegeEscalation = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
| where category == "PostgreSQLLogs"
| where message has_any ("GRANT", "REVOKE", "ALTER ROLE", "CREATE ROLE")
| extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| where FinalUser != "azuresu"
| summarize 
    PrivilegeOpsCount = count(),
    FirstOp = min(EventProcessedUtcTime),
    LastOp = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, bin(EventProcessedUtcTime, 5m)
| where PrivilegeOpsCount > 3
| extend 
    AnomalyType = "Privilege Escalation",
    Severity = case(PrivilegeOpsCount > 10, "CRITICAL", PrivilegeOpsCount > 5, "HIGH", "MEDIUM")
| project TimeGenerated = LastOp, AnomalyType, Severity, ServerName = LogicalServerName, User, PrivilegeOpsCount;

union (suspiciousDataAccess), (destructiveOperations), (errorSpike), (privilegeEscalation)
| order by TimeGenerated desc
| take 100;
```

**Dashboard Config**:
- **Type**: Table
- **Auto-refresh**: 1 minute
- **Visible columns**: TimeGenerated, AnomalyType, Severity, ServerName, User

---

## 📈 DASHBOARD 2: Real-Time Metrics

### Tile 1: General Activity by Server (1h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where isnotempty(LogicalServerName)
| summarize 
    TotalEvents = count(),
    Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    Warnings = countif(errorLevel == "WARNING"),
    AuditLogs = countif(message contains "AUDIT:")
    by LogicalServerName, bin(EventProcessedUtcTime, 2m)
| render timechart
```
**Config**: Timechart | Auto-refresh: 2 min

---

### Tile 2: AUDIT Operations Distribution (6h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(6h)
| where message contains "AUDIT:"
| extend AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message)
| where isnotempty(AuditStatement)
| summarize Count = count() by AuditStatement
| order by Count desc
| take 10
| render piechart;
```
**Config**: Piechart | Auto-refresh: 5 min

---

### Tile 3: Operations Timeline by Type (1h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| extend OperationType = case(
    message contains ",READ," or message contains ",SELECT,", "SELECT",
    message contains ",WRITE," or message contains ",UPDATE,", "WRITE",
    message contains ",DELETE,", "DELETE",
    message contains ",INSERT,", "INSERT",
    message contains ",DDL,", "DDL",
    "OTHER"
)
| summarize Count = count() by OperationType, bin(EventProcessedUtcTime, 2m)
| render timechart;
```
**Config**: Timechart | Auto-refresh: 2 min

---

### Tile 4: TOP 10 Users by Activity (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| extend UserName = extract(@"user=([^\s,]+)", 1, message)
| where isnotempty(UserName)
| summarize 
    TotalActivity = count(),
    AuditLogs = countif(message contains "AUDIT:"),
    Connections = countif(message contains "connection authorized"),
    Errors = countif(errorLevel in ("ERROR", "FATAL")),
    LastActivity = max(EventProcessedUtcTime)
    by UserName
| top 10 by TotalActivity desc
| project UserName, TotalActivity, AuditLogs, Connections, Errors, LastActivity;
```
**Config**: Table | Auto-refresh: 10 min

---

### Tile 5: Errors by Category (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where errorLevel in ("ERROR", "FATAL", "PANIC")
| extend ErrorCategory = case(
    message contains "authentication", "Auth Errors",
    message contains "permission", "Permission Errors",
    message contains "connection", "Connection Errors",
    sqlerrcode startswith "28", "Auth Errors",
    sqlerrcode startswith "42", "Permission Errors",
    sqlerrcode startswith "08", "Connection Errors",
    sqlerrcode startswith "53", "Resource Errors",
    "Other Errors"
)
| summarize Count = count() by ErrorCategory, bin(EventProcessedUtcTime, 30m)
| render areachart;
```
**Config**: Areachart | Auto-refresh: 5 min

---

### Tile 6: Authentication Failures (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "authentication failed" 
    or message contains "password authentication failed"
    or sqlerrcode == "28P01"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| summarize 
    FailedAttempts = count(),
    FirstAttempt = min(EventProcessedUtcTime),
    LastAttempt = max(EventProcessedUtcTime)
    by UserName, ClientHost
| extend ThreatLevel = case(
    FailedAttempts > 20, "CRITICAL",
    FailedAttempts > 10, "HIGH",
    FailedAttempts > 5, "MEDIUM",
    "LOW"
)
| order by FailedAttempts desc
| take 20
| project UserName, ClientHost, FailedAttempts, ThreatLevel, FirstAttempt, LastAttempt;
```
**Config**: Table | Auto-refresh: 10 min

---

### Tile 7: TOP Hosts by Connections (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| extend 
    ClientHost = extract(@"host=([^\s]+)", 1, message),
    UserName = extract(@"user=([^\s,]+)", 1, message)
| where isnotempty(ClientHost)
| summarize 
    TotalConnections = count(),
    UniqueUsers = dcount(UserName),
    Errors = countif(errorLevel in ("ERROR", "FATAL")),
    LastSeen = max(EventProcessedUtcTime)
    by ClientHost
| extend 
    ErrorRate = round((todouble(Errors) / TotalConnections) * 100, 2),
    Riesgo = case(
        round((todouble(Errors) / TotalConnections) * 100, 2) > 20, "HIGH",
        round((todouble(Errors) / TotalConnections) * 100, 2) > 5, "MEDIUM",
        "LOW"
    )
| top 10 by TotalConnections desc
| project ClientHost, TotalConnections, UniqueUsers, Errors, ErrorRate, Riesgo, LastSeen;
```
**Config**: Table | Auto-refresh: 10 min

---

## 🎯 DASHBOARD 3: ML Anomalies (Baseline Deviation)

### ML Query: Baseline Deviation
```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| where isnotempty(ServerName)
| make-series ActivitySeries = sum(ActivityCount) default=0 
    on Timestamp step 5m 
    by ServerName
| extend (anomalies, score, baseline) = 
    series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
| mv-expand Timestamp to typeof(datetime), 
    ActivitySeries to typeof(long), 
    anomalies to typeof(int), 
    score to typeof(double), 
    baseline to typeof(double)
| where anomalies != 0
| where Timestamp >= ago(1h)
| extend 
    AnomalyDirection = iff(anomalies > 0, "📈 Above Normal", "📉 Below Normal"),
    Severity = case(
        abs(score) > 3.0, "CRITICAL",
        abs(score) > 2.0, "HIGH",
        "MEDIUM"
    )
| project 
    Timestamp,
    ServerName,
    AnomalyDirection,
    Severity,
    ActivityCount = ActivitySeries,
    ExpectedBaseline = round(baseline, 0),
    DeviationScore = round(score, 2)
| order by abs(DeviationScore) desc
| take 20;
```
**Config**: Table | Auto-refresh: 5 min

---

## 🔍 DASHBOARD 4: System Health Monitoring

### Query: Data Freshness
```kql
bronze_pssql_alllogs_nometrics
| summarize 
    LastEvent = max(EventProcessedUtcTime),
    TotalEvents = count()
| extend 
    Status = iff(datetime_diff('minute', now(), LastEvent) < 5, "✅ Fresh", "⚠️ Stale"),
    LatencyMinutes = datetime_diff('minute', now(), LastEvent)
| project Status, LatencyMinutes, LastEvent, TotalEvents;
```
**Config**: Card/KPI | Auto-refresh: 1 min

---

### Query: AUDIT Logs Coverage
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| summarize 
    TotalLogs = count(),
    AuditLogs = countif(message contains "AUDIT:"),
    ErrorLogs = countif(errorLevel in ("ERROR", "FATAL", "PANIC"))
    by LogicalServerName
| extend 
    AuditCoverage = round((todouble(AuditLogs) / TotalLogs) * 100, 2),
    ErrorRate = round((todouble(ErrorLogs) / TotalLogs) * 100, 2)
| project LogicalServerName, TotalLogs, AuditCoverage, ErrorRate;
```
**Config**: Table | Auto-refresh: 5 min

---

### Query: Metrics Tables Status
```kql
postgres_activity_metrics
| summarize 
    LastUpdate = max(Timestamp),
    TotalRecords = count(),
    AvgActivity = avg(ActivityCount),
    MaxErrors = max(Errors)
    by ServerName
| extend 
    Status = iff(datetime_diff('minute', now(), LastUpdate) < 10, "✅ Healthy", "⚠️ Delayed"),
    DelayMinutes = datetime_diff('minute', now(), LastUpdate)
| project ServerName, Status, DelayMinutes, LastUpdate, TotalRecords, AvgActivity, MaxErrors;
```
**Config**: Table | Auto-refresh: 5 min

---

## 📋 Implementation Checklist

### ✅ Step 1: Create Infrastructure (one-time setup)
Execute all queries from **SECTION 1** of the `UNIFIED-ANOMALY-DETECTION.kql` file:
- [ ] Create table `postgres_activity_metrics`
- [ ] Create function `postgres_activity_metrics_transform()`
- [ ] Configure Update Policy
- [ ] Load historical data (30 days)
- [ ] Create table `postgres_error_metrics`
- [ ] Create table `postgres_user_metrics`

### ✅ Step 2: Configure Dashboard 1 - Anomalies
- [ ] Create new Dashboard "PostgreSQL - Real-Time Anomalies"
- [ ] Paste main query (Dashboard 1)
- [ ] Configure auto-refresh to 1 minute
- [ ] Add filters by ServerName and Severity

### ✅ Step 3: Configure Dashboard 2 - Metrics
- [ ] Create new Dashboard "PostgreSQL - Operational Metrics"
- [ ] Add Tile 1 (General Activity) - Timechart
- [ ] Add Tile 2 (AUDIT Distribution) - Piechart
- [ ] Add Tile 3 (Operations Timeline) - Timechart
- [ ] Add Tile 4 (TOP Users) - Table
- [ ] Add Tile 5 (Errors Category) - Areachart
- [ ] Add Tile 6 (Auth Failures) - Table
- [ ] Add Tile 7 (TOP Hosts) - Table

### ✅ Step 4: Configure Dashboard 3 - ML
- [ ] Configure Anomaly Detector in Fabric UI (see README-UNIFIED-SETUP.md)
- [ ] Create Dashboard "PostgreSQL - ML Anomalies"
- [ ] Paste ML query (Dashboard 3)
- [ ] Configure auto-refresh to 5 minutes

### ✅ Step 5: Configure Dashboard 4 - Health
- [ ] Create Dashboard "PostgreSQL - System Health"
- [ ] Add Data Freshness query (KPI)
- [ ] Add AUDIT Coverage query (Table)
- [ ] Add Metrics Status query (Table)

### ✅ Step 6: Configure Alerts
- [ ] Create alert for Data Exfiltration (Severity = CRITICAL)
- [ ] Create alert for Destructive Operations (Severity >= HIGH)
- [ ] Create alert for Privilege Escalation (Severity >= HIGH)
- [ ] Create alert for ML Anomalies (DeviationScore > 3.0)

---

## 🎨 Dashboard Customization

### Recommended Colors by Severity
- **CRITICAL**: 🔴 Red (`#DC3545`)
- **HIGH**: 🟠 Orange (`#FD7E14`)
- **MEDIUM**: 🟡 Yellow (`#FFC107`)
- **LOW**: 🟢 Green (`#28A745`)

### Recommended Icons
- **Data Exfiltration**: 📥 (download)
- **Destructive Operations**: 💣 (bomb)
- **Error Spike**: ⚡ (lightning)
- **Privilege Escalation**: 🔐 (lock)
- **ML Anomaly**: 🤖 (robot)

### Suggested Layout
```
Dashboard 1: Anomalies
┌─────────────────────────┐
│  Main Table (100%)      │
│  [TimeGenerated | Type  │
│   | Severity | Server]  │
└─────────────────────────┘

Dashboard 2: Metrics
┌──────────┬──────────┐
│ Tile 1   │ Tile 2   │
│ (50%)    │ (50%)    │
├──────────┴──────────┤
│ Tile 3 (100%)       │
├──────────┬──────────┤
│ Tile 4   │ Tile 5   │
│ (50%)    │ (50%)    │
├──────────┼──────────┤
│ Tile 6   │ Tile 7   │
│ (50%)    │ (50%)    │
└──────────┴──────────┘

Dashboard 3: ML
┌─────────────────────────┐
│  Tabla ML (100%)        │
│  [Timestamp | Direction│
│   | Score | Baseline]   │
└─────────────────────────┘

Dashboard 4: Health
┌─────┬─────┬─────┬─────┐
│ KPI │ KPI │ KPI │ KPI │
│ (25%)     (25%)   (25%)│
├─────────────────────────┤
│ Coverage Table (100%)   │
├─────────────────────────┤
│ Status Table (100%)     │
└─────────────────────────┘
```

---

**Version**: 1.0 Quick Start  
**Last updated**: 2026-01-25
