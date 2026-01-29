# PostgreSQL Anomaly Testing Container

> **Herramienta automatizada para ejecutar tests de anomalías en PostgreSQL Flexible Servers y demostrar capacidades de detección con Microsoft Fabric**

## 🆕 Novedades v2.0 - Simulación de Tráfico Realista

**La demo ahora es mucho más realista y efectiva:**

- 🎭 **Tráfico de fondo normal** - Simula actividad típica de aplicación (SELECTs, UPDATEs, errores ocasionales)
- ⏱️ **Baseline establecido** - 3 min de actividad normal antes de introducir anomalías
- 🎯 **Anomalías graduales** - Introducidas una a la vez, intercaladas con períodos normales
- 📊 **3 niveles de intensidad** - low/medium/high según el escenario de demo
- 🔄 **Contraste visible** - Cliente ve claramente el baseline normal vs los picos anómalos
- ✨ **Threading concurrente** - Tráfico de fondo continúa mientras se ejecutan anomalías

**Resultado**: Demo más convincente que demuestra que Fabric NO genera falsos positivos con actividad normal.

## 📋 Descripción

1. **Data Exfiltration** - Extracción masiva de datos (>15 SELECTs en 5 min)
2. **Mass Destructive Operations** - Operaciones destructivas masivas (>5 UPDATEs/DELETEs en 2 min)
3. **Critical Error Spike** - Escalada de errores críticos (>15 errores en 1 min)
4. **Privilege Escalation** - Escalada de privilegios (>3 GRANTs/REVOKEs en 5 min)
5. **Cross-Schema Reconnaissance** - Reconocimiento cross-schema (>4 schemas en 10 min)
6. **Deep Schema Enumeration** - Enumeración profunda de schema (>10 queries a tablas de sistema)
7. **ML Baseline Deviation** - Desviación de baseline ML (50+ queries en ráfaga)

## ✨ Características

- ✅ **Ejecución automatizada** de todos los tests en secuencia
- ✅ **Soporte multi-servidor** - Ejecuta en uno o varios PostgreSQL simultáneamente
- ✅ **Tests modulares** - Cada anomalía en su propio archivo SQL (fácil de modificar)
- ✅ **Containerizado** - Listo para desplegar en Azure Container Apps
- ✅ **Delays configurables** - Tiempo entre tests para permitir ingesta en Fabric
- ✅ **Brute force opcional** - Simula ataques de autenticación
- ✅ **Output colorizado** - Progreso visual durante la demo
- ✅ **Limpieza automática** - Elimina tablas temporales al finalizar

## 🚀 Inicio Rápido

### Opción 1: Ejecución Local con Python

```bash
# 1. Clonar o navegar al directorio
cd anomaly-testing-container

# 2. Instalar dependencias
pip install -r requirements.txt

# 3. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales

# 4. Ejecutar
python anomaly_runner.py
```

### Opción 2: Ejecución con Docker

```bash
# 1. Construir imagen
docker build -t postgres-anomaly-tester .

# 2. Ejecutar (pasando variables de entorno)
docker run \
  -e POSTGRES_SERVERS="server1.postgres.database.azure.com" \
  -e POSTGRES_USER="tu_usuario" \
  -e POSTGRES_PASSWORD="tu_password" \
  -e POSTGRES_DATABASE="adventureworks" \
  -e DELAY_BETWEEN_TESTS=120 \
  postgres-anomaly-tester
```

### Opción 3: Ejecución con Docker Compose

```bash
# 1. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales

# 2. Ejecutar
docker-compose up
```

## 🔧 Configuración

### Variables de Entorno

| Variable | Descripción | Requerido | Default |
|----------|-------------|-----------|---------|
| `POSTGRES_SERVERS` | Servidores PostgreSQL (separados por coma) | ✅ | - |
| `POSTGRES_USER` | Usuario de PostgreSQL | ✅ | - |
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL | ✅ | - |
| `POSTGRES_DATABASE` | Base de datos | ❌ | `adventureworks` |
| `POSTGRES_PORT` | Puerto | ❌ | `5432` |
| `DELAY_BETWEEN_TESTS` | Segundos entre tests (para ingesta Fabric) | ❌ | `120` |
| `ENABLE_BRUTE_FORCE` | Habilitar test de brute force | ❌ | `false` |
| `BRUTE_FORCE_ATTEMPTS` | Intentos de brute force | ❌ | `20` |
| **`ENABLE_BACKGROUND_TRAFFIC`** | **🆕 Habilitar tráfico de fondo normal** | ❌ | `true` |
| **`BACKGROUND_TRAFFIC_INTENSITY`** | **🆕 Intensidad (low/medium/high)** | ❌ | `medium` |
| **`BASELINE_DURATION`** | **🆕 Segundos de baseline antes de anomalías** | ❌ | `180` |
| **`ANOMALY_SPACING`** | **🆕 Segundos entre anomalías** | ❌ | `300` |

### Ejemplo de .env

```bash
POSTGRES_SERVERS=server1.postgres.database.azure.com,server2.postgres.database.azure.com
POSTGRES_USER=postgres_admin
POSTGRES_PASSWORD=YourSecurePassword123!
POSTGRES_DATABASE=adventureworks
DELAY_BETWEEN_TESTS=120
ENABLE_BRUTE_FORCE=false

# >>> v2.0: Background Traffic Simulation
ENABLE_BACKGROUND_TRAFFIC=true
BACKGROUND_TRAFFIC_INTENSITY=medium
BASELINE_DURATION=180
ANOMALY_SPACING=300
```

## 🎯 Añadir o Modificar Tests

La arquitectura modular permite fácil personalización:

```
sql_tests/
├── test_01_data_exfiltration.sql       ← Modifica queries existentes
├── test_02_destructive_operations.sql
├── test_03_error_spike.sql
├── test_04_privilege_escalation.sql
├── test_05_cross_schema_recon.sql
├── test_06_deep_enumeration.sql
├── test_07_ml_baseline.sql
├── test_08_tu_nuevo_test.sql           ← Añade nuevos tests
└── test_cleanup.sql
```

**Para añadir un nuevo test:**

1. Crea archivo `test_08_nombre_descriptivo.sql`
2. Escribe tus queries SQL
3. El orquestador lo detectará automáticamente (archivos con patrón `test_[0-9]*.sql`)

## ☁️ Desplegar en Azure Container Apps

### 1. Crear Azure Container Registry (ACR)

```bash
# Crear resource group
az group create --name rg-anomaly-tester --location westeurope

# Crear ACR
az acr create \
  --resource-group rg-anomaly-tester \
  --name acranomalytester \
  --sku Basic

# Login en ACR
az acr login --name acranomalytester
```

### 2. Construir y Publicar Imagen

```bash
# Build y push
docker build -t acranomalytester.azurecr.io/postgres-anomaly-tester:v1.0 .
docker push acranomalytester.azurecr.io/postgres-anomaly-tester:v1.0
```

### 3. Crear Container Apps Environment

```bash
# Crear environment
az containerapp env create \
  --name env-anomaly-tester \
  --resource-group rg-anomaly-tester \
  --location westeurope
```

### 4. Crear Container App

```bash
# Crear container app
az containerapp create \
  --name app-postgres-anomaly-tester \
  --resource-group rg-anomaly-tester \
  --environment env-anomaly-tester \
  --image acranomalytester.azurecr.io/postgres-anomaly-tester:v1.0 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 0 \
  --max-replicas 1 \
  --registry-server acranomalytester.azurecr.io \
  --secrets \
    postgres-password="YourSecurePassword123!" \
  --env-vars \
    POSTGRES_SERVERS="server1.postgres.database.azure.com" \
    POSTGRES_USER="postgres_admin" \
    POSTGRES_PASSWORD=secretref:postgres-password \
    POSTGRES_DATABASE="adventureworks" \
    DELAY_BETWEEN_TESTS="120"
```

### 5. Ejecutar Manualmente para Demos

```bash
# Ejecutar una instancia manual
az containerapp job create \
  --name job-anomaly-demo \
  --resource-group rg-anomaly-tester \
  --environment env-anomaly-tester \
  --image acranomalytester.azurecr.io/postgres-anomaly-tester:v1.0 \
  --trigger-type Manual \
  --replica-timeout 1800 \
  --secrets \
    postgres-password="YourSecurePassword123!" \
  --env-vars \
    POSTGRES_SERVERS="server1.postgres.database.azure.com" \
    POSTGRES_USER="postgres_admin" \
    POSTGRES_PASSWORD=secretref:postgres-password \
    POSTGRES_DATABASE="adventureworks" \
    DELAY_BETWEEN_TESTS="120"

# Ejecutar el job durante la demo
az containerapp job start \
  --name job-anomaly-demo \
  --resource-group rg-anomaly-tester
```

## � Setup de pgAudit (IMPORTANTE)

**⚠️ REQUISITO CRÍTICO**: Para que las anomalías se detecten correctamente, pgaudit DEBE estar habilitado y configurado correctamente.

### Opción A: Setup Automático (Recomendado)

```bash
# Ejecutar el script de setup automático
python setup_pgaudit.py
```

Este script:
- ✅ Verifica que pgaudit está instalado
- ✅ Configura pgaudit a nivel de base de datos
- ✅ Habilita logging de catálogos de sistema (necesario para anomalía #6)
- ✅ Verifica la configuración aplicada

### Opción B: Setup Manual (SQL)

```bash
# Ejecutar el script SQL manualmente
psql -h server.postgres.database.azure.com -U adminuser -d adventureworks -f sql_tests/setup_pgaudit.sql
```

O conectarte a PostgreSQL y ejecutar:

```sql
-- Configurar pgaudit a nivel de base de datos
ALTER DATABASE adventureworks SET pgaudit.log = 'READ, WRITE, DDL, MISC';
ALTER DATABASE adventureworks SET pgaudit.log_catalog = 'on';
ALTER DATABASE adventureworks SET pgaudit.log_parameter = 'on';

-- Reconectar para aplicar cambios
```

### Verificar que pgaudit está funcionando

```sql
-- Debe mostrar las configuraciones correctas
SELECT name, setting, source
FROM pg_settings
WHERE name LIKE 'pgaudit%';
```

**Configuración esperada:**
- `pgaudit.log` = `'READ, WRITE, DDL, MISC'` o `'ALL'`
- `pgaudit.log_catalog` = `'on'`
- `pgaudit.log_parameter` = `'on'`

### Configuración en Azure Portal (si pgaudit no está instalado)

Si pgaudit no está instalado en tu servidor:

1. Ve a tu PostgreSQL Flexible Server en Azure Portal
2. Settings → **Server parameters**
3. Busca `shared_preload_libraries` y añade `pgaudit`
4. Busca `pgaudit.log` y configúralo a `ALL`
5. Busca `pgaudit.log_catalog` y ponlo en `ON`
6. **Reinicia el servidor** para aplicar cambios

## 📊 Flujo de Demo Recomendado

1. **Preparación** (antes del cliente):
   - ✅ **Ejecutar `python setup_pgaudit.py`** (CRÍTICO)
   - ✅ Validar que pgaudit está configurado correctamente
   - ✅ Validar que Fabric Event Stream está ingiriendo logs
   - ✅ Validar que dashboard de Fabric está funcionando

2. **Durante la demo**:
   ```bash
   # Iniciar container (Azure o local)
   az containerapp job start --name job-anomaly-demo --resource-group rg-anomaly-tester
   
   # Mientras ejecuta (toma ~20 minutos con delays de 120s):
   # - Explicar cada anomalía mientras se ejecuta
   # - Mostrar dashboard de Fabric en tiempo real
   # - Explicar que los logs tardan 1-2 min en aparecer
   ```

3. **Mostrar resultados en Fabric**:
   - Anomalía 1: Data Exfiltration (~20 SELECTs)
   - Anomalía 2: Mass Destructive Ops (6 UPDATEs/DELETEs)
   - Anomalía 3: Error Spike (~23 errores)
   - Anomalía 4: Privilege Escalation (6 GRANTs)
   - Anomalía 5: Cross-Schema Recon (5+ schemas)
   - Anomalía 6: Deep Enumeration (15+ system queries)
   - Anomalía 7: ML Baseline Deviation (52 queries)

## 🔍 Troubleshooting

### Problema: "No se pudo conectar al servidor"

**Solución**: Verificar:
- Firewall de Azure PostgreSQL permite la IP del container
- Variables de entorno correctas (`POSTGRES_SERVERS`, `POSTGRES_USER`, `POSTGRES_PASSWORD`)
- Server name es el FQDN completo (ej: `server.postgres.database.azure.com`)

### Problema: "Las anomalías no aparecen en Fabric"

**Solución**: Verificar:
1. **pgaudit está habilitado y configurado** - Ejecutar `python setup_pgaudit.py`
2. Diagnostic Settings habilitado en PostgreSQL → Event Hub
3. Event Stream en Fabric recibiendo datos
4. Dashboard refresh automático habilitado

### Problema: "Anomalía #6 (Deep Enumeration) no se detecta"

**Diagnóstico**: Esta anomalía requiere `pgaudit.log_catalog = 'on'`

**Solución**:
```bash
# Ejecutar setup automático
python setup_pgaudit.py

# O manualmente:
ALTER DATABASE adventureworks SET pgaudit.log_catalog = 'on';
-- Reconectar para aplicar
```

**Verificar en Fabric**: La query KQL debe mostrar mensajes con `AUDIT:` o consultas a tablas `pg_*` y `information_schema.*`

### Problema: "Los logs no contienen 'AUDIT:' en el mensaje"

**Causa**: pgaudit no está habilitado a nivel de servidor o base de datos

**Solución**:
1. Azure Portal → PostgreSQL Server → Server Parameters
2. Verificar: `shared_preload_libraries` incluye `pgaudit`
3. Verificar: `pgaudit.log` = `ALL` o contiene `READ`
4. Ejecutar: `python setup_pgaudit.py` para configuración a nivel de BD
5. Reiniciar servidor si es necesario
3. Esperar 2-3 minutos para ingesta
4. Queries KQL en dashboard tienen thresholds correctos

### Problema: "User/Database/Host = UNKNOWN en dashboard"

**Solución**: Verificar:
- pgaudit instalado: `SELECT * FROM pg_extension WHERE extname = 'pgaudit';`
- pgaudit configurado: `SHOW pgaudit.log;` debe ser `'ALL'`
- Correlación con CONNECTION logs funcionando

## 📁 Estructura del Proyecto

```
anomaly-testing-container/
├── sql_tests/                          # Tests SQL modulares
│   ├── test_01_data_exfiltration.sql
│   ├── test_02_destructive_operations.sql
│   ├── test_03_error_spike.sql
│   ├── test_04_privilege_escalation.sql
│   ├── test_05_cross_schema_recon.sql
│   ├── test_06_deep_enumeration.sql
│   ├── test_07_ml_baseline.sql
│   └── test_cleanup.sql
├── anomaly_runner.py                   # Orquestador principal
├── requirements.txt                    # Dependencias Python
├── Dockerfile                          # Containerización
├── docker-compose.yml                  # Testing local
├── .env.example                        # Template de configuración
├── .gitignore                          # Git ignore
└── README.md                           # Esta documentación
```

## 🛠️ Tecnologías Utilizadas

- **Python 3.11** - Orquestación y ejecución
- **psycopg2** - Driver PostgreSQL
- **colorama** - Output colorizado en consola
- **Docker** - Containerización
- **Azure Container Apps** - Deployment en la nube

## 📝 Notas Importantes

- ⚠️ **TEST 3** genera errores intencionalmente - Esto es esperado
- ⏱️ **Delays entre tests** permiten ingesta en Fabric (recomendado: 120s)
- 🧹 **Limpieza automática** elimina tabla `temp_test_anomaly` al finalizar
- 🔒 **Brute force** deshabilitado por defecto (habilitar solo en demos controladas)

## 🤝 Contribuir

Para añadir nuevos tests o mejorar existentes:

1. Editar archivos en `sql_tests/`
2. Re-construir imagen Docker
3. Probar localmente antes de desplegar

## 📄 Licencia

Este proyecto es parte de la POC Fabric-RTI y está diseñado para uso interno en demos.

---

**¿Preguntas?** Contacta al equipo de desarrollo o consulta la documentación de Microsoft Fabric.
