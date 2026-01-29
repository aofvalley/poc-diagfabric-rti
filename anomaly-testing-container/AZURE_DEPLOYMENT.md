# Azure Container Apps Deployment Guide

This guide provides step-by-step instructions for deploying the anomaly testing solution to Azure Container Apps.

## 🎯 Deployment Architecture

```
Azure Container Registry (ACR)
     ↓
Container Apps Environment
     ↓
Container App Job (Manual Trigger)
     ↓
PostgreSQL Flexible Server(s)
     ↓
Event Hub → Fabric Event Stream → KQL Database
```

## 📋 Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Docker installed locally
- Contributor permissions in Azure subscription
- PostgreSQL Flexible Server(s) already configured with pgaudit

## 🚀 Step 1: Create Base Resources

### 1.1 Create Resource Group

```bash
RESOURCE_GROUP="rg-fabric-anomaly-testing"
LOCATION="westeurope"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 1.2 Create Azure Container Registry

```bash
ACR_NAME="acrfabricanomalies"  # Must be globally unique

# Create ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

# Get credentials
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

## 🐳 Step 2: Build and Push Image

### 2.1 Login to ACR

```bash
az acr login --name $ACR_NAME
```

### 2.2 Build Image

```bash
# From the anomaly-testing-container/ directory
docker build -t ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.0 .
```

### 2.3 Push Image

```bash
docker push ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.0
```

### 2.4 Verify Image

```bash
az acr repository show \
  --name $ACR_NAME \
  --repository postgres-anomaly-tester
```

## ☁️ Step 3: Create Container Apps Environment

```bash
ENVIRONMENT_NAME="env-fabric-anomaly-testing"

# Create environment
az containerapp env create \
  --name $ENVIRONMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

## 🎯 Step 4: Create Container App Job

### 4.1 Configure Variables

```bash
# PostgreSQL Configuration
POSTGRES_SERVERS="server1.postgres.database.azure.com,server2.postgres.database.azure.com"
POSTGRES_USER="postgres_admin"
POSTGRES_PASSWORD="YourSecurePassword123!"  # Replace with your actual password
POSTGRES_DATABASE="adventureworks"

# Test Configuration
DELAY_BETWEEN_TESTS=120
ENABLE_BRUTE_FORCE=false
```

### 4.2 Create Job with Manual Trigger

```bash
JOB_NAME="job-anomaly-demo"

az containerapp job create \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT_NAME \
  --trigger-type Manual \
  --replica-timeout 2700 \
  --replica-retry-limit 0 \
  --parallelism 1 \
  --replica-completion-count 1 \
  --image ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.0 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --secrets \
    postgres-password="$POSTGRES_PASSWORD" \
  --env-vars \
    POSTGRES_SERVERS="$POSTGRES_SERVERS" \
    POSTGRES_USER="$POSTGRES_USER" \
    POSTGRES_PASSWORD=secretref:postgres-password \
    POSTGRES_DATABASE="$POSTGRES_DATABASE" \
    DELAY_BETWEEN_TESTS="$DELAY_BETWEEN_TESTS" \
    ENABLE_BRUTE_FORCE="$ENABLE_BRUTE_FORCE"
```

## 🎬 Step 5: Run During Demo

### 5.1 Start Job Manually

```bash
# Start job
az containerapp job start \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP
```

### 5.2 Monitor Execution

```bash
# View execution history
az containerapp job execution list \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --output table

# Get logs from last execution
EXECUTION_NAME=$(az containerapp job execution list \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --query [0].name -o tsv)

az containerapp job logs show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --execution $EXECUTION_NAME
```

## 🔧 Advanced Configuration

### Update Environment Variables

```bash
# Update job configuration
az containerapp job update \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars \
    DELAY_BETWEEN_TESTS="60" \
    ENABLE_BRUTE_FORCE="true"
```

### Update Image

```bash
# 1. Build new version
docker build -t ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.1 .
docker push ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.1

# 2. Update job
az containerapp job update \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --image ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.1
```

## 🔐 PostgreSQL Firewall Configuration

To allow Container App to connect to PostgreSQL, add the outbound IP:

```bash
# Get outbound IP from Container Apps Environment
OUTBOUND_IP=$(az containerapp env show \
  --name $ENVIRONMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.staticIp -o tsv)

echo "Outbound IP: $OUTBOUND_IP"

# Add firewall rule in PostgreSQL
POSTGRES_SERVER_NAME="your-postgres-server"

az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME \
  --rule-name "allow-container-apps" \
  --start-ip-address $OUTBOUND_IP \
  --end-ip-address $OUTBOUND_IP
```

## 📊 Monitoring and Logs

### View Real-Time Logs (during execution)

```bash
# Streaming logs
az containerapp job logs show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --follow
```

### View Metrics

```bash
# Execution history
az containerapp job execution list \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --output table
```

## 🧹 Clean Up Resources

### Delete Only the Job

```bash
az containerapp job delete \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --yes
```

### Delete Entire Resource Group

```bash
az group delete \
  --name $RESOURCE_GROUP \
  --yes \
  --no-wait
```

## 🎯 Complete Demo Flow

### Preparation (1 time)

```bash
# 1. Create resources (steps 1-4)
# 2. Verify PostgreSQL connectivity
# 3. Validate Fabric is receiving logs
```

### During the Demo

```bash
# 1. Start job
az containerapp job start \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP

# 2. Open Fabric dashboard on second screen

# 3. While running (~20 minutes with 120s delays):
#    - Explain each test
#    - Show real-time logs
#    - Show anomalies appearing in Fabric

# 4. When finished, show summary of detected anomalies
```

### Post-Demo Verification

```bash
# View complete logs
EXECUTION_NAME=$(az containerapp job execution list \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --query [0].name -o tsv)

az containerapp job logs show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --execution $EXECUTION_NAME
```

## 🚨 Troubleshooting

### Error: "Cannot connect to PostgreSQL"

```bash
# Verify firewall
az postgres flexible-server firewall-rule list \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME

# Verify Container Apps IP is allowed
```

### Error: "Image pull failed"

```bash
# Verify ACR credentials
az containerapp job show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.registries

# Recreate with updated credentials if necessary
```

### Job Stuck in "Running" State

```bash
# Check logs to see where it's stuck
az containerapp job logs show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --execution $EXECUTION_NAME

# Cancel execution if necessary
az containerapp job stop \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --execution-name $EXECUTION_NAME
```

## 💡 Tips for Successful Demos

1. **Do a dry-run** before the client demo
2. **Have Fabric dashboard open** on a second screen
3. **Prepare explanations** for each anomaly while it runs
4. **120s delay** is optimal for demos (allows explanation while waiting for ingestion)
5. **Enable brute force only if you'll show it** (adds ~1 minute extra)
6. **Keep job logs visible** for transparency with clients

---

**Having issues?** Check the Troubleshooting section or review the complete logs.
