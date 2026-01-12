# 🚀 Deployment Guide

## Prerequisites

1. **Azure CLI** installed and logged in (`az login`)
2. **Fabric Workspace** with Real-Time Intelligence enabled
3. **Azure PostgreSQL** with pgaudit enabled and Diagnostic Settings configured

---

## Quick Deployment (3 steps)

### Option A: Using PowerShell Scripts

```powershell
# 1. Run full deployment (creates Eventhouse + KQL Database)
.\scripts\Deploy-FabricSolution.ps1 -WorkspaceId "your-workspace-guid"

# Or, if you already have a KQL Database:
# 2. Just setup the schema
.\scripts\Setup-KqlSchema.ps1 `
    -ClusterUri "https://your-eventhouse.kusto.fabric.microsoft.com" `
    -DatabaseName "SecurityLogs"
```

### Option B: Manual Setup in Fabric Portal

1. **Create Eventhouse**
   - Fabric Portal → Workspace → New → Eventhouse
   - Name: `PostgreSQLMonitor`

2. **Create Event Stream**
   - New → Eventstream
   - Source: Azure Event Hub (from PostgreSQL Diagnostic Settings)
   - Destination: KQL Database table `bronze_pssql_alllogs_nometrics`

3. **Run KQL Setup**
   - Open your KQL Database
   - Copy/paste commands from `queries/ANOMALY-DETECTION-SETUP.kql`

4. **Create Dashboard**
   - New → Real-Time Dashboard
   - Add tiles using queries from `queries/kql-queries-PRODUCTION.kql`

---

## Validate Deployment

```kql
// Check data is flowing
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| count

// Check metrics table is being populated
postgres_activity_metrics
| order by Timestamp desc
| take 10
```

---

## Test Anomaly Detection

Execute `TEST-ANOMALY-TRIGGERS.sql` in your PostgreSQL:
- **Tests 1-4**: Basic anomalies (Data Exfiltration, Destructive Ops, Error Spike)
- **Tests 5-8**: Advanced anomalies (Privilege Escalation, Cross-Schema, Deep Enum)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No data in logs table | Check Event Stream is running |
| User/Database = UNKNOWN | Enable pgaudit (`SHOW pgaudit.log;`) |
| ML not detecting | Need 7+ days of data |
