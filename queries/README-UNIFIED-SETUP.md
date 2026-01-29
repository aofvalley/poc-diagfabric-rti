# 🎯 PostgreSQL Anomaly Detection - Unified Setup

This document describes the unified `UNIFIED-ANOMALY-DETECTION.kql` file that consolidates the entire PostgreSQL anomaly detection system for Microsoft Fabric Real-Time Intelligence.

## 📋 File Content

### **SECTION 1: Setup - Infrastructure Creation**

#### 1.1-1.2: Main Activity Metrics Table
```kql
.create table postgres_activity_metrics (...)
.create-or-alter function postgres_activity_metrics_transform() {...}
```
**Purpose**: Aggregated metrics table in 5-minute windows with temporal dimensions (hour of day, day of week) for ML.

**Key Columns**:
- `ActivityCount`, `AuditLogs`, `Errors`, `Connections`
- `UniqueUsers`: Detects abnormal user cardinality
- `SelectOps`, `WriteOps`, `DDLOps`: Operations breakdown
- `PrivilegeOps`: GRANT/REVOKE for detecting privilege escalation
- `HourOfDay`, `DayOfWeek`: Temporal patterns

#### 1.3-1.4: Update Policy and Historical Load
```kql
.alter table postgres_activity_metrics policy update @'[...]'
.set-or-append postgres_activity_metrics <| ...
```
**Purpose**: Automatic pipeline that updates the table in real-time + loads 30 days of history to train ML model.

#### 1.5-1.6: Auxiliary Tables
- **`postgres_error_metrics`**: Error metrics per server (1-minute windows)
- **`postgres_user_metrics`**: Activity per user with session correlation (1-hour windows)

---

### **SECTION 2: Real-Time Anomaly Queries**

#### 2.1 Massive Data Extraction (Data Exfiltration)
**Threshold**: >15 SELECTs in 5 minutes  
**Detects**: Massive queries, COPY, pg_dump  
**Severity**: MEDIUM (15-30), HIGH (30-50), CRITICAL (>50)

#### 2.2 Massive Destructive Operations
**Threshold**: >5 destructive operations in 2 minutes  
**Detects**: DELETE, UPDATE, TRUNCATE, DROP TABLE/DATABASE  
**Severity**: MEDIUM (5-10), HIGH (10-20), CRITICAL (>20)

#### 2.3 Critical Error Spike
**Threshold**: >3 errors in 1 minute  
**Detects**: ERROR, FATAL, PANIC, SQL error codes  
**Categories**: Authentication, Permission, Connection, Resource, Other  
**Severity**: MEDIUM (3-8), HIGH (8-15), CRITICAL (>15)

#### 2.4 Privilege Escalation
**Threshold**: >3 privilege operations in 5 minutes  
**Detects**: GRANT, REVOKE, ALTER ROLE, CREATE/DROP ROLE  
**Severity**: MEDIUM (3-5), HIGH (5-10), CRITICAL (>10)

#### 2.5 Cross-Schema Reconnaissance (Lateral Movement)
**Threshold**: >4 different schemas accessed in 10 minutes  
**Detects**: Access to multiple schemas (lateral movement)  
**Severity**: MEDIUM (4-5), HIGH (5-8), CRITICAL (>8)

#### 2.6 System Schema Enumeration (Deep Scan)
**Threshold**: >10 queries to system tables in 5 minutes  
**Detects**: pg_catalog, information_schema, pg_tables, pg_class, etc.  
**Severity**: MEDIUM (10-15), HIGH (15-30), CRITICAL (>30)  
**RiskLevel**: 🔴 HIGH (>5 tables), 🟠 MEDIUM

#### 2.7 ML Anomaly Detection - Baseline Deviation
**Algorithm**: `series_decompose_anomalies()` with sensitivity 1.5  
**Lookback**: 7 days to establish normal baseline  
**Detection**: High anomalies (📈) or low anomalies (📉)  
**Severity**: MEDIUM (score 1.5-2.0), HIGH (2.0-3.0), CRITICAL (>3.0)

---

### **SECTION 3: Main Dashboard**

**Unified query** that combines all anomalies in a single view:
```kql
union
    (suspiciousDataAccess),
    (destructiveOperations),
    (errorSpike),
    (privilegeEscalation),
    (crossSchemaRecon),
    (deepSchemaEnum)
| order by TimeGenerated desc
| take 100;
```

**View**: Top 100 most recent anomalies of all types, ordered by timestamp.

---

### **SECTION 4: Operational Metrics Dashboards**

#### 4.1 General Activity per Server (1h)
Line chart with total events, errors, warnings, and audit logs per server.

#### 4.2 AUDIT Operations Distribution (6h)
Pie chart with operation types: SELECT, INSERT, UPDATE, DELETE, DDL, etc.

#### 4.3 Top 15 Most Accessed Tables (6h)
List of tables with highest access count, object types, and last access.

#### 4.4 AUDIT Operations Timeline (1h)
Line chart by operation type (SELECT, WRITE, DELETE, INSERT, DDL, MISC).

#### 4.5 Errors by Category (24h)
Area chart with categories: Auth, Permission, Connection, Resource, Other.

#### 4.6 Activity by Backend Type (1h)
Line chart comparing `client backend` vs `autovacuum`, `checkpointer`, etc.

#### 4.7 TOP 10 Users by Activity (24h)
Table with: TotalActivity, AuditLogs, Connections, Errors, Databases, LastActivity.

#### 4.8 TOP 10 Hosts/IPs by Connections (24h)
Table with: TotalConnections, UniqueUsers, ErrorRate, Risk (HIGH/MEDIUM/LOW).

#### 4.9 Heat Map User + Database (24h)
Activity matrix by user-database combination (ActivityCount > 10).

#### 4.10 Authentication Failures (24h)
Table with failed attempts by user/host, ThreatLevel (CRITICAL/HIGH/MEDIUM/LOW).

#### 4.11 Top Error Codes (24h)
Top 15 SQL error codes with description and category.

---

### **SECTION 5: Monitoring and Validation Queries**

#### 5.1 Verify Metrics Tables Status
```kql
postgres_activity_metrics | order by Timestamp desc | take 20;
```
Confirms tables are updating correctly.

#### 5.2 Verify Data Freshness
Shows data latency (✅ Fresh < 5min, ⚠️ Stale > 5min).

#### 5.3 AUDIT Log Coverage
Percentage of AUDIT logs vs total, per server.

#### 5.4 Backend Types Distribution
Event count by backend type (validation of filters).

---

### **SECTION 6: Troubleshooting & Maintenance**

#### View active Update Policies
```kql
.show table postgres_activity_metrics policy update
```

#### View ingestion errors
```kql
.show ingestion failures
| where Table in ("postgres_activity_metrics", "postgres_error_metrics", "postgres_user_metrics")
```

#### Force manual refresh (commented by default)
```kql
// .refresh table postgres_activity_metrics
```

---

### **SECTION 7: Cleanup (Optional)**

Commands to delete all tables and functions (ONLY to restart from scratch):
```kql
// .drop table postgres_activity_metrics ifexists
// .drop table postgres_error_metrics ifexists
// .drop table postgres_user_metrics ifexists
// ...
```

---

## 🚀 Implementation Guide

### Step 1: Create Metrics Tables
Run queries from **SECTION 1** (1.1 to 1.6) in order:

1. Create `postgres_activity_metrics`
2. Create function `postgres_activity_metrics_transform()`
3. Configure Update Policy
4. Load historical data (30 days)
5. Repeat for `postgres_error_metrics`
6. Repeat for `postgres_user_metrics`

**Estimated time**: 5-10 minutes (depends on historical data volume).

---

### Step 2: Verify Tables are Updating
Run queries from **SECTION 5.1**:
```kql
postgres_activity_metrics | order by Timestamp desc | take 20;
```

**Expected**: You should see records with recent timestamps (last 5-10 minutes).

---

### Step 3: Configure Anomaly Detector in Fabric UI

> **⚠️ IMPORTANT**: For ML anomaly (2.7) to work, you must configure the anomaly detector in Fabric UI.

1. Open your **KQL Database** in Fabric Real-Time Intelligence
2. Click on the `postgres_activity_metrics` table
3. Click **"Anomaly detection"** (top button)
4. Configure:
   - **Table**: `postgres_activity_metrics`
   - **Timestamp column**: `Timestamp`
   - **Value to watch**: `ActivityCount`
   - **Group by dimension**: `ServerName`
   - **Sensitivity**: `Medium` (adjust later based on results)
   - **Lookback period**: `7 days`
5. Click **"Create"**
6. Wait **5-10 minutes** for model to train

---

### Step 4: Create Dashboards in Fabric

#### Dashboard 1: **Real-Time Anomalies**
- Pin query from **SECTION 3** (Main Dashboard)
- Visualization: **Table** with columns: TimeGenerated, AnomalyType, Severity, ServerName, User
- Refresh: **Auto-refresh every 1 minute**

#### Dashboard 2: **Operational Metrics**
Create individual tiles with queries from **SECTION 4**:

| Tile | Query | Chart Type | Refresh |
|------|-------|-----------|---------|
| 4.1 | General Activity | Timechart | 2min |
| 4.2 | AUDIT Distribution | Piechart | 5min |
| 4.3 | Top Tables | Table | 5min |
| 4.4 | AUDIT Timeline | Timechart | 2min |
| 4.5 | Errors Categories | Areachart | 5min |
| 4.6 | Backend Type | Timechart | 2min |
| 4.7 | TOP Users | Table | 10min |
| 4.8 | TOP Hosts | Table | 10min |
| 4.9 | Heat Map User+DB | Table | 10min |
| 4.10 | Auth Failures | Table | 10min |
| 4.11 | Top Error Codes | Table | 10min |

---

### Step 5: Configure Alerts

Configure alerts in Fabric for each critical anomaly:

#### Alert 1: Data Exfiltration
- **Query**: `suspiciousDataAccess` (SECTION 2.1)
- **Condition**: `Severity == "CRITICAL"`
- **Frequency**: Every 5 minutes
- **Action**: Email + Teams

#### Alert 2: Destructive Operations
- **Query**: `destructiveOperations` (SECTION 2.2)
- **Condition**: `Severity in ("CRITICAL", "HIGH")`
- **Frequency**: Every 2 minutes
- **Action**: Email + Teams + SMS

#### Alert 3: Privilege Escalation
- **Query**: `privilegeEscalation` (SECTION 2.4)
- **Condition**: `Severity in ("CRITICAL", "HIGH")`
- **Frequency**: Every 5 minutes
- **Action**: Email + Teams + Incident in Sentinel

#### Alert 4: ML Anomaly Detection
- **Query**: `mlAnomalyDetection` (SECTION 2.7)
- **Condition**: `Severity == "CRITICAL" and abs(DeviationScore) > 3.0`
- **Frequency**: Every 5 minutes
- **Action**: Email + Teams

---

## 📊 Key Metrics for Monitoring

### Security Metrics
1. **Anomalies detected by type** (last 24h)
2. **Anomaly severity** (CRITICAL/HIGH/MEDIUM)
3. **Users with anomalous behavior** (last 24h)
4. **Suspicious hosts/IPs** (ErrorRate > 10%)
5. **Authentication failures** (FailedAttempts > 10)

### Operational Metrics
1. **Data latency** (should be < 5 minutes)
2. **AUDIT log coverage** (should be > 80%)
3. **Error rate** (ErrorRate per server)
4. **Activity by hour of day** (baseline for ML)
5. **Backend Types distribution** (validate filters)

### ML Metrics
1. **Baseline deviation** (DeviationScore)
2. **High vs low anomalies** (📈 vs 📉)
3. **Model accuracy** (false positives)
4. **Adjusted baseline** (ExpectedBaseline vs ActivityCount)

---

## 🛠️ Troubleshooting

### Problem 1: Metrics tables not updating
**Solution**:
1. Verify the Update Policy is active:
   ```kql
   .show table postgres_activity_metrics policy update
   ```
2. Check ingestion errors:
   ```kql
   .show ingestion failures | where Table == "postgres_activity_metrics"
   ```
3. Force manual refresh:
   ```kql
   .refresh table postgres_activity_metrics
   ```

### Problem 2: ML Anomaly Detection returns no results
**Possible causes**:
- Model hasn't trained yet (wait 5-10 minutes after creating detector)
- Not enough historical data (minimum 7 days)
- Sensitivity too high (adjust to 1.0 or 1.2)

**Solution**:
```kql
// Verify historical data exists
postgres_activity_metrics
| where Timestamp >= ago(7d)
| summarize count() by ServerName
```

### Problem 3: Too many false positives
**Solution**: Adjust thresholds in anomaly queries:
- `suspiciousDataAccess`: Increase from 15 to 25 SELECTs
- `destructiveOperations`: Increase from 5 to 10 operations
- `errorSpike`: Increase from 3 to 5 errors
- ML Anomaly: Reduce sensitivity from 1.5 to 1.8

### Problem 4: User/Database/Host correlation not working
**Possible causes**:
- Connection logs not arriving
- `processId` mismatch between AUDIT and CONNECTION logs

**Solution**:
```kql
// Verify connection logs
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "connection authorized"
| take 10
```

---

## 📚 Differences from Previous Files

### Changes vs `kql-queries-PRODUCTION.kql`
- ✅ **Added**: Complete Setup sections (tables, functions, policies)
- ✅ **Added**: Dynamic severity in all anomalies
- ✅ **Improved**: Inline correlation instead of global `let sessionInfo`
- ✅ **Organized**: Modular structure by numbered sections

### Changes vs `ANOMALY-DETECTION-SETUP.kql`
- ✅ **Added**: All RTI anomaly queries (7 types)
- ✅ **Added**: Complete operational dashboards (11 tiles)
- ✅ **Added**: Validation and troubleshooting queries
- ✅ **Improved**: Inline documentation for each section

---

## 🎯 Recommended Next Steps

1. **Threshold Optimization**: After 1 week, adjust thresholds based on your real baseline
2. **ML Tuning**: Adjust anomaly model sensitivity (1.0 - 2.0)
3. **Advanced Alerts**: Integrate with Microsoft Sentinel for SOAR
4. **Custom Dashboards**: Create team-specific views (Security, DBA, DevOps)
5. **Data Retention**: Configure retention policies for metrics tables (default 90 days)

---

## 📧 Support

For questions or issues:
1. Review **SECTION 6: Troubleshooting**
2. Check **SECTION 5: Validation Queries**
3. Consult ingestion logs: `.show ingestion failures`

---

**Version**: 1.0 - Unified Setup  
**Last updated**: 2026-01-25  
**Autor**: Anomaly Detection Team
