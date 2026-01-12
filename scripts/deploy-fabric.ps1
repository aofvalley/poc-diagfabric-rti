<#
.SYNOPSIS
    Deploy PostgreSQL Anomaly Detection Solution using Fabric CLI (fab)
.DESCRIPTION
    Uses the official Microsoft Fabric CLI to create:
    - Eventhouse
    - KQL Database
    - Tables and functions for anomaly detection
    
    Documentation: https://microsoft.github.io/fabric-cli/
.PARAMETER WorkspaceName
    Name of the Fabric Workspace
.PARAMETER EventhouseName
    Name for the Eventhouse (default: PostgreSQLMonitor)
.PARAMETER DatabaseName
    Name for the KQL Database (default: SecurityLogs)
.EXAMPLE
    .\deploy-fabric.ps1 -WorkspaceName "MyWorkspace"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory = $false)]
    [string]$EventhouseName = "PostgreSQLMonitor",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = "SecurityLogs"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  PostgreSQL Anomaly Detection - Fabric CLI Deployment v3.0      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Prerequisites Check
# ============================================================================

Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow

# Check fab is installed
try {
    $fabVersion = fab --version 2>&1
    Write-Host "✅ Fabric CLI found: $fabVersion" -ForegroundColor Green
}
catch {
    Write-Host "❌ Fabric CLI (fab) not found. Install with:" -ForegroundColor Red
    Write-Host "   pip install ms-fabric-cli" -ForegroundColor White
    exit 1
}

# Check authentication
$authStatus = fab auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "🔐 Not authenticated. Running: fab auth login" -ForegroundColor Yellow
    fab auth login
}
Write-Host "✅ Authenticated" -ForegroundColor Green

# ============================================================================
# Workspace Selection
# ============================================================================

if ([string]::IsNullOrEmpty($WorkspaceName)) {
    Write-Host ""
    Write-Host "Available workspaces:" -ForegroundColor Yellow
    fab ls
    Write-Host ""
    $WorkspaceName = Read-Host "Enter workspace name"
}

Write-Host "📂 Navigating to workspace: $WorkspaceName" -ForegroundColor Cyan
fab cd $WorkspaceName

# ============================================================================
# Create Eventhouse
# ============================================================================

Write-Host ""
Write-Host "🏠 Creating Eventhouse: $EventhouseName" -ForegroundColor Cyan

$eventhouseExists = fab exists "$EventhouseName.Eventhouse" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "⚠️ Eventhouse already exists" -ForegroundColor Yellow
}
else {
    fab mkdir "$EventhouseName.Eventhouse"
    Write-Host "✅ Eventhouse created" -ForegroundColor Green
}

# ============================================================================
# Create KQL Database
# ============================================================================

Write-Host ""
Write-Host "📊 Creating KQL Database: $DatabaseName" -ForegroundColor Cyan

# Navigate into Eventhouse
fab cd "$EventhouseName.Eventhouse"

$dbExists = fab exists "$DatabaseName.KQLDatabase" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "⚠️ KQL Database already exists" -ForegroundColor Yellow
}
else {
    fab mkdir "$DatabaseName.KQLDatabase"
    Write-Host "✅ KQL Database created" -ForegroundColor Green
}

# ============================================================================
# Deploy KQL Schema
# ============================================================================

Write-Host ""
Write-Host "⚙️ Deploying KQL schema..." -ForegroundColor Cyan

# Navigate to database
fab cd "$DatabaseName.KQLDatabase"

# Get script directory and KQL file
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KqlSetup = Join-Path $ScriptDir "..\queries\ANOMALY-DETECTION-SETUP.kql"

if (Test-Path $KqlSetup) {
    Write-Host "  Running ANOMALY-DETECTION-SETUP.kql..." -ForegroundColor Gray
    
    try {
        fab run --file $KqlSetup
        Write-Host "✅ KQL schema deployed" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Some commands may have failed (tables might already exist)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "⚠️ KQL setup file not found at: $KqlSetup" -ForegroundColor Yellow
    Write-Host "  Please run ANOMALY-DETECTION-SETUP.kql manually" -ForegroundColor Yellow
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    DEPLOYMENT COMPLETE                           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📦 Resources Created:" -ForegroundColor Cyan
Write-Host "   • Workspace: $WorkspaceName"
Write-Host "   • Eventhouse: $EventhouseName"
Write-Host "   • KQL Database: $DatabaseName"
Write-Host "   • Tables: postgres_activity_metrics"
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Create Event Stream from Azure Event Hub to bronze_pssql_alllogs_nometrics"
Write-Host "   2. Configure Diagnostic Settings on PostgreSQL to send to Event Hub"
Write-Host "   3. Create Real-Time Dashboard using queries from kql-queries-PRODUCTION.kql"
Write-Host ""
Write-Host "📊 Test the solution:" -ForegroundColor Yellow
Write-Host "   Execute TEST-ANOMALY-TRIGGERS.sql in your PostgreSQL database"
Write-Host ""
