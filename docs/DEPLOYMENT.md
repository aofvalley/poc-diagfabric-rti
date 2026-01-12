# 🚀 Deployment Guide

## Prerequisites

1. **Fabric CLI (fab)** installed
   ```bash
   pip install ms-fabric-cli
   ```

2. **Authenticated** to Fabric
   ```bash
   fab auth login
   ```

3. **Azure PostgreSQL** with pgaudit enabled and Diagnostic Settings configured

---

## Quick Deployment

### Using Fabric CLI (recommended)

```bash
# Bash/Linux/Mac
./scripts/deploy-fabric.sh "MyWorkspace"

# PowerShell/Windows
.\scripts\deploy-fabric.ps1 -WorkspaceName "MyWorkspace"
```

The script will:
1. Create Eventhouse `PostgreSQLMonitor`
2. Create KQL Database `SecurityLogs`
3. Deploy tables and functions from `ANOMALY-DETECTION-SETUP.kql`

---

### Manual Deployment

If you prefer to set up manually:

1. **Create Eventhouse**
   ```bash
   fab cd "MyWorkspace"
   fab mkdir "PostgreSQLMonitor.Eventhouse"
   ```

2. **Create KQL Database**
   ```bash
   fab cd "PostgreSQLMonitor.Eventhouse"
   fab mkdir "SecurityLogs.KQLDatabase"
   ```

3. **Run KQL Setup**
   ```bash
   fab cd "SecurityLogs.KQLDatabase"
   fab run --file queries/ANOMALY-DETECTION-SETUP.kql
   ```

4. **Create Event Stream** (in Fabric Portal)
   - Source: Azure Event Hub (from PostgreSQL Diagnostic Settings)
   - Destination: `bronze_pssql_alllogs_nometrics` table

5. **Create Dashboard** (in Fabric Portal)
   - New → Real-Time Dashboard
   - Add tiles using `queries/kql-queries-PRODUCTION.kql`

---

## Validate Deployment

```kql
// Check data is flowing
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| count

// Check metrics table
postgres_activity_metrics
| order by Timestamp desc
| take 10
```

---

## Test Anomaly Detection

Execute `TEST-ANOMALY-TRIGGERS.sql` in PostgreSQL:
- **Tests 1-4**: Basic anomalies
- **Tests 5-8**: Advanced anomalies (Defender-proof)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `fab` not found | `pip install ms-fabric-cli` |
| Not authenticated | `fab auth login` |
| No data in logs | Check Event Stream is running |
| ML not detecting | Need 7+ days of data |
