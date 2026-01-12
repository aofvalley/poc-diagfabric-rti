<#
.SYNOPSIS
    Deploy PostgreSQL Anomaly Detection Solution to Microsoft Fabric
.DESCRIPTION
    This script creates all necessary resources in Fabric Real-Time Intelligence:
    - Eventhouse
    - KQL Database
    - Tables and functions for anomaly detection
    - Update policies for real-time processing
.PARAMETER WorkspaceId
    The Fabric Workspace ID where resources will be created
.PARAMETER EventhouseName
    Name for the Eventhouse (default: PostgreSQLMonitor)
.PARAMETER DatabaseName
    Name for the KQL Database (default: SecurityLogs)
.EXAMPLE
    .\Deploy-FabricSolution.ps1 -WorkspaceId "your-workspace-guid"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceId,
    
    [Parameter(Mandatory=$false)]
    [string]$EventhouseName = "PostgreSQLMonitor",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "SecurityLogs",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipResourceCreation,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSchemaSetup
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
$FabricApiBaseUrl = "https://api.fabric.microsoft.com/v1"
$KustoApiBaseUrl = "https://{cluster}.kusto.fabric.microsoft.com"

# Colors for output
function Write-Step { param($msg) Write-Host "📋 $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠️ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }

# ============================================================================
# Authentication
# ============================================================================

function Get-FabricAccessToken {
    Write-Step "Authenticating to Fabric..."
    
    try {
        # Try Azure CLI authentication first
        $token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv 2>$null
        if ($token) {
            Write-Success "Authenticated via Azure CLI"
            return $token
        }
    } catch {
        Write-Warning "Azure CLI not available, trying Az PowerShell module..."
    }
    
    try {
        # Try Az PowerShell module
        $token = (Get-AzAccessToken -ResourceUrl "https://api.fabric.microsoft.com").Token
        if ($token) {
            Write-Success "Authenticated via Az PowerShell"
            return $token
        }
    } catch {
        Write-Warning "Az PowerShell not available..."
    }
    
    # Interactive login fallback
    Write-Warning "Please sign in interactively..."
    Connect-AzAccount
    $token = (Get-AzAccessToken -ResourceUrl "https://api.fabric.microsoft.com").Token
    return $token
}

function Get-KustoAccessToken {
    try {
        $token = az account get-access-token --resource "https://kusto.kusto.windows.net" --query accessToken -o tsv 2>$null
        if ($token) { return $token }
    } catch {}
    
    try {
        return (Get-AzAccessToken -ResourceUrl "https://kusto.kusto.windows.net").Token
    } catch {}
    
    throw "Cannot obtain Kusto access token"
}

# ============================================================================
# Fabric API Functions
# ============================================================================

function Invoke-FabricApi {
    param(
        [string]$Method,
        [string]$Endpoint,
        [object]$Body,
        [string]$Token
    )
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    $params = @{
        Method = $Method
        Uri = "$FabricApiBaseUrl$Endpoint"
        Headers = $headers
    }
    
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    
    return Invoke-RestMethod @params
}

function New-Eventhouse {
    param([string]$Token, [string]$WorkspaceId, [string]$Name)
    
    Write-Step "Creating Eventhouse: $Name..."
    
    $body = @{
        displayName = $Name
        description = "PostgreSQL Security Monitoring - Anomaly Detection"
    }
    
    try {
        $result = Invoke-FabricApi -Method "POST" `
            -Endpoint "/workspaces/$WorkspaceId/eventhouses" `
            -Body $body -Token $Token
        
        Write-Success "Eventhouse created: $($result.id)"
        return $result
    } catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Warning "Eventhouse already exists, fetching..."
            $eventhouses = Invoke-FabricApi -Method "GET" `
                -Endpoint "/workspaces/$WorkspaceId/eventhouses" -Token $Token
            return $eventhouses.value | Where-Object { $_.displayName -eq $Name }
        }
        throw $_
    }
}

function New-KqlDatabase {
    param([string]$Token, [string]$WorkspaceId, [string]$EventhouseId, [string]$Name)
    
    Write-Step "Creating KQL Database: $Name..."
    
    $body = @{
        displayName = $Name
        description = "Security logs and anomaly detection queries"
        creationPayload = @{
            databaseType = "ReadWrite"
            parentEventhouseItemId = $EventhouseId
        }
    }
    
    try {
        $result = Invoke-FabricApi -Method "POST" `
            -Endpoint "/workspaces/$WorkspaceId/kqlDatabases" `
            -Body $body -Token $Token
        
        Write-Success "KQL Database created: $($result.id)"
        return $result
    } catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Warning "KQL Database already exists, fetching..."
            $databases = Invoke-FabricApi -Method "GET" `
                -Endpoint "/workspaces/$WorkspaceId/kqlDatabases" -Token $Token
            return $databases.value | Where-Object { $_.displayName -eq $Name }
        }
        throw $_
    }
}

# ============================================================================
# KQL Schema Setup
# ============================================================================

function Invoke-KqlCommand {
    param(
        [string]$ClusterUri,
        [string]$Database,
        [string]$Command,
        [string]$Token
    )
    
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        db = $Database
        csl = $Command
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Method POST `
            -Uri "$ClusterUri/v1/rest/mgmt" `
            -Headers $headers -Body $body
    } catch {
        Write-Warning "Command may have failed: $($_.Exception.Message)"
    }
}

function Deploy-KqlSchema {
    param([string]$ClusterUri, [string]$Database, [string]$Token)
    
    Write-Step "Deploying KQL schema and functions..."
    
    # Read KQL setup script
    $scriptPath = Join-Path $PSScriptRoot "queries\ANOMALY-DETECTION-SETUP.kql"
    if (-not (Test-Path $scriptPath)) {
        $scriptPath = ".\queries\ANOMALY-DETECTION-SETUP.kql"
    }
    
    if (Test-Path $scriptPath) {
        $kqlContent = Get-Content $scriptPath -Raw
        
        # Split into individual commands (by .command prefix)
        $commands = $kqlContent -split '(?=\n\.[a-z])' | Where-Object { $_.Trim() -match '^\.' }
        
        foreach ($cmd in $commands) {
            $cmdClean = $cmd.Trim()
            if ($cmdClean -match '^\.create|^\.alter|^\.set') {
                Write-Host "  Executing: $($cmdClean.Substring(0, [Math]::Min(60, $cmdClean.Length)))..." -ForegroundColor Gray
                Invoke-KqlCommand -ClusterUri $ClusterUri -Database $Database `
                    -Command $cmdClean -Token $Token
            }
        }
        
        Write-Success "KQL schema deployed"
    } else {
        Write-Warning "KQL setup script not found at: $scriptPath"
        Write-Warning "You'll need to run ANOMALY-DETECTION-SETUP.kql manually"
    }
}

# ============================================================================
# Main Deployment
# ============================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  PostgreSQL Anomaly Detection - Fabric Deployment Script v3.0   ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Step 1: Authentication
$fabricToken = Get-FabricAccessToken
$kustoToken = Get-KustoAccessToken

if (-not $SkipResourceCreation) {
    # Step 2: Create Eventhouse
    $eventhouse = New-Eventhouse -Token $fabricToken -WorkspaceId $WorkspaceId -Name $EventhouseName
    
    # Step 3: Create KQL Database
    $database = New-KqlDatabase -Token $fabricToken -WorkspaceId $WorkspaceId `
        -EventhouseId $eventhouse.id -Name $DatabaseName
    
    # Get cluster URI from database properties
    $clusterUri = $database.properties.queryUri
    if (-not $clusterUri) {
        # Fallback: construct from eventhouse
        Write-Warning "Could not get cluster URI from database, using default pattern"
        $clusterUri = "https://$EventhouseName.z-westeurope.kusto.fabric.microsoft.com"
    }
} else {
    Write-Warning "Skipping resource creation (--SkipResourceCreation)"
    $clusterUri = Read-Host "Enter your Kusto cluster URI (e.g., https://eventhouse.kusto.fabric.microsoft.com)"
}

if (-not $SkipSchemaSetup) {
    # Step 4: Deploy KQL Schema
    Start-Sleep -Seconds 5  # Wait for database to be ready
    Deploy-KqlSchema -ClusterUri $clusterUri -Database $DatabaseName -Token $kustoToken
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
Write-Host "   • Eventhouse: $EventhouseName"
Write-Host "   • KQL Database: $DatabaseName"
Write-Host "   • Tables: postgres_activity_metrics, postgres_error_metrics, postgres_user_metrics"
Write-Host "   • Functions: postgres_activity_metrics_transform, etc."
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Create Event Stream from Azure Event Hub to bronze_pssql_alllogs_nometrics"
Write-Host "   2. Configure Diagnostic Settings on PostgreSQL to send to Event Hub"
Write-Host "   3. Create Real-Time Dashboard using queries from kql-queries-PRODUCTION.kql"
Write-Host "   4. Set up Data Activator alerts for anomaly notifications"
Write-Host ""
Write-Host "📊 Test the solution:" -ForegroundColor Yellow
Write-Host "   Execute TEST-ANOMALY-TRIGGERS.sql in your PostgreSQL database"
Write-Host ""
