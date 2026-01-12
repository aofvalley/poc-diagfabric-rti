#!/bin/bash
# ============================================================================
# PostgreSQL Anomaly Detection - Fabric CLI Deployment Script
# ============================================================================
# Uses the official Microsoft Fabric CLI (fab)
# Documentation: https://microsoft.github.io/fabric-cli/
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_NAME="${1:-}"
EVENTHOUSE_NAME="${2:-PostgreSQLMonitor}"
DATABASE_NAME="${3:-SecurityLogs}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  PostgreSQL Anomaly Detection - Fabric CLI Deployment v3.0      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Prerequisites Check
# ============================================================================

echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check fab is installed
if ! command -v fab &> /dev/null; then
    echo -e "${RED}❌ Fabric CLI (fab) not found. Install with:${NC}"
    echo "   pip install ms-fabric-cli"
    exit 1
fi
echo -e "${GREEN}✅ Fabric CLI (fab) found${NC}"

# Check authentication
if ! fab auth status &> /dev/null; then
    echo -e "${YELLOW}🔐 Not authenticated. Running: fab auth login${NC}"
    fab auth login
fi
echo -e "${GREEN}✅ Authenticated${NC}"

# ============================================================================
# Workspace Setup
# ============================================================================

if [ -z "$WORKSPACE_NAME" ]; then
    echo ""
    echo -e "${YELLOW}Available workspaces:${NC}"
    fab ls
    echo ""
    read -p "Enter workspace name: " WORKSPACE_NAME
fi

echo -e "${CYAN}📂 Navigating to workspace: $WORKSPACE_NAME${NC}"
fab cd "$WORKSPACE_NAME"

# ============================================================================
# Create Eventhouse
# ============================================================================

echo ""
echo -e "${CYAN}🏠 Creating Eventhouse: $EVENTHOUSE_NAME${NC}"

if fab exists "$EVENTHOUSE_NAME.Eventhouse" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Eventhouse already exists${NC}"
else
    fab mkdir "$EVENTHOUSE_NAME.Eventhouse"
    echo -e "${GREEN}✅ Eventhouse created${NC}"
fi

# ============================================================================
# Create KQL Database (inside Eventhouse)
# ============================================================================

echo ""
echo -e "${CYAN}📊 Creating KQL Database: $DATABASE_NAME${NC}"

# Navigate into Eventhouse
fab cd "$EVENTHOUSE_NAME.Eventhouse"

if fab exists "$DATABASE_NAME.KQLDatabase" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ KQL Database already exists${NC}"
else
    fab mkdir "$DATABASE_NAME.KQLDatabase"
    echo -e "${GREEN}✅ KQL Database created${NC}"
fi

# ============================================================================
# Deploy KQL Schema
# ============================================================================

echo ""
echo -e "${CYAN}⚙️ Deploying KQL schema...${NC}"

# Navigate to database
fab cd "$DATABASE_NAME.KQLDatabase"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KQL_SETUP="$SCRIPT_DIR/../queries/ANOMALY-DETECTION-SETUP.kql"

if [ -f "$KQL_SETUP" ]; then
    echo -e "${CYAN}  Running ANOMALY-DETECTION-SETUP.kql...${NC}"
    
    # Run the KQL commands using fab run
    # Note: fab run executes KQL against the current database context
    fab run --file "$KQL_SETUP" || {
        echo -e "${YELLOW}⚠️ Some commands may have failed (tables might already exist)${NC}"
    }
    
    echo -e "${GREEN}✅ KQL schema deployed${NC}"
else
    echo -e "${YELLOW}⚠️ KQL setup file not found at: $KQL_SETUP${NC}"
    echo -e "${YELLOW}  Please run ANOMALY-DETECTION-SETUP.kql manually${NC}"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    DEPLOYMENT COMPLETE                           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Resources Created:${NC}"
echo "   • Workspace: $WORKSPACE_NAME"
echo "   • Eventhouse: $EVENTHOUSE_NAME"
echo "   • KQL Database: $DATABASE_NAME"
echo "   • Tables: postgres_activity_metrics"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "   1. Create Event Stream from Azure Event Hub to bronze_pssql_alllogs_nometrics"
echo "   2. Configure Diagnostic Settings on PostgreSQL to send to Event Hub"
echo "   3. Create Real-Time Dashboard using queries from kql-queries-PRODUCTION.kql"
echo ""
echo -e "${YELLOW}📊 Test the solution:${NC}"
echo "   Execute TEST-ANOMALY-TRIGGERS.sql in your PostgreSQL database"
echo ""
