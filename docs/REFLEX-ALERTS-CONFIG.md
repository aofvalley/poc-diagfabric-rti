# ⚙️ Configuración de Alertas en Data Activator (Reflex)

**Versión**: 2.0 (Validada 20/11/2025)  
**Estado**: ✅ Queries validadas con datos reales  
**Fuente de queries**: `kql-queries-PRODUCTION.kql`

> ⚠️ **IMPORTANTE**: Las alertas ahora incluyen User/Database/Host mediante correlación.  
> Requiere extensión `pgaudit` instalada en cada base de datos: `CREATE EXTENSION pgaudit;`

## 📋 Prerequisitos
- Dashboard Real-Time creado
- Workspace con Data Activator habilitado
- Permisos de Contributor en el Workspace
- Queries validadas de `kql-queries-PRODUCTION.kql` (líneas 1-612)
- **Extensión pgaudit instalada en todas las bases de datos de usuario**
- `azure.extensions` debe incluir `PGAUDIT` en la allowlist
- `shared_preload_libraries` debe incluir `pgaudit`

---

## 🔔 CONFIGURACIÓN PASO A PASO

### Paso 1: Crear el Reflex Item

1. Abre tu **Workspace en Fabric**
2. Click en **+ New** → **Reflex** (o **Data Activator**)
3. Nombre: `PostgreSQL_Anomaly_Alerts`
4. Click **Create**

---

### Paso 2: Conectar a la Fuente de Datos

#### Opción A: Desde el Dashboard (Recomendado)

1. En el Reflex, click **Get data**
2. Selecciona **Real-Time Dashboard**
3. Elige el dashboard `PostgreSQL Security Monitoring`
4. Selecciona el tile **"Anomalías Detectadas"**
5. Click **Connect**

#### Opción B: Directamente desde KQL Database

1. En el Reflex, click **Get data**
2. Selecciona **KQL Database**
3. Elige tu database
4. Pega la query de anomalías (del archivo kql-queries-anomalies.kql)
5. Click **Next**

---

## 🚨 ALERTA 1: Extracción Masiva de Datos

### Configuración

```yaml
Name: Alert_DataExfiltration
Description: Detecta patrones de lectura masiva (SELECT, COPY, pg_dump) que sugieren exfiltración
Type: Automatic
Source Query: kql-queries-PRODUCTION.kql (líneas 12-65)
```

### Query de Detección (VALIDADA)

Ver `kql-queries-PRODUCTION.kql` líneas 1-78 para la query completa con todos los comentarios.

**Resumen de la lógica**:
- **Construye tabla `sessionInfo`** con correlación User/Database/Host desde CONNECTION logs (24h lookback)
- **FILTRO**: Solo `backend_type == "client backend"` (excluye workers internos como pg_qs_background_worker)
- Detecta > 15 SELECTs en ventana de 5 minutos por sesión (processId)
- Identifica queries COPY o pg_dump
- **Extrae TablesAccessed y SampleQueries** directamente de logs AUDIT (fallback cuando User = UNKNOWN)
- **Enriquece con User/Database/SourceHost** mediante join con sessionInfo
- Genera alerta con detalles de sesión, usuario, servidor, tablas accedidas y queries ejecutadas

### Trigger Conditions

1. **Object to monitor**: Resultado de la query de Data Exfiltration
2. **Event**: When data arrives
3. **Filter**:
   ```
   AnomalyType = "Potential Data Exfiltration"
   AND SelectCount > 15
   AND BackendType = "client backend"
   ```
4. **Optional Filters** (para reducir falsos positivos):
   ```
   // Excluir usuarios conocidos de ETL/backup
   AND User !in ("etl_service", "backup_admin", "reporting_user")
   
   // Excluir hosts conocidos de aplicaciones
   AND SourceHost !in ("10.0.1.100", "app-server-prod")
   ```

### Alert Rule

```yaml
Condition: SelectCount > 15 (en 5 minutos)
Evaluate: Every 1 minute
Suppress for: 5 minutes (evitar spam)
Severity: Critical
Note: Umbral 15 + filtro backend_type = solo usuarios reales (no workers internos)
```

### Actions

#### 📧 Acción 1: Email
```yaml
Type: Send email
To: security-team@company.com, dba-team@company.com
Subject: 🚨 ALERTA CRÍTICA - Posible Extracción de Datos en PostgreSQL
Body: |
  ANOMALÍA DETECTADA: Extracción Masiva de Datos
  
  🖥️ Servidor: {ServerName}
  👤 Usuario: {User}
  🗄️ Base de Datos: {Database}
  🌐 Host/IP Origen: {SourceHost}
  🖥️ Backend Type: {BackendType}
  📊 Número de SELECTs: {SelectCount}
  ⏰ Ventana: {TimeWindow}
  🗂️ Tablas Accedidas: {TablesAccessed}
  🔑 Process ID: {ProcessID}
  
  QUERIES EJECUTADAS (primeras 3):
  {SampleQueries}
  
  ANÁLISIS:
  - Si TablesAccessed incluye pg_catalog/information_schema → Reconocimiento de esquema
  - Si TablesAccessed incluye tablas de negocio → Posible extracción de datos
  
  ACCIÓN REQUERIDA:
  1. Verificar identidad del usuario '{User}' desde host '{SourceHost}'
  2. Validar si es operación autorizada (backup, ETL, reporting)
  3. Revisar qué datos fueron accedidos en '{Database}'
  4. Correlacionar con logs de aplicación usando ProcessID {SessionId}
  5. Si es actividad maliciosa:
     - Terminar sesión (pg_terminate_backend({SessionId}))
     - Revocar credenciales del usuario '{User}'
     - Bloquear host '{SourceHost}' en firewall/NSG
  
  Dashboard: [Link al dashboard]
  
  ⚠️ Nota: Si User/Database/SourceHost = "UNKNOWN", verificar que pgaudit esté instalado en la BD.
```

#### 💬 Acción 2: Teams
```yaml
Type: Send Teams message
Channel: #security-alerts
Message: |
  🚨 **ALERTA CRÍTICA - PostgreSQL Data Exfiltration**
  
  **Servidor**: {ServerName}
  **Usuario**: {User}
  **Base de Datos**: {Database}
  **Host/IP**: {SourceHost}
  **Backend**: {BackendType}
  **SELECTs**: {SelectCount} en 5 min
  **Tablas**: {TablesAccessed}
  **Ventana**: {TimeWindow}
  
  🔍 Usuario '{User}' desde '{SourceHost}' ejecutando queries masivos en '{Database}'
  
  **Queries**: {SampleQueries}
  
  **Acciones Rápidas**:
  - Terminar sesión: `SELECT pg_terminate_backend({ProcessID});`
  - Revocar acceso: `REVOKE ALL ON DATABASE {Database} FROM {User};`
  
  [Ver Dashboard](link)
```

#### 📋 Acción 3: Crear Ticket (Power Automate)
```yaml
Type: Power Automate Flow
Flow: Create_Security_Incident
Parameters:
  - Title: "PostgreSQL Data Exfiltration - {User}@{Database} from {SourceHost}"
  - Priority: High
  - AssignTo: Security Team
  - Description: "Detected {SelectCount} SELECTs by user '{User}' from host '{SourceHost}' on database '{Database}'"
  - Metadata:
      Server: {ServerName}
      User: {User}
      Database: {Database}
      SourceHost: {SourceHost}
      SessionId: {SessionId}
      SelectCount: {SelectCount}
      DataVolumeBytes: {DataVolumeBytes}
      TopTables: {TopTables}
      FirstSeen: {FirstSeen}
      LastSeen: {LastSeen}
```

---

## ⚠️ ALERTA 2: Operaciones Destructivas Masivas

### Configuración

```yaml
Name: Alert_MassDestructiveOps
Description: Detecta DELETE, UPDATE, TRUNCATE, DROP masivos que puedan comprometer datos
Type: Automatic
Source Query: kql-queries-PRODUCTION.kql (líneas 71-114)
```

### Query de Detección (VALIDADA)

Ver `kql-queries-PRODUCTION.kql` líneas 80-128 para la query completa.

**Resumen de la lógica**:
- **Usa tabla `sessionInfo`** para correlación User/Database/Host (24h lookback)
- Detecta > 5 operaciones destructivas (DELETE/UPDATE/TRUNCATE/DROP) en ventanas de 2 minutos
- Agrupa por servidor, backend_type y ventana temporal `bin(EventProcessedUtcTime, 2m)`
- **Enriquece con User/Database/SourceHost** mediante join con sessionInfo
- Identifica tablas afectadas y tipos de operación
- Extrae queries ejecutadas con `take_any(QueryText, 3)`
- Genera alerta con usuario responsable y muestras de queries ejecutadas

### Trigger Conditions

```yaml
Filter: AnomalyType = "Mass Destructive Operations"
Condition: OperationCount > 5 (en ventanas de 2 minutos)

Optional Filters (reducir falsos positivos):
  # Excluir usuarios de mantenimiento conocidos
  User !in ("maintenance_admin", "etl_cleanup")
  
  # Excluir bases de datos de test/staging
  Database !in ("testdb", "staging_db")
```

### Alert Rule

```yaml
Condition: OperationCount > 5 (en ventanas de 2 minutos)
Evaluate: Every 2 minutes
Suppress for: 10 minutes
Severity: High
Note: Threshold 5 con ventana bin(2m) para detección precisa
```

### Actions

#### 📧 Email
```yaml
To: dba-team@company.com, app-owners@company.com
Subject: ⚠️ ALERTA - Operaciones Destructivas Masivas en PostgreSQL
Body: |
  OPERACIONES DESTRUCTIVAS DETECTADAS
  
  🖥️ Servidor: {ServerName}
  👤 Usuario: {User}
  🗄️ Base de Datos: {Database}
  🌐 Host/IP Origen: {SourceHost}
  📝 Operaciones: {Operations}
  📊 Cantidad: {OperationCount}
  🗃️ Tablas Afectadas: {TablesAffected}
  ⏰ Ventana de Tiempo: {TimeWindow}
  🔑 Process ID: {SessionId}
  
  OPERACIONES DETECTADAS:
  {SampleMessages}
  
  ACCIÓN REQUERIDA:
  1. Validar identidad del usuario '{User}' desde host '{SourceHost}'
  2. Verificar si son operaciones programadas/autorizadas
  3. Revisar integridad de datos en '{Database}'
  4. Validar backups recientes de tablas afectadas: {TablesAffected}
  5. Contactar al propietario de la aplicación
  6. Si es actividad no autorizada:
     - Terminar sesión inmediatamente
     - Revocar permisos del usuario '{User}'
     - Restaurar desde backup si es necesario
  
  [Ver Dashboard](link)
  
  ⚠️ Nota: Si User = "UNKNOWN", verificar instalación de pgaudit en '{Database}'.
```

#### 💬 Teams
```yaml
Channel: #database-ops
Message: |
  ⚠️ **ALERTA - Operaciones Destructivas**
  
  **Servidor**: {ServerName}
  **Usuario**: {User}
  **Base de Datos**: {Database}
  **Host/IP**: {SourceHost}
  **Ops**: {OperationCount} ({Operations})
  **Tablas**: {TablesAffected}
  
  🔍 Usuario '{User}' ejecutando operaciones destructivas desde '{SourceHost}'
  
  **Acción Rápida**: `SELECT pg_terminate_backend({SessionId});`
  
  Revisar inmediatamente
```

---

## 🔴 ALERTA 3: Escalada de Errores Críticos

### Configuración

```yaml
Name: Alert_ErrorSpike
Description: Pico de errores (autenticación, permisos, conexión) que sugiere ataque o fallo grave
Type: Automatic
Source Query: kql-queries-PRODUCTION.kql (líneas 120-137)
```

### Query de Detección (VALIDADA)

Ver `kql-queries-PRODUCTION.kql` líneas 130-180 para la query completa.

**Resumen de la lógica**:
- **Usa tabla `sessionInfo`** para correlación User/Database/Host (24h lookback)
- **Extracción dual de usuario**: DirectUser desde mensajes de error + correlación via sessionInfo (más robusto)
- **Extracción dual de database**: DirectDatabase + correlación sessionInfo
- **Extracción dual de host**: DirectHost + correlación sessionInfo
- Detecta > 15 errores (ERROR/FATAL/PANIC) por minuto por servidor (ventana `bin(1m)`)
- Categoriza errores: Authentication, Permission, Connection, Resource, Operator Intervention, Other
- Identifica códigos SQL de error más frecuentes (sqlerrcode)
- **Enriquece con FinalUser/FinalDatabase/FinalHost** (prioriza extracción directa sobre correlación)
- Genera alerta con distribución de tipos de error, usuario afectado, códigos y ejemplos

### Trigger Conditions

```yaml
Filter: AnomalyType = "Critical Error Spike"
Condition: ErrorCount > 15 (por minuto)

Optional Filters (alta prioridad):
  # Priorizar errores de autenticación (brute force)
  ErrorTypes contains "Authentication Failure" AND ErrorCount > 10
  
  # Excluir hosts conocidos con errores transitorios
  SourceHost !in ("known-flaky-app-server")
  
  # Alerta crítica si usuario específico genera muchos errores
  User != "UNKNOWN" AND ErrorCount > 10
```

### Alert Rule

```yaml
Condition: ErrorCount > 15 (por minuto)
Evaluate: Every 1 minute
Suppress for: 5 minutes
Severity: Critical
Note: Threshold 15 con ventana bin(1m) + extracción dual para máxima precisión
```

### Actions

#### 📧 Email
```yaml
To: security-team@company.com, sre-team@company.com
Subject: 🔴 CRÍTICO - Escalada de Errores en PostgreSQL
Body: |
  PICO DE ERRORES DETECTADO - POSIBLE ATAQUE O FALLO CRÍTICO
  
  🖥️ Servidor: {ServerName}
  👤 Usuario: {FinalUser}
  🗂️ Base de Datos: {FinalDatabase}
  🌐 Host/IP Origen: {FinalHost}
  🏃 Backend Type: {BackendType}
  ❌ Errores totales: {ErrorCount} (por minuto)
  🏷️ Tipos de Error: {ErrorTypes}
  🔢 Códigos SQL: {ErrorCodes}
  ⏰ Ventana: {TimeWindow}
  
  EJEMPLOS DE ERRORES:
  {SampleErrors}
  
  ANÁLISIS DE ORIGEN:
  - Usuario generando errores: {FinalUser}
  - Host/IP origen: {FinalHost}
  - Base de datos afectada: {FinalDatabase}
  - Tipo de backend: {BackendType}
  
  POSIBLES CAUSAS:
  - Ataque de fuerza bruta desde '{FinalHost}' (si son errores Authentication Failure)
  - Problema de red/conectividad desde '{FinalHost}' (Connection Errors)
  - Aplicación mal configurada con usuario '{FinalUser}' (Permission Denied)
  - Intento de escalada de privilegios por usuario '{FinalUser}'
  - Recursos insuficientes en base de datos '{FinalDatabase}' (Resource Errors)
  
  ACCIÓN INMEDIATA:
  1. Identificar actividad del usuario '{FinalUser}' desde host '{FinalHost}'
  2. Si es auth: bloquear host '{FinalHost}' temporalmente
  3. Si es conexión: verificar red, firewall, límites de conexión
  4. Si es permisos: auditar intentos de acceso no autorizado
  5. Validar que servicios críticos funcionen correctamente
  6. Si es ataque confirmado:
     - Bloquear host '{FinalHost}' en firewall/NSG
     - Revocar credenciales de usuario '{FinalUser}' si está comprometido
     - Revisar logs de acceso de '{FinalUser}' en las últimas 24h
  
  ⚠️ Nota: Si FinalUser/FinalDatabase/FinalHost = "UNKNOWN", verificar instalación de pgaudit.
  
  [Ver Dashboard](link) | [Incident Response Plan](link)
```

#### 💬 Teams
```yaml
Channel: #security-alerts
Message: |
  🔴 **CRÍTICO - Error Spike en PostgreSQL**
  
  **Servidor**: {ServerName}
  **Usuario**: {FinalUser}
  **Base de Datos**: {FinalDatabase}
  **Host/IP**: {FinalHost}
  **Backend Type**: {BackendType}
  **Errores**: {ErrorCount} por minuto
  **Tipos de Error**: {ErrorTypes}
  **Códigos SQL**: {ErrorCodes}
  **Ventana**: {TimeWindow}
  
  🔍 Posibles causas: 
  - Auth brute-force desde '{FinalHost}'
  - Connection issues con usuario '{FinalUser}'
  - Permission denied para '{FinalUser}' en '{FinalDatabase}'
  
  **Acciones Rápidas**:
  - Bloquear host: Agregar '{FinalHost}' a firewall deny list
  - Revocar usuario: `REVOKE ALL ON DATABASE {FinalDatabase} FROM {FinalUser};`
  - Terminar sesiones: `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '{FinalUser}';`
  
  @security-team @sre-team revisar URGENTE
  
  [Ver Dashboard](link)
```

#### 🤖 Acción Automática (Power Automate)
```yaml
Flow: Auto_Escalate_Critical_Errors
Condition: ErrorCount > 30 AND ErrorTypes contains "Authentication Failure"
Action: 
  1. Create P1 security incident in ServiceNow/Jira
     - Title: "PostgreSQL Brute Force Attack - User: {FinalUser}, Host: {FinalHost}"
     - Description: "{ErrorCount} authentication failures from {FinalHost} targeting user {FinalUser}"
     - AssignTo: Security Operations Center
  2. Send SMS to on-call SRE
     - Message: "CRITICAL: {ErrorCount} auth failures from {SourceHost} on {ServerName}"
  3. Trigger PagerDuty escalation
     - Severity: P1
     - Details: User={User}, Host={SourceHost}, Database={Database}
  4. Log to SIEM (Sentinel/Splunk) for correlation
     - Event: PostgreSQL_Auth_Brute_Force
     - Source_IP: {SourceHost}
     - Target_User: {User}
     - Error_Count: {ErrorCount}
  5. Auto-blocking (if SourceHost is known IP):
     - Add {SourceHost} to Azure NSG deny rule (temporary 1-hour block)
     - Send notification to network team
  
Note: Auto-blocking requires valid IP in SourceHost field. 
      If SourceHost = "UNKNOWN" or hostname, manual correlation with firewall logs needed.
```

---

## 📊 ALERTA 4 (Bonus): Desviación del Baseline

### Configuración

```yaml
Name: Alert_BaselineDeviation
Description: Actividad 3x superior al promedio (últimos 7 días)
Type: Advanced
```

### Query en Reflex

```kql
let baseline = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime between (ago(7d) .. ago(1h))
| summarize AvgEventsPerMin = count() / (7*24*60) by LogicalServerName;

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| summarize CurrentEvents = count() / 5 by LogicalServerName
| join kind=inner baseline on LogicalServerName
| extend DeviationFactor = CurrentEvents / AvgEventsPerMin
| where DeviationFactor > 3.0
| project 
    LogicalServerName, 
    CurrentEventsPerMin = CurrentEvents, 
    BaselineEventsPerMin = AvgEventsPerMin, 
    DeviationFactor = round(DeviationFactor, 2)
```

### Trigger

```yaml
Condition: DeviationFactor > 3.0
Evaluate: Every 5 minutes
Suppress: 15 minutes
```

### Actions

```yaml
Email:
  Subject: 📈 ALERTA - Actividad Inusual en PostgreSQL
  Body: |
    DESVIACIÓN DEL COMPORTAMIENTO NORMAL
    
    Servidor: {LogicalServerName}
    Actividad Actual: {CurrentEventsPerMin} eventos/min
    Promedio Normal: {BaselineEventsPerMin} eventos/min
    Factor de Desviación: {DeviationFactor}x
    
    La actividad es {DeviationFactor} veces superior al promedio de los últimos 7 días.
    
    Revisar si hay:
    - Carga de trabajo no programada
    - Migración de datos
    - Problema de aplicación (retry loops)
    - Ataque DDoS
```

---

## 🔧 Configuración Avanzada

### Enriquecer Alertas con Contexto de Usuario/Host

Las alertas ya incluyen **User/Database/SourceHost** mediante correlación automática con CONNECTION logs.

Para añadir **contexto adicional** (departamento, propietario, nivel de riesgo), crea una **lookup table**:

```kql
.create table UserContext (
    UserName: string,
    Department: string,
    Owner: string,
    RiskLevel: string,
    IsServiceAccount: bool,
    Notes: string
)

.ingest inline into table UserContext <|
etl_service,IT,ETL Team,Low,true,Automated ETL jobs
backup_admin,IT,DBA Team,Low,true,Backup operations
reporting_user,Analytics,BI Team,Low,true,Reporting queries
app_user_prod,Engineering,App Team,Medium,false,Production application
admin_user,IT,Security Team,High,false,Administrative access

.create table HostContext (
    HostAddress: string,
    Location: string,
    Owner: string,
    IsTrusted: bool,
    Notes: string
)

.ingest inline into table HostContext <|
10.0.1.100,Datacenter,App Server Prod,true,Production application server
10.0.2.50,Datacenter,ETL Server,true,ETL/batch processing
20.107.5.167,Azure Cloud,App Gateway,true,Azure Application Gateway
127.0.0.1,Localhost,Local,true,Local connections
ipv6-localhost,Localhost,Local,true,IPv6 local
```

Luego modifica las queries para incluir contexto:

```kql
// En kql-queries-PRODUCTION.kql, después de sessionInfo join
| join kind=leftouter (UserContext) on $left.User == $right.UserName
| join kind=leftouter (HostContext) on $left.SourceHost == $right.HostAddress
| extend 
    UserRisk = iff(isempty(RiskLevel), "Unknown", RiskLevel),
    HostTrust = iff(IsTrusted == true, "✅ Trusted", "⚠️ Unknown"),
    Department = iff(isempty(Department), "Unknown", Department)
| project-away UserName, HostAddress  // Evitar duplicados
```

**Beneficios**:
- Filtrar alertas: Excluir service accounts conocidos (`IsServiceAccount == false`)
- Priorizar: Alertas de usuarios `RiskLevel = "High"` son más críticas
- Enriquecer notificaciones: Incluir departamento/owner en emails

---

### Integración con SIEM

Si usas **Microsoft Sentinel** u otro SIEM:

```kql
// Query para enviar a Sentinel
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where errorLevel in ("ERROR", "FATAL", "PANIC")
| extend 
    IncidentType = "PostgreSQL Security Alert",
    Severity = case(
        message contains "authentication failed", "High",
        message contains "permission denied", "Medium",
        "Low"
    )
| project 
    TimeGenerated = EventProcessedUtcTime,
    IncidentType,
    Severity,
    ServerName = LogicalServerName,
    Message = message,
    ResourceId = resourceId
```

Configura **Logic App** o **Sentinel Connector** para ingestar estos eventos.

---

## 📱 Notificaciones Push (Mobile)

Para recibir alertas en el móvil, usa **Power Automate** con:

1. **Trigger**: Reflex alert
2. **Action**: Power Automate Mobile Notification
3. **Config**:
   ```yaml
   Title: 🚨 PostgreSQL Alert
   Message: {AnomalyType} detected on {ServerName}
   Link: [Dashboard URL]
   ```

---

## 🧪 Testing de Alertas

### Test Checklist

```bash
# Test 1: Data Exfiltration
✅ Ejecutar 10+ SELECTs en < 1 minuto desde una sesión específica
✅ Verificar alerta recibida en < 2 minutos
✅ Validar que contenga User/Database/SourceHost correctos
✅ Comando de test:
   ```sql
   -- Repetir 12 veces
   SELECT * FROM pg_tables LIMIT 10;
   ```
✅ Verificar en alerta:
   - User = tu usuario actual
   - Database = base de datos donde ejecutaste
   - SourceHost = tu IP/hostname

# Test 2: Destructive Ops
✅ Crear tabla de test y ejecutar 6+ DELETE/TRUNCATE
✅ Verificar alerta recibida
✅ Validar que muestre User/Database/SourceHost y tablas afectadas
✅ Comando de test:
   ```sql
   CREATE TABLE test_alert_destructive (id INT);
   INSERT INTO test_alert_destructive VALUES (1), (2), (3);
   DELETE FROM test_alert_destructive WHERE id = 1;
   DELETE FROM test_alert_destructive WHERE id = 2;
   TRUNCATE test_alert_destructive;
   INSERT INTO test_alert_destructive VALUES (4), (5);
   DELETE FROM test_alert_destructive;
   -- Repetir DELETE 3 veces más
   ```
✅ Verificar en alerta:
   - User = tu usuario
   - TablesAffected incluye "test_alert_destructive"
   - OperationCount >= 5

# Test 3: Error Spike
✅ Intentar 20+ conexiones con password incorrecta
✅ Verificar alerta CRÍTICA recibida
✅ Validar que muestre User (usuario que intentó autenticar) y SourceHost
✅ Comando de test (desde terminal/psql):
   ```bash
   # Repetir 25 veces con password incorrecto
   PGPASSWORD=wrong_password psql -h <server> -U <user> -d postgres
   ```
✅ Verificar en alerta:
   - User = usuario que intentó autenticar
   - ErrorCategories incluye "Auth Errors"
   - SourceHost = tu IP
   - ErrorCount >= 20

# Test 4: Baseline Deviation (sin cambios en user tracking)
✅ Generar 3x tráfico normal
✅ Verificar alerta en < 5 minutos
✅ Validar cálculo de desviación

# Test 5: Verificar sessionInfo correlation
✅ Ejecutar query de test:
   ```kql
   let sessionInfo = 
   bronze_pssql_alllogs_nometrics
   | where EventProcessedUtcTime >= ago(24h)
   | where message contains "connection authorized" or message contains "connection received"
   | extend UserName = extract(@"user=([^\s,]+)", 1, message),
            DatabaseName = extract(@"database=([^\s,]+)", 1, message),
            ClientHost = extract(@"host=([^\s]+)", 1, message)
   | where isnotempty(UserName)
   | summarize User = any(UserName), Database = any(DatabaseName), SourceHost = any(ClientHost)
       by processId, LogicalServerName;
   
   sessionInfo
   | where User == "<tu_usuario>"
   | take 10
   ```
✅ Verificar que retorna tus sesiones recientes con User/Database/SourceHost poblados
```

---

## 📊 Dashboard de Alertas (Meta-Monitoring)

Crea un dashboard para monitorizar las propias alertas:

```kql
// En Reflex, tabla interna de alertas disparadas
RefexAlertHistory
| where Timestamp >= ago(24h)
| summarize 
    TotalAlerts = count(),
    AlertsByType = dcount(AlertName)
    by bin(Timestamp, 1h)
| render timechart
```

---

## 🔒 Seguridad de las Alertas

### Principios

1. **Least Privilege**: Solo enviar alertas a quienes necesitan actuar
2. **No PII**: No incluir datos sensibles en notificaciones
3. **Encryption**: Usar canales seguros (Teams, Email corporativo)
4. **Audit**: Registrar quién recibió cada alerta

### Configuración de Destinatarios

```yaml
Critical Alerts (Error Spike):
  - Security Operations Center (SOC)
  - Database Administrators
  - On-call SRE

High Alerts (Data Exfiltration, Destructive Ops):
  - Database Administrators
  - Application Owners
  - Security Team

Medium Alerts (Baseline Deviation):
  - Database Administrators
  - Performance Team
```

---

## 📈 Métricas de Efectividad

Monitoriza la efectividad del sistema de alertas:

```kql
// KPIs de Alertas
RefexAlertHistory
| where Timestamp >= ago(7d)
| summarize 
    TotalAlerts = count(),
    AlertsByType = dcount(AlertName),
    AvgResponseTime = avg(ResponseTime),
    FalsePositiveRate = countif(WasFalsePositive) * 100.0 / count()
| extend 
    Grade = case(
        FalsePositiveRate < 5 and AvgResponseTime < 900, "A - Excellent",
        FalsePositiveRate < 10 and AvgResponseTime < 1800, "B - Good",
        FalsePositiveRate < 20, "C - Needs Improvement",
        "D - Critical Issues"
    )
```

**Objetivos**:
- False Positive Rate: < 5%
- Avg Response Time: < 15 minutos
- Alert Coverage: > 95% de incidentes reales

---

## 🛠️ Troubleshooting

### Problema: Alertas no se envían

**Solución**:
1. Verificar que Reflex esté en estado "Running"
2. Comprobar permisos de email/Teams
3. Revisar logs de Reflex:
   ```kql
   RefexOperationLog
   | where OperationType == "AlertSend"
   | where Status == "Failed"
   ```

### Problema: Demasiadas alertas (fatiga)

**Solución**:
1. Aumentar umbrales (ej: ErrorCount > 20 en vez de > 15)
2. Aumentar tiempo de supresión (de 5min a 15min)
3. Implementar alertas compuestas:
   ```
   (ErrorCount > 15 AND Duration > 5m)
   ```

### Problema: Alertas llegan tarde

**Solución**:
1. Reducir intervalo de evaluación (de 2min a 30s)
2. Verificar latencia de ingesta:
   ```kql
   bronze_pssql_alllogs_nometrics
   | extend Latency = EventProcessedUtcTime - todatetime(timestamp)
   | summarize avg(Latency), max(Latency)
   ```
3. Optimizar queries con índices/materialized views

---

## 📚 Plantillas de Respuesta a Incidentes

### Incidente: Data Exfiltration

```markdown
## Respuesta Inmediata (0-15 min)
1. [ ] Identificar usuario: {User}
2. [ ] Identificar host/IP origen: {SourceHost}
3. [ ] Verificar si usuario/host son conocidos/autorizados (consultar UserContext/HostContext)
4. [ ] Revisar base de datos afectada: {Database}
5. [ ] Si es sospechoso: Terminar sesión inmediatamente
   ```sql
   SELECT pg_terminate_backend({SessionId});
   ```
6. [ ] Si host es externo/desconocido: Bloquear IP en firewall/NSG

## Investigación (15-60 min)
7. [ ] Analizar queries ejecutadas (ver {SampleQueries})
8. [ ] Revisar datos accedidos/exportados (ver {TopTables})
9. [ ] Correlacionar con logs de aplicación usando ProcessID {SessionId}
10. [ ] Verificar histórico del usuario {User}:
    ```kql
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "{User}"
    | summarize OperationCount = count() by bin(EventProcessedUtcTime, 1h)
    ```
11. [ ] Revisar otras sesiones activas del mismo usuario/host:
    ```sql
    SELECT pid, usename, application_name, client_addr, state, query 
    FROM pg_stat_activity 
    WHERE usename = '{User}' OR client_addr::text = '{SourceHost}';
    ```

## Contención (1-4 horas)
12. [ ] Si es cuenta comprometida: Revocar credenciales
    ```sql
    REVOKE ALL ON DATABASE {Database} FROM {User};
    ALTER USER {User} WITH PASSWORD 'REVOKED';
    ```
13. [ ] Actualizar reglas de firewall/NSG (bloquear {SourceHost})
14. [ ] Auditar todos los accesos del usuario en las últimas 72h
15. [ ] Notificar a seguridad/legal si hay fuga de datos confirmada

## Post-Mortem (1-2 días)
16. [ ] Documentar incidente (usuario, host, datos accedidos, timeline)
17. [ ] Ajustar umbrales de detección si es necesario
18. [ ] Implementar controles adicionales (ej: MFA para usuario {User}, whitelist de IPs)
19. [ ] Revisar y actualizar UserContext/HostContext con nuevos patrones
```

---

### Incidente: Destructive Operations

```markdown
## Respuesta Inmediata (0-15 min)
1. [ ] Identificar usuario responsable: {User}
2. [ ] Identificar host/IP origen: {SourceHost}
3. [ ] Revisar operaciones ejecutadas: {Operations}
4. [ ] Verificar tablas afectadas: {TablesAffected}
5. [ ] Si es actividad no autorizada: Terminar sesión
   ```sql
   SELECT pg_terminate_backend({SessionId});
   ```

## Evaluación de Daños (15-60 min)
6. [ ] Verificar integridad de datos en {Database}
7. [ ] Estimar cantidad de datos afectados (rows deleted/truncated)
8. [ ] Validar backups recientes disponibles
9. [ ] Revisar si hay datos críticos en {TablesAffected}

## Recuperación (1-4 horas)
10. [ ] Si es necesario: Restaurar desde backup
11. [ ] Revocar permisos del usuario si es ataque:
    ```sql
    REVOKE DELETE, TRUNCATE, DROP ON ALL TABLES IN SCHEMA public FROM {User};
    ```
12. [ ] Auditar otros usuarios con permisos similares
13. [ ] Implementar restricciones adicionales (ej: RLS, row-level security)

## Post-Mortem
14. [ ] Documentar operaciones ejecutadas y daños
15. [ ] Revisar políticas de permisos (principio de mínimo privilegio)
16. [ ] Implementar auditoría más granular si es necesario
```

---

### Incidente: Critical Error Spike

```markdown
## Respuesta Inmediata (0-15 min)
1. [ ] Identificar origen de errores:
   - Usuario: {User}
   - Host/IP: {SourceHost}
   - Base de datos: {Database}
2. [ ] Categorizar tipo de error: {ErrorCategories}
3. [ ] Si es brute force (Auth Errors):
   - Bloquear host {SourceHost} en firewall/NSG
   - Notificar a Security Operations Center
4. [ ] Si es Connection Errors:
   - Verificar límites de conexión: `SHOW max_connections;`
   - Revisar conexiones activas: `SELECT count(*) FROM pg_stat_activity;`
5. [ ] Si es Permission Denied:
   - Revisar intentos de escalada de privilegios del usuario {User}
   - Auditar permisos actuales: `\du {User}` (psql)

## Diagnóstico (15-60 min)
6. [ ] Revisar ejemplos de errores: {SampleErrors}
7. [ ] Analizar códigos SQL: {TopErrorCodes}
8. [ ] Correlacionar con logs de aplicación (usar {SourceHost} como filtro)
9. [ ] Verificar histórico del usuario:
    ```kql
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(7d)
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where UserName == "{User}"
    | summarize ErrorCount = countif(errorLevel in ("ERROR", "FATAL", "PANIC")) by bin(EventProcessedUtcTime, 1h)
    | render timechart
    ```

## Contención (1-4 horas)
10. [ ] Si es ataque confirmado:
    - Revocar credenciales de {User}
    - Mantener bloqueo de {SourceHost}
    - Escalar a incident response team
11. [ ] Si es problema de aplicación:
    - Contactar a propietario de app en {SourceHost}
    - Revisar configuración de conexión
12. [ ] Si es problema de recursos:
    - Escalar recursos (CPU/RAM/connections)
    - Revisar queries lentas

## Post-Mortem
13. [ ] Documentar root cause (usuario/host/causa)
14. [ ] Ajustar umbrales si es necesario
15. [ ] Implementar prevención (ej: rate limiting para {User}, firewall rules)
```

---

## ✅ Checklist de Implementación

- [ ] Reflex item creado
- [ ] Conexión a KQL Database verificada
- [ ] **Extensión pgaudit instalada en todas las bases de datos de usuario**
  ```sql
  -- Ejecutar en cada base de datos:
  CREATE EXTENSION IF NOT EXISTS pgaudit;
  
  -- Verificar instalación:
  SELECT * FROM pg_extension WHERE extname = 'pgaudit';
  ```
- [ ] **Configuración de pgaudit validada**
  ```sql
  -- Verificar parámetros:
  SHOW pgaudit.log;  -- Debe ser 'ALL' o 'READ, WRITE, DDL'
  SHOW pgaudit.log_client;  -- Debe ser 'ON'
  ```
- [ ] **sessionInfo correlation validada** (ejecutar Test 5 del checklist de testing)
- [ ] 3 alertas principales configuradas (con User/Database/Host tracking)
- [ ] Destinatarios de email/Teams configurados
- [ ] **Filtros opcionales configurados** (excluir service accounts conocidos)
- [ ] Tests de alertas ejecutados exitosamente (Tests 1-5)
- [ ] **UserContext/HostContext tables creadas** (opcional, para enriquecimiento avanzado)
- [ ] Power Automate flows (opcional) creados
- [ ] Documentación de respuesta a incidentes lista
- [ ] Equipo entrenado en interpretación de alertas con contexto de usuario
- [ ] On-call rotation definida

---

**Sistema de Alertas con User Tracking Listo! 🎉**

**Capacidades ahora disponibles**:
✅ Identificación de usuario responsable de anomalías  
✅ Correlación User + Database + Host para todas las alertas  
✅ Filtrado avanzado (excluir service accounts, hosts conocidos)  
✅ Respuesta rápida con comandos SQL específicos por usuario/host  
✅ Auto-blocking posible para hosts con IPs conocidas  

Siguiente paso: Ejecutar tests (especialmente Test 5 para validar correlación) y ajustar umbrales según tu entorno.
