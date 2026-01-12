<#
.SYNOPSIS
    Quick setup script - Run KQL commands on existing Fabric database
.DESCRIPTION
    Use this if you already have an Eventhouse and KQL Database.
    This script reads the KQL setup files and executes them.
.PARAMETER ClusterUri
    Your Kusto cluster URI (e.g., https://myeventhouse.kusto.fabric.microsoft.com)
.PARAMETER DatabaseName
    Your KQL database name
.EXAMPLE
    .\Setup-KqlSchema.ps1 -ClusterUri "https://myeh.kusto.fabric.microsoft.com" -DatabaseName "SecurityLogs"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ClusterUri,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName
)

$ErrorActionPreference = "Stop"

Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           PostgreSQL Anomaly Detection - KQL Setup              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get token
Write-Host "📋 Authenticating..." -ForegroundColor Yellow
try {
    $token = az account get-access-token --resource "https://kusto.kusto.windows.net" --query accessToken -o tsv
} catch {
    $token = (Get-AzAccessToken -ResourceUrl "https://kusto.kusto.windows.net").Token
}

if (-not $token) {
    Write-Host "❌ Could not authenticate. Run 'az login' first." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Authenticated" -ForegroundColor Green

# Function to run KQL
function Run-Kql {
    param([string]$Command, [string]$Description)
    
    Write-Host "  → $Description" -ForegroundColor Gray
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        db = $DatabaseName
        csl = $Command
    } | ConvertTo-Json
    
    try {
        $null = Invoke-RestMethod -Method POST -Uri "$ClusterUri/v1/rest/mgmt" `
            -Headers $headers -Body $body
        return $true
    } catch {
        Write-Host "    ⚠️ $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# ============================================================================
# Create Main Logs Table (if not using Event Stream)
# ============================================================================

Write-Host ""
Write-Host "📦 Creating bronze_pssql_alllogs_nometrics table..." -ForegroundColor Cyan

$createLogsTable = @"
.create table bronze_pssql_alllogs_nometrics (
    EventProcessedUtcTime: datetime,
    TimeGenerated: datetime,
    LogicalServerName: string,
    category: string,
    message: string,
    errorLevel: string,
    sqlerrcode: string,
    processId: long,
    backend_type: string,
    OperationName: string,
    SourceSystem: string,
    TenantId: string,
    Type: string
)
"@

Run-Kql -Command $createLogsTable -Description "Creating logs table"

# ============================================================================
# Create Metrics Table (Enhanced v3)
# ============================================================================

Write-Host ""
Write-Host "📊 Creating postgres_activity_metrics table (v3)..." -ForegroundColor Cyan

$createMetricsTable = @"
.create table postgres_activity_metrics (
    Timestamp: datetime,
    ServerName: string,
    HourOfDay: int,
    DayOfWeek: int,
    ActivityCount: long,
    AuditLogs: long,
    Errors: long,
    Connections: long,
    UniqueUsers: long,
    SelectOps: long,
    WriteOps: long,
    DDLOps: long,
    PrivilegeOps: long
)
"@

Run-Kql -Command $createMetricsTable -Description "Creating metrics table"

# ============================================================================
# Create Transform Function
# ============================================================================

Write-Host ""
Write-Host "⚙️ Creating transform function..." -ForegroundColor Cyan

$createFunction = @"
.create-or-alter function postgres_activity_metrics_transform() {
    bronze_pssql_alllogs_nometrics
    | where category == "PostgreSQLLogs"
    | extend 
        HourOfDay = hourofday(EventProcessedUtcTime),
        DayOfWeek = toint(dayofweek(EventProcessedUtcTime) / 1d),
        UserName = extract(@"user=([^\s,]+)", 1, message)
    | summarize 
        ActivityCount = count(),
        AuditLogs = countif(message contains "AUDIT:"),
        Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
        Connections = countif(message contains "connection authorized"),
        UniqueUsers = dcount(UserName),
        SelectOps = countif(message has_any ("SELECT", "COPY", ",READ,")),
        WriteOps = countif(message has_any ("INSERT", "UPDATE", "DELETE", ",WRITE,")),
        DDLOps = countif(message has_any ("CREATE", "DROP", "ALTER TABLE")),
        PrivilegeOps = countif(message has_any ("GRANT", "REVOKE", "ALTER ROLE"))
        by ServerName = LogicalServerName, 
           Timestamp = bin(EventProcessedUtcTime, 5m),
           HourOfDay = hourofday(EventProcessedUtcTime),
           DayOfWeek = toint(dayofweek(EventProcessedUtcTime) / 1d)
    | project Timestamp, ServerName, HourOfDay, DayOfWeek,
              ActivityCount, AuditLogs, Errors, Connections,
              UniqueUsers, SelectOps, WriteOps, DDLOps, PrivilegeOps
}
"@

Run-Kql -Command $createFunction -Description "Creating aggregation function"

# ============================================================================
# Create Update Policy
# ============================================================================

Write-Host ""
Write-Host "🔄 Creating update policy..." -ForegroundColor Cyan

$createPolicy = @"
.alter table postgres_activity_metrics policy update 
@'[{"IsEnabled": true, "Source": "bronze_pssql_alllogs_nometrics", "Query": "postgres_activity_metrics_transform()", "IsTransactional": false, "PropagateIngestionProperties": false}]'
"@

Run-Kql -Command $createPolicy -Description "Creating update policy"

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                      SETUP COMPLETE                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Created:" -ForegroundColor White
Write-Host "   • bronze_pssql_alllogs_nometrics (main logs table)"
Write-Host "   • postgres_activity_metrics (ML metrics table)"
Write-Host "   • postgres_activity_metrics_transform() function"
Write-Host "   • Update policy for automatic aggregation"
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Create Event Stream: Event Hub → bronze_pssql_alllogs_nometrics"
Write-Host "   2. Create Real-Time Dashboard with queries from kql-queries-PRODUCTION.kql"
Write-Host "   3. Test with TEST-ANOMALY-TRIGGERS.sql"
Write-Host ""
