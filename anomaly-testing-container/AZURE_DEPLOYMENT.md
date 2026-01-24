# Guía de Despliegue en Azure Container Apps

Esta guía proporciona instrucciones paso a paso para desplegar la solución de testing de anomalías en Azure Container Apps.

## 🎯 Arquitectura de Despliegue

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

## 📋 Prerequisitos

- Azure CLI instalado y autenticado (`az login`)
- Docker instalado localmente
- Permisos de Contributor en la suscripción Azure
- PostgreSQL Flexible Server(s) ya configurado(s) con pgaudit

## 🚀 Paso 1: Crear Recursos Base

### 1.1 Crear Resource Group

```bash
RESOURCE_GROUP="rg-fabric-anomaly-testing"
LOCATION="westeurope"

# Crear resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 1.2 Crear Azure Container Registry

```bash
ACR_NAME="acrfabricanomalies"  # Debe ser único globalmente

# Crear ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

# Obtener credenciales
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

## 🐳 Paso 2: Construir y Publicar Imagen

### 2.1 Login en ACR

```bash
az acr login --name $ACR_NAME
```

### 2.2 Construir Imagen

```bash
# Desde el directorio anomaly-testing-container/
docker build -t ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.0 .
```

### 2.3 Publicar Imagen

```bash
docker push ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.0
```

### 2.4 Verificar Imagen

```bash
az acr repository show \
  --name $ACR_NAME \
  --repository postgres-anomaly-tester
```

## ☁️ Paso 3: Crear Container Apps Environment

```bash
ENVIRONMENT_NAME="env-fabric-anomaly-testing"

# Crear environment
az containerapp env create \
  --name $ENVIRONMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

## 🎯 Paso 4: Crear Container App Job

### 4.1 Configurar Variables

```bash
# PostgreSQL Configuration
POSTGRES_SERVERS="server1.postgres.database.azure.com,server2.postgres.database.azure.com"
POSTGRES_USER="postgres_admin"
POSTGRES_PASSWORD="YourSecurePassword123!"  # Cambiar por tu password real
POSTGRES_DATABASE="adventureworks"

# Test Configuration
DELAY_BETWEEN_TESTS=120
ENABLE_BRUTE_FORCE=false
```

### 4.2 Crear Job con Trigger Manual

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

## 🎬 Paso 5: Ejecutar Durante la Demo

### 5.1 Iniciar Job Manualmente

```bash
# Start job
az containerapp job start \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP
```

### 5.2 Monitorear Ejecución

```bash
# Ver historial de ejecuciones
az containerapp job execution list \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --output table

# Obtener logs de última ejecución
EXECUTION_NAME=$(az containerapp job execution list \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --query [0].name -o tsv)

az containerapp job logs show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --execution $EXECUTION_NAME
```

## 🔧 Configuración Avanzada

### Actualizar Variables de Entorno

```bash
# Actualizar configuración del job
az containerapp job update \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars \
    DELAY_BETWEEN_TESTS="60" \
    ENABLE_BRUTE_FORCE="true"
```

### Actualizar Imagen

```bash
# 1. Construir nueva versión
docker build -t ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.1 .
docker push ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.1

# 2. Actualizar job
az containerapp job update \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --image ${ACR_LOGIN_SERVER}/postgres-anomaly-tester:v1.1
```

## 🔐 Configuración de Firewall PostgreSQL

Para que el Container App pueda conectarse a PostgreSQL, añade la IP de salida:

```bash
# Obtener IP de salida del Container Apps Environment
OUTBOUND_IP=$(az containerapp env show \
  --name $ENVIRONMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.staticIp -o tsv)

echo "IP de salida: $OUTBOUND_IP"

# Añadir regla de firewall en PostgreSQL
POSTGRES_SERVER_NAME="tu-servidor-postgres"

az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME \
  --rule-name "allow-container-apps" \
  --start-ip-address $OUTBOUND_IP \
  --end-ip-address $OUTBOUND_IP
```

## 📊 Monitoreo y Logs

### Ver Logs en Tiempo Real (durante ejecución)

```bash
# Streaming logs
az containerapp job logs show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --follow
```

### Ver Métricas

```bash
# Historial de ejecuciones
az containerapp job execution list \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --output table
```

## 🧹 Limpieza de Recursos

### Eliminar Solo el Job

```bash
az containerapp job delete \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --yes
```

### Eliminar Todo el Resource Group

```bash
az group delete \
  --name $RESOURCE_GROUP \
  --yes \
  --no-wait
```

## 🎯 Flujo Completo para Demos

### Preparación (1 vez)

```bash
# 1. Crear recursos (pasos 1-4)
# 2. Verificar conectividad a PostgreSQL
# 3. Validar que Fabric está recibiendo logs
```

### Durante la Demo

```bash
# 1. Iniciar job
az containerapp job start \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP

# 2. Abrir dashboard de Fabric en segunda pantalla

# 3. Mientras ejecuta (~20 minutos con delays de 120s):
#    - Explicar cada test
#    - Mostrar logs en tiempo real
#    - Mostrar anomalías apareciendo en Fabric

# 4. Al finalizar, mostrar resumen de anomalías detectadas
```

### Verificación Post-Demo

```bash
# Ver logs completos
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
# Verificar firewall
az postgres flexible-server firewall-rule list \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME

# Verificar que la IP del Container Apps está permitida
```

### Error: "Image pull failed"

```bash
# Verificar credenciales ACR
az containerapp job show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.registries

# Re-crear con credenciales actualizadas si es necesario
```

### Job se Queda en Estado "Running"

```bash
# Verificar logs para ver dónde está bloqueado
az containerapp job logs show \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --execution $EXECUTION_NAME

# Cancelar ejecución si es necesario
az containerapp job stop \
  --name $JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --execution-name $EXECUTION_NAME
```

## 💡 Tips para Demos Exitosas

1. **Ejecuta un dry-run** antes de la demo con el cliente
2. **Ten el dashboard de Fabric abierto** en una segunda pantalla
3. **Prepara explicaciones** de cada anomalía mientras ejecuta
4. **Delay de 120s** es óptimo para demos (permite explicar mientras espera ingesta)
5. **Habilita brute force solo si lo vas a mostrar** (añade ~1 minuto extra)
6. **Ten los logs del job visibles** para transparencia con el cliente

---

**¿Problemas?** Revisa la sección de Troubleshooting o consulta los logs completos.
