# 🚨 Activator Alert Rules Strategy

This document defines the specific alert rules to be configured in **Microsoft Fabric Activator**. These rules function as the "nervous system" of the security monitoring solution, triggering real-time actions when the KQL queries detect anomalies.

---

## 🟢 1. Core Security Alerts

These alerts detect deterministic attack patterns based on fixed thresholds.

### 1.1. Mass Data Exfiltration
*   **Goal**: Detect if a user is rapidly accessing a large number of tables or selecting massive amounts of data.
*   **Condition**:
    *   **Trigger**: `SelectCount > 15` in a 5-minute window.
    *   **Severity**:
        *   **Critical**: `> 50` selects.
        *   **High**: `> 30` selects.
*   **Activator Logic**:
    *   **Check**: Monitor the `SelectCount` column from the `suspiciousDataAccess` query.
    *   **Action**: Send Email to Admin + Teams Notification.

    > **KQL Query for Alert:**
    > ```kql
    > bronze_pssql_alllogs_nometrics
    > | where EventProcessedUtcTime >= ago(5m)
    > | where category == "PostgreSQLLogs"
    > | where message contains "AUDIT:"
    > | where message has_any ("SELECT", "COPY", "pg_dump")
    > | where backend_type == "client backend"
    > | extend 
    >     AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    >     AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
    >     TableName = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message),
    >     QueryText = trim('"', extract(@",,,([^<]+)<", 1, message)),
    >     ProcessSession = strcat(LogicalServerName, "-", processId),
    >     DirectUser = extract(@"user=([^\s,]+)", 1, message),
    >     DirectDatabase = extract(@"database=([^\s,]+)", 1, message),
    >     DirectHost = extract(@"host=([^\s]+)", 1, message)
    > | where AuditOperation == "READ" or AuditStatement == "SELECT"
    > | extend FinalUser = iff(isnotempty(DirectUser), DirectUser, "UNKNOWN")
    > | where FinalUser != "azuresu"
    > | summarize SelectCount = count() by ProcessSession, LogicalServerName, backend_type, processId
    > | where SelectCount > 15
    > ```

### 1.2. Mass Destructive Operations
*   **Goal**: Prevent data loss by detecting rapid destructive commands (`DELETE`, `DROP`, `TRUNCATE`).
*   **Condition**:
    *   **Trigger**: `OperationCount > 5` in a 2-minute window.
    *   **Severity**:
        *   **Critical**: `> 20` operations.
        *   **High**: `> 10` operations.
*   **Activator Logic**:
    *   **Check**: Monitor `OperationCount` from the `destructiveOperations` query.
    *   **Action**: **IMMEDIATE** Email to Security Team + Trigger blocking script (if configured).

    > **KQL Query for Alert:**
    > ```kql
    > bronze_pssql_alllogs_nometrics
    > | where EventProcessedUtcTime >= ago(10m)
    > | where category == "PostgreSQLLogs"
    > | where message contains "AUDIT:"
    > | where message has_any ("DELETE", "UPDATE", "TRUNCATE", "DROP TABLE", "DROP DATABASE")
    > | extend 
    >     AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    >     AuditStatement = trim(' ', extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message)),
    >     DirectUser = extract(@"user=([^\s,]+)", 1, message)
    > | where message has_any ("DELETE", "UPDATE", "TRUNCATE", "DROP")
    > | where AuditOperation == "WRITE" or AuditStatement has_any ("DELETE", "UPDATE", "TRUNCATE", "DROP")
    > | extend FinalUser = iff(isnotempty(DirectUser), DirectUser, "UNKNOWN")
    > | where FinalUser !in ("azuresu", "azure_maintenance", "UNKNOWN")
    > | summarize OperationCount = count() by LogicalServerName, backend_type, bin(EventProcessedUtcTime, 2m)
    > | where OperationCount > 5
    > | where backend_type == "client backend"
    > ```

### 1.3. Privilege Escalation Attempt
*   **Goal**: Detect any attempt to grant permissions or modify roles (PostgreSQL typically generates warnings/errors for unauthorized attempts, or we track successful ones).
*   **Condition**:
    *   **Trigger**: `PrivilegeOpsCount > 1` in a 5-minute window.
*   **Activator Logic**:
    *   **Check**: Monitor `PrivilegeOpsCount` from the `privilegeEscalation` query.
    *   **Action**: Send High Priority Email.

    > **KQL Query for Alert:**
    > ```kql
    > bronze_pssql_alllogs_nometrics
    > | where EventProcessedUtcTime >= ago(15m)
    > | where category == "PostgreSQLLogs"
    > | where message has_any ("GRANT", "REVOKE", "ALTER ROLE", "CREATE ROLE", "DROP ROLE", "anomaly_test")
    > | where backend_type == "client backend" or isempty(backend_type)
    > | extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
    > | extend FinalUser = iff(isnotempty(DirectUser), DirectUser, "UNKNOWN")
    > | where FinalUser !in ("azuresu", "azure_maintenance")
    > | summarize PrivilegeOpsCount = count() by LogicalServerName, bin(EventProcessedUtcTime, 5m)
    > | where PrivilegeOpsCount > 1
    > ```

### 1.4. Critical Error Spike
*   **Goal**: Detect brute-force attacks (auth errors) or system instability.
*   **Condition**:
    *   **Trigger**: `ErrorCount > 3` in a 1-minute window.
    *   **Severity**:
        *   **Critical**: `> 15` errors.
        *   **High**: `> 8` errors.
*   **Activator Logic**:
    *   **Check**: Monitor `ErrorCount` from the `errorSpike` query.
    *   **Action**: Email to DevOps/Admin.

    > **KQL Query for Alert:**
    > ```kql
    > bronze_pssql_alllogs_nometrics
    > | where EventProcessedUtcTime >= ago(15m)
    > | where category == "PostgreSQLLogs"
    > | where errorLevel in ("ERROR", "FATAL", "PANIC") or (sqlerrcode != "00000" and sqlerrcode != "")
    > | summarize ErrorCount = count() by LogicalServerName, backend_type, bin(EventProcessedUtcTime, 1m)
    > | where ErrorCount > 3
    > ```

---

## 🟠 2. Reconnaissance Detection

These alerts detect the "pre-attack" phase where an attacker maps the database.

### 2.1. Cross-Schema Reconnaissance
*   **Goal**: Detect lateral movement across different database schemas.
*   **Condition**:
    *   **Trigger**: `SchemasAccessed > 4` in a 10-minute window.
*   **Activator Logic**:
    *   **Check**: Monitor `SchemasAccessed` from the `crossSchemaRecon` query.
    *   **Action**: Warning Email to Admin.

    > **KQL Query for Alert:**
    > ```kql
    > bronze_pssql_alllogs_nometrics
    > | where EventProcessedUtcTime >= ago(15m)
    > | where category == "PostgreSQLLogs"
    > | where message contains "AUDIT:"
    > | where backend_type == "client backend"
    > | extend 
    >     SchemaAccessed = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^\.]+)\.", 1, message),
    >     TableAccessed = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message),
    >     DirectUser = extract(@"user=([^\s,]+)", 1, message)
    > | where isnotempty(SchemaAccessed) or isnotempty(TableAccessed)
    > | extend SchemaName = iff(isnotempty(SchemaAccessed), SchemaAccessed, extract(@"^([^\.]+)\.", 1, TableAccessed))
    > | where isnotempty(SchemaName) and SchemaName !in ("pg_catalog", "information_schema", "")
    > | extend FinalUser = iff(isnotempty(DirectUser), DirectUser, "UNKNOWN")
    > | where FinalUser != "azuresu"
    > | summarize SchemasAccessed = dcount(SchemaName) by LogicalServerName, processId, bin(EventProcessedUtcTime, 10m)
    > | where SchemasAccessed > 4
    > ```

### 2.2. Deep System Enumeration
*   **Goal**: Detect specific queries targeting system catalogs (`pg_catalog`, `information_schema`) to map the database structure.
*   **Condition**:
    *   **Trigger**: `SystemTableQueries > 10` in a 5-minute window.
*   **Risk**: **High** if `UniqueSystemTables > 5`.
*   **Activator Logic**:
    *   **Check**: Monitor `SystemTableQueries` from the `deepSchemaEnum` query.
    *   **Action**: Warning Email to Admin.

    > **KQL Query for Alert:**
    > ```kql
    > bronze_pssql_alllogs_nometrics
    > | where EventProcessedUtcTime >= ago(10m)
    > | where category == "PostgreSQLLogs"
    > | where message contains "AUDIT:"
    > | where backend_type == "client backend"
    > | where message has_any ("pg_catalog", "information_schema", "pg_tables", "pg_class", 
    >         "pg_attribute", "pg_proc", "pg_type", "pg_constraint", "pg_roles", "pg_indexes",
    >         "table_constraints", "table_privileges", "routines")
    > | extend QueryText = coalesce(trim('"', extract(@",,,([^<]+)<", 1, message)), extract(@"statement: (.+)$", 1, message), message)
    > | extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
    > | extend FinalUser = iff(isnotempty(DirectUser), DirectUser, "UNKNOWN")
    > | where FinalUser != "azuresu"
    > | summarize SystemTableQueries = count() by LogicalServerName, processId, bin(EventProcessedUtcTime, 5m)
    > | where SystemTableQueries > 10
    > ```

---

## 🔵 3. ML-Based Behavioral Alerts

These alerts use the Machine Learning model to detect "unknown unknowns"—activity that is statistically unusual for that specific time and day.

### 3.1. Behavioral Baseline Deviation
*   **Goal**: Detect anomalies that don't match static rules (e.g., a massive `SELECT` at 3 AM from a user who usually works at 9 AM).
*   **Condition**:
    *   **Trigger**: `series_decompose_anomalies` score `> 3.0` (or `<-3.0`).
    *   **Metric**: Total Activity Count (`ActivityCount` in `postgres_activity_metrics`).
*   **Activator Logic**:
    *   **Check**: Monitor the `DeviationScore` from the `mlAnomalyDetection` query.
    *   **Action**: Email to Security Analyst for review (requires human triage).

    > **KQL Query for Alert:**
    > ```kql
    > postgres_activity_metrics
    > | where Timestamp >= ago(7d)
    > | where isnotempty(ServerName)
    > | make-series ActivitySeries = sum(ActivityCount) default=0 on Timestamp step 5m by ServerName
    > | extend (anomalies, score, baseline) = series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
    > | mv-expand Timestamp to typeof(datetime), ActivitySeries to typeof(long), anomalies to typeof(int), score to typeof(double), baseline to typeof(double)
    > | where anomalies != 0
    > | where Timestamp >= ago(1h)
    > | where abs(score) > 3.0
    > ```

---

## ⚙️ Configuration Summary

| Alert Name | Query Source | Trigger Field | Threshold | Action |
| :--- | :--- | :--- | :--- | :--- |
| **Data Exfil** | `suspiciousDataAccess` | `SelectCount` | `> 15` | Email + Teams |
| **Destruction** | `destructiveOperations` | `OperationCount` | `> 5` | **URGENT Email** |
| **Privilege** | `privilegeEscalation` | `PrivilegeOpsCount` | `> 1` | High Priority Email |
| **Error Spike** | `errorSpike` | `ErrorCount` | `> 3` | Email |
| **Recon (Schema)** | `crossSchemaRecon` | `SchemasAccessed` | `> 4` | Warning Email |
| **Recon (Deep)** | `deepSchemaEnum` | `SystemTableQueries` | `> 10` | Warning Email |
| **ML Anomaly** | `mlAnomalyDetection` | `DeviationScore` | `> 3.0` | Review Email |
