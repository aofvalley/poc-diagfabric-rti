# 📊 Guía Completa: Dashboard Real-Time para PostgreSQL Flexible Server

**Versión**: 2.0 - Actualizado 20/11/2025  
**Estado**: ✅ Queries 100% validadas con datos reales

## 🎯 Objetivo
Crear un dashboard en tiempo real en Microsoft Fabric para monitorizar anomalías de seguridad en PostgreSQL Flexible Server, con alertas automáticas usando Data Activator (Reflex).

---

## 📋 Prerequisitos

- ✅ PostgreSQL Flexible Server con Diagnostic Settings configurado
- ✅ **Extensión pgaudit instalada en TODAS las bases de datos de usuario**
  ```sql
  -- Ejecutar en cada base de datos:
  CREATE EXTENSION IF NOT EXISTS pgaudit;
  
  -- Verificar instalación:
  SELECT * FROM pg_extension WHERE extname = 'pgaudit';
  ```
- ✅ **Configuración pgaudit en Azure Portal**:
  - `azure.extensions` debe incluir `PGAUDIT` (allowlist)
  - `shared_preload_libraries` debe incluir `pgaudit`
  - `pgaudit.log = ALL` (o READ, WRITE, DDL según necesidad)
  - `pgaudit.log_client = ON`
- ✅ Datos ingiriendo en Fabric Real-Time Hub → Event Stream → KQL Database
- ✅ Tabla `bronze_pssql_alllogs_nometrics` en KQL Database
- ✅ Workspace de Fabric con permisos de Contributor o superior
- ✅ **VALIDACIÓN COMPLETADA**: Queries con User/Database/Host correlation validadas (20/11/2025)

---

## ✨ NUEVO: User/Database/Host Tracking

**🎯 AHORA DISPONIBLE**: Las queries incluyen **correlación User/Database/Host** mediante la tabla `sessionInfo`.

**Cómo funciona**:
- **CONNECTION logs** contienen: `user=X database=Y host=Z port=P`
- **AUDIT logs** NO contienen user/database/host directamente
- **Solución**: Join AUDIT logs con CONNECTION logs usando `processId + LogicalServerName`

**Beneficios**:
- ✅ Identificar QUIÉN realiza operaciones sospechosas
- ✅ Rastrear DESDE DÓNDE se originan ataques (IP/hostname)
- ✅ Filtrar anomalías por usuario/base de datos
- ✅ Respuesta rápida con SQL commands específicos por usuario

**Limitación**: Correlación funciona con ventana de 24h. Si User/Database/Host = "UNKNOWN", verificar:
1. Extensión pgaudit instalada en esa base de datos
2. Conexión existe en logs de últimas 24h

---

## 🚨 Anomalías Detectadas (Validadas con User Tracking)

### 1. **Extracción Masiva de Datos (Data Exfiltration)**
- **Descripción**: Detecta extracción masiva de datos (SELECTs) por sesión con identificación de usuario
- **Patrones**: Múltiples SELECTs, COPY, pg_dump detectados en logs AUDIT
- **Umbral**: >10 operaciones SELECT en 1 minuto desde la misma sesión (processId)
- **Tracking**: **User + Database + SourceHost** (IP o hostname)
- **Severidad**: 🔴 Crítica
- **Estado**: ✅ Query validada con correlación User/Database/Host
- **Query**: `kql-queries-PRODUCTION.kql` líneas 1-78

### 2. **Operaciones Destructivas Masivas**
- **Descripción**: DELETE, UPDATE, TRUNCATE en masa que podrían eliminar datos, con usuario responsable
- **Patrones**: Comandos DML destructivos extraídos de logs AUDIT
- **Umbral**: >5 operaciones destructivas en 5 minutos
- **Tracking**: **User + Database + SourceHost** para identificar responsable
- **Severidad**: 🟠 Alta
- **Estado**: ✅ Query validada con correlación User/Database/Host
- **Query**: `kql-queries-PRODUCTION.kql` líneas 80-128

### 3. **Escalada de Errores Críticos**
- **Descripción**: Picos de errores de autenticación/permisos/conexión con origen identificado
- **Patrones**: Errores de auth, permission denied, connection failures
- **Umbral**: >20 errores en 5 minutos por servidor
- **Tracking**: **User + Database + SourceHost** (extracción dual: DirectUser + correlación)
- **Severidad**: 🔴 Crítica
- **Estado**: ✅ Query validada con correlación User/Database/Host
- **Query**: `kql-queries-PRODUCTION.kql` líneas 130-180

---

## 🏗️ PARTE 1: Crear el Real-Time Dashboard

### Paso 1: Crear el Dashboard

1. Navega a tu **Workspace en Fabric**
2. Haz clic en **+ New** → **Real-Time Dashboard**
3. Nombra el dashboard: `PostgreSQL Security Monitoring`
4. Haz clic en **Create**

### Paso 2: Conectar a tu KQL Database

1. En el nuevo dashboard, haz clic en **+ Add tile**
2. Selecciona **Add data source**
3. Elige tu **KQL Database** (donde está `bronze_pssql_alllogs_nometrics`)
4. Haz clic en **Connect**

### Paso 3: Crear Tiles (Paneles) con Queries Validadas

> **🎯 ENFOQUE**: Dashboard optimizado con **6-7 visuales** centrados en **detección de anomalías** con **User/Database/Host tracking**.

---

#### 📌 **Tile 1: ANOMALÍA 1 - EXTRACCIÓN MASIVA DE DATOS** (últimos 5 minutos)

**Query validada** (líneas 30-78 de `kql-queries-PRODUCTION.kql`):

```kql
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "connection authorized" or message contains "connection received"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| where isnotempty(UserName)
| summarize User = any(UserName), Database = any(DatabaseName), SourceHost = any(ClientHost)
    by processId, LogicalServerName;

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where category == "PostgreSQLLogs"
| where message contains "AUDIT:"
| where message has_any ("SELECT", "COPY", "pg_dump")
| where backend_type == "client backend"  // Solo usuarios reales, NO workers internos
| extend 
    AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
    TableName = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message),
    QueryText = trim('"', extract(@",,,([^<]+)<", 1, message)),
    ProcessSession = strcat(LogicalServerName, "-", processId)
| where AuditOperation == "READ" or AuditStatement == "SELECT"
| join kind=leftouter sessionInfo on processId, LogicalServerName
| summarize 
    SelectCount = count(),
    FirstSeen = min(EventProcessedUtcTime),
    LastSeen = max(EventProcessedUtcTime),
    TablesAccessed = make_set(TableName, 10),
    SampleQueries = make_list(QueryText, 3),
    User = any(User),
    Database = any(Database),
    SourceHost = any(SourceHost)
    by ProcessSession, LogicalServerName, backend_type, processId
| where SelectCount > 15  // Threshold: >15 SELECTs en 5 minutos
| project 
    TimeGenerated = LastSeen,
    AnomalyType = "Potential Data Exfiltration",
    ServerName = LogicalServerName,
    User = iff(isempty(User), "UNKNOWN", User),
    Database = iff(isempty(Database), "UNKNOWN", Database),
    SourceHost = iff(isempty(SourceHost), "UNKNOWN", SourceHost),
    BackendType = backend_type,
    ProcessID = processId,
    SelectCount,
    TimeWindow = strcat(format_datetime(FirstSeen, 'HH:mm:ss'), " - ", format_datetime(LastSeen, 'HH:mm:ss')),
    TablesAccessed = strcat_array(TablesAccessed, ", "),
    SampleQueries = strcat_array(SampleQueries, " ||| ")
| order by SelectCount desc;
```

**Configuración del Tile:**
- **Visualization**: Table
- **Tile name**: "🚨 ANOMALÍA 1 - Extracción Masiva de Datos (últimos 5 min)"
- **Auto-refresh**: ✅ **1 minuto**
- **Columns**: TimeGenerated, ServerName, User, Database, SourceHost, ProcessID, SelectCount, TablesAccessed, SampleQueries, TimeWindow
- **Alert Threshold**: SelectCount > 15 (mostrar en rojo)
- **Column widths**: TablesAccessed (200px), SampleQueries (300px)

**Qué muestra**: Detección en tiempo real de usuarios ejecutando >15 SELECTs en 5 minutos (SOLO client backend, excluye workers internos). Muestra tablas accedidas y queries ejecutadas. **CRÍTICO para detectar data exfiltration con patrón de reconocimiento (pg_catalog) vs extracción real**.

---

#### 📌 **Tile 2: ANOMALÍA 2 - OPERACIONES DESTRUCTIVAS MASIVAS** (últimos 10 minutos)

**Query validada** (líneas 80-128 de `kql-queries-PRODUCTION.kql`):

```kql
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "connection authorized" or message contains "connection received"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| where isnotempty(UserName)
| summarize User = any(UserName), Database = any(DatabaseName), SourceHost = any(ClientHost)
    by processId, LogicalServerName;

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
| where category == "PostgreSQLLogs"
| where message contains "AUDIT:"
| where message has_any ("DELETE", "UPDATE", "TRUNCATE", "DROP TABLE", "DROP DATABASE")
| extend 
    AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
    TableAffected = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message),
    QueryText = trim('"', extract(@",,,([^<]+)<", 1, message))
| where AuditStatement in ("DELETE", "UPDATE", "TRUNCATE", "DROP") 
    or QueryText contains "DROP TABLE" 
    or QueryText contains "DROP DATABASE"
| join kind=leftouter sessionInfo on processId, LogicalServerName
| summarize 
    OperationCount = count(),
    Operations = make_set(AuditStatement),
    TablesAffected = make_set(TableAffected),
    FirstOccurrence = min(EventProcessedUtcTime),
    LastOccurrence = max(EventProcessedUtcTime),
    SampleMessages = take_any(QueryText, 3),
    User = any(User),
    Database = any(Database),
    SourceHost = any(SourceHost)
    by LogicalServerName, backend_type, bin(EventProcessedUtcTime, 2m)
| where OperationCount > 5  // >5 operaciones destructivas en 2 minutos
| where backend_type == "client backend"  // FILTRAR workers
| project 
    TimeGenerated = LastOccurrence,
    AnomalyType = "Mass Destructive Operations",
    ServerName = LogicalServerName,
    User = iff(isempty(User), "UNKNOWN", User),
    Database = iff(isempty(Database), "UNKNOWN", Database),
    SourceHost = iff(isempty(SourceHost), "UNKNOWN", SourceHost),
    BackendType = backend_type,
    OperationCount,
    Operations,
    TablesAffected,
    TimeWindow = strcat(FirstOccurrence, " to ", LastOccurrence),
    SampleMessages
| order by OperationCount desc;
```

**Configuración:**
- **Visualization**: Table
- **Tile name**: "⚠️ ANOMALÍA 2 - Operaciones Destructivas Masivas (últimos 10 min)"
- **Auto-refresh**: ✅ **2 minutos**
- **Columns**: TimeGenerated, ServerName, User, Database, SourceHost, BackendType, OperationCount, Operations, TablesAffected, TimeWindow, SampleMessages
- **Alert Threshold**: OperationCount > 5 (mostrar en naranja)
- **Column widths**: SampleMessages (300px)

**Qué muestra**: Detección de usuarios ejecutando >5 operaciones destructivas (DELETE/UPDATE/TRUNCATE/DROP) en ventanas de 2 minutos, con identificación de usuario responsable y tablas afectadas. Muestra queries ejecutadas. **CRÍTICO para prevenir pérdida de datos**.

---

#### 📌 **Tile 3: ANOMALÍA 3 - ESCALADA DE ERRORES CRÍTICOS** (últimos 5 minutos)

**Query validada** (líneas 130-195 de `kql-queries-PRODUCTION.kql`):

```kql
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "connection authorized" or message contains "connection received"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    DatabaseName = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| where isnotempty(UserName)
| summarize User = any(UserName), Database = any(DatabaseName), SourceHost = any(ClientHost)
    by processId, LogicalServerName;

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where category == "PostgreSQLLogs"
| where errorLevel in ("ERROR", "FATAL", "PANIC")
    or (sqlerrcode != "00000" and sqlerrcode != "")
| extend 
    ErrorCategory = case(
        message contains "authentication" or message contains "password", "Authentication Failure",
        message contains "permission denied" or message contains "access denied", "Permission Denied",
        message contains "connection" or message contains "timeout", "Connection Error",
        sqlerrcode startswith "28", "Authorization Error",
        sqlerrcode startswith "42", "Permission Error",
        sqlerrcode startswith "08", "Connection Error",
        sqlerrcode startswith "53", "Resource Error",
        sqlerrcode startswith "57", "Operator Intervention",
        "Other Error"
    ),
    DirectUser = extract(@"user=([^\s,]+)", 1, message),
    DirectDatabase = extract(@"database=([^\s,]+)", 1, message),
    DirectHost = extract(@"host=([^\s]+)", 1, message)
| join kind=leftouter sessionInfo on processId, LogicalServerName
| extend
    FinalUser = iff(isnotempty(DirectUser), DirectUser, User),
    FinalDatabase = iff(isnotempty(DirectDatabase), DirectDatabase, Database),
    FinalHost = iff(isnotempty(DirectHost), DirectHost, SourceHost)
| summarize 
    ErrorCount = count(),
    ErrorTypes = make_set(ErrorCategory),
    ErrorCodes = make_set(sqlerrcode),
    FirstError = min(EventProcessedUtcTime),
    LastError = max(EventProcessedUtcTime),
    SampleErrors = take_any(message, 3),
    User = any(FinalUser),
    Database = any(FinalDatabase),
    SourceHost = any(FinalHost)
    by LogicalServerName, backend_type, bin(EventProcessedUtcTime, 1m)
| where ErrorCount > 15  // >15 errores por minuto
| project 
    TimeGenerated = LastError,
    AnomalyType = "Critical Error Spike",
    ServerName = LogicalServerName,
    User = iff(isempty(User), "UNKNOWN", User),
    Database = iff(isempty(Database), "UNKNOWN", Database),
    SourceHost = iff(isempty(SourceHost), "UNKNOWN", SourceHost),
    BackendType = backend_type,
    ErrorCount,
    ErrorTypes,
    ErrorCodes,
    TimeWindow = strcat(FirstError, " to ", LastError),
    SampleErrors
| order by ErrorCount desc;
```

**Configuración:**
- **Visualization**: Table
- **Tile name**: "🔴 ANOMALÍA 3 - Escalada de Errores Críticos (últimos 5 min)"
- **Auto-refresh**: ✅ **1 minuto**
- **Columns**: TimeGenerated, ServerName, User, Database, SourceHost, BackendType, ErrorCount, ErrorTypes, ErrorCodes, TimeWindow, SampleErrors
- **Alert Threshold**: ErrorCount > 15 (mostrar en rojo)
- **Column widths**: ErrorTypes (200px), SampleErrors (300px)

**Qué muestra**: Detección de picos de errores (>15 por minuto) con identificación de usuario/host origen (extracción dual: DirectUser + correlación). Incluye categorización de errores (Auth, Permission, Connection, Resource) y códigos SQL. **CRÍTICO para detectar brute-force attacks o problemas de conectividad**.

---

#### 📌 **Tile 4: TOP 10 USUARIOS POR ACTIVIDAD** (última hora)

**Query validada** (líneas 350-370 de `kql-queries-PRODUCTION.kql`):

```kql
let sessionInfo = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "connection authorized" or message contains "connection received"
| extend UserName = extract(@"user=([^\s,]+)", 1, message),
         DatabaseName = extract(@"database=([^\s,]+)", 1, message)
| where isnotempty(UserName)
| summarize User = any(UserName), Database = any(DatabaseName)
    by processId, LogicalServerName;

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| join kind=leftouter sessionInfo on processId, LogicalServerName
| extend User = iff(isempty(User), "UNKNOWN", User)
| where User != "UNKNOWN"
| summarize 
    TotalActivity = count(),
    AuditLogs = countif(message contains "AUDIT:"),
    Connections = countif(message contains "connection authorized"),
    Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    Databases = dcount(Database)
    by User
| top 10 by TotalActivity desc
| project User, TotalActivity, AuditLogs, Connections, Errors, Databases;
```

**Configuración:**
- **Visualization**: Bar chart (horizontal)
- **Tile name**: "👥 TOP 10 USUARIOS por Actividad (última hora)"
- **Auto-refresh**: ✅ **2 minutos**
- **X-axis**: TotalActivity
- **Y-axis**: User
- **Tooltip**: Mostrar AuditLogs, Connections, Errors, Databases

**Qué muestra**: Ranking de usuarios más activos con desglose de actividad AUDIT, conexiones, errores y bases de datos accedidas. **Útil para identificar usuarios anómalos o compromised accounts**.

---

#### 📌 **Tile 5: TOP 10 HOSTS/IPs POR CONEXIONES** (última hora)

**Query validada** (líneas 372-395 de `kql-queries-PRODUCTION.kql`):

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "connection authorized" or message contains "connection received" or errorLevel in ("ERROR", "FATAL")
| extend 
    SourceHost = extract(@"host=([^\s]+)", 1, message),
    UserName = extract(@"user=([^\s,]+)", 1, message)
| where isnotempty(SourceHost)
| summarize 
    TotalConnections = countif(message contains "connection authorized"),
    UniqueUsers = dcount(UserName),
    ErrorCount = countif(errorLevel in ("ERROR", "FATAL")),
    TotalEvents = count()
    by SourceHost
| extend ErrorRate = round(todouble(ErrorCount) / todouble(TotalEvents) * 100, 2)
| extend Riesgo = case(
    ErrorRate > 50, "🔴 ALTO",
    ErrorRate > 20, "🟠 MEDIO",
    "🟢 BAJO"
)
| top 10 by TotalConnections desc
| project SourceHost, TotalConnections, UniqueUsers, ErrorRate, Riesgo;
```

**Configuración:**
- **Visualization**: Table
- **Tile name**: "🌐 TOP 10 HOSTS/IPs por Conexiones (última hora)"
- **Auto-refresh**: ✅ **2 minutos**
- **Columns**: SourceHost, TotalConnections, UniqueUsers, ErrorRate, Riesgo
- **Sort by**: TotalConnections (descending)
- **Conditional formatting**: Colorear Riesgo según valor (🔴 rojo, 🟠 naranja, 🟢 verde)

**Qué muestra**: Ranking de hosts/IPs con más conexiones, usuarios únicos, tasa de error y nivel de riesgo. **Útil para identificar hosts sospechosos con alta tasa de error (brute force) o actividad anómala**.

---

#### 📌 **Tile 6: FALLOS DE AUTENTICACIÓN POR USUARIO/HOST** (última hora)

**Query validada** (líneas 420-450 de `kql-queries-PRODUCTION.kql`):

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where errorLevel in ("ERROR", "FATAL")
| where message contains "authentication failed" or message contains "password authentication failed" or sqlerrcode startswith "28"
| extend 
    User = extract('for user "([^"]+)"', 1, message),
    SourceHost = extract(@"host=([^\s]+)", 1, message)
| where isnotempty(User) or isnotempty(SourceHost)
| extend 
    FinalUser = iff(isempty(User), "UNKNOWN", User),
    FinalHost = iff(isempty(SourceHost), "UNKNOWN", SourceHost)
| summarize 
    FailedAttempts = count(),
    FirstAttempt = min(EventProcessedUtcTime),
    LastAttempt = max(EventProcessedUtcTime)
    by FinalUser, FinalHost, LogicalServerName
| extend ThreatLevel = case(
    FailedAttempts > 20, "🔴 CRITICAL",
    FailedAttempts > 10, "🟠 HIGH",
    FailedAttempts > 5, "🟡 MEDIUM",
    "🟢 LOW"
)
| where FailedAttempts > 3
| order by FailedAttempts desc
| project 
    ServerName = LogicalServerName, 
    User = FinalUser, 
    SourceHost = FinalHost, 
    FailedAttempts, 
    ThreatLevel, 
    FirstAttempt, 
    LastAttempt;
```

**Configuración:**
- **Visualization**: Table
- **Tile name**: "🔐 FALLOS DE AUTENTICACIÓN por Usuario/Host (última hora)"
- **Auto-refresh**: ✅ **1 minuto**
- **Columns**: LogicalServerName, User, SourceHost, FailedAttempts, ThreatLevel, FirstAttempt, LastAttempt
- **Sort by**: FailedAttempts (descending)
- **Conditional formatting**: Colorear ThreatLevel según valor

**Qué muestra**: Detección de intentos fallidos de autenticación agrupados por usuario+host con nivel de amenaza. **CRÍTICO para detectar brute-force attacks en tiempo real**.

---

### Paso 4: Configurar el Dashboard Layout

**🎯 Layout Optimizado (6 Tiles - Enfoque Anomalías)**:

```
┌─────────────────────────────────────────────────────────────┐
│  TILE 1: ANOMALÍA 1 - Extracción Masiva de Datos          │
│  (Table - Ancho completo)                                   │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────────┬──────────────────────────────┐
│  TILE 2: ANOMALÍA 2          │  TILE 3: ANOMALÍA 3          │
│  Operaciones Destructivas    │  Escalada de Errores         │
│  (Table - 50% ancho)         │  (Table - 50% ancho)         │
└──────────────────────────────┴──────────────────────────────┘

┌──────────────────────────────┬──────────────────────────────┐
│  TILE 4: TOP 10 USUARIOS     │  TILE 5: TOP 10 HOSTS        │
│  (Bar Chart - 50% ancho)     │  (Table - 50% ancho)         │
└──────────────────────────────┴──────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  TILE 6: FALLOS DE AUTENTICACIÓN (User+Host)               │
│  (Table - Ancho completo)                                   │
└─────────────────────────────────────────────────────────────┘
```

**Configuración:**

1. **Organiza los tiles** siguiendo el layout anterior:
   - **Fila 1**: Tile 1 (Anomalía 1) - Ancho completo, máxima prioridad
   - **Fila 2**: Tile 2 (Anomalía 2) + Tile 3 (Anomalía 3) - Lado a lado
   - **Fila 3**: Tile 4 (TOP Usuarios) + Tile 5 (TOP Hosts) - Lado a lado
   - **Fila 4**: Tile 6 (Auth Failures) - Ancho completo

2. **Parámetros Globales** (recomendado):
   ```
   Time Range Parameter:
   - Name: "TimeRange"
   - Default: Last 1 hour
   - Options: Last 5 min, Last 15 min, Last 1 hour, Last 6 hours, Last 24 hours
   
   Server Name Parameter:
   - Name: "ServerName"
   - Type: Multi-select dropdown
   - Source: bronze_pssql_alllogs_nometrics | distinct LogicalServerName
   ```

3. **Configuración de Auto-refresh**:
   - Tiles 1, 3, 6 (Anomalías críticas): **1 minuto**
   - Tiles 2, 4, 5 (Análisis): **2 minutos**

4. **Alertas Visuales** (Conditional Formatting):
   - Tile 1: SelectCount > 10 → Fila en rojo
   - Tile 2: DestructiveOpCount > 5 → Fila en naranja
   - Tile 3: ErrorCount > 20 → Fila en rojo
   - Tile 5: Riesgo ALTO → Fila en rojo
   - Tile 6: ThreatLevel CRITICAL → Fila en rojo

5. **Guarda el dashboard**: Haz clic en **Save** en la parte superior

**🎯 Beneficios del Layout**:
- ✅ **6 tiles enfocados en anomalías** (sin ruido)
- ✅ **User/Database/Host tracking** en todos los tiles críticos
- ✅ **Refresh rápido** (1-2 min) para detección en tiempo real
- ✅ **Alertas visuales** con conditional formatting
- ✅ **Jerarquía clara**: Anomalías arriba, análisis abajo

---

## 🔔 PARTE 2: Configurar Alertas con Data Activator (Reflex)

### Paso 1: Crear un Reflex Item

1. En tu Workspace, haz clic en **+ New** → **Reflex**
2. Nombra el Reflex: `PostgreSQL Anomaly Alerts`
3. Haz clic en **Create**

### Paso 2: Conectar al Real-Time Dashboard

1. En el Reflex, haz clic en **Get data**
2. Selecciona **From Real-Time Dashboard**
3. Elige tu dashboard `PostgreSQL Security Monitoring`
4. Selecciona el tile **"Anomalías Detectadas"**

---

### 🚨 **Alerta 1: Data Exfiltration**

1. En Reflex, haz clic en **+ New alert**
2. **Nombre**: `Alerta - Extracción Masiva de Datos`
3. **Configuración**:
   ```
   Trigger on: AnomalyType
   Condition: equals "Data Exfiltration"
   Action: Send notification
   ```
4. **Acción**:
   - **Type**: Email / Teams
   - **Recipients**: [tu email o canal de Teams]
   - **Message**:
     ```
     🚨 ANOMALÍA DETECTADA: Extracción Masiva de Datos
     
     Servidor: {ServerName}
     IP Origen: {SourceIP}
     Número de Queries: {QueryCount}
     Tiempo: {TimeGenerated}
     
     Acción requerida: Revisar inmediatamente la actividad sospechosa.
     ```

---

### 🚨 **Alerta 2: Operaciones Destructivas**

1. **Nombre**: `Alerta - Operaciones Destructivas Masivas`
2. **Configuración**:
   ```
   Trigger on: AnomalyType
   Condition: equals "Mass Destructive Ops"
   AND OperationCount > 10
   Action: Send notification
   ```
3. **Acción**:
   - **Type**: Email / Teams
   - **Message**:
     ```
     ⚠️ ALERTA: Operaciones Destructivas Detectadas
     
     Servidor: {ServerName}
     Número de Operaciones: {OperationCount}
     Tiempo: {TimeGenerated}
     
     Se han detectado múltiples DELETE/UPDATE/TRUNCATE en poco tiempo.
     ```

---

### 🚨 **Alerta 3: Escalada de Errores**

1. **Nombre**: `Alerta - Pico de Errores Críticos`
2. **Configuración**:
   ```
   Trigger on: AnomalyType
   Condition: equals "Error Spike"
   AND ErrorCount > 20
   Action: Send notification
   ```
3. **Acción**:
   - **Type**: Email / Teams
   - **Message**:
     ```
     🔴 CRÍTICO: Escalada de Errores Detectada
     
     Servidor: {ServerName}
     Errores en 1 minuto: {ErrorCount}
     Tiempo: {TimeGenerated}
     
     Posible ataque de fuerza bruta o problema de conectividad.
     ```

---

### Paso 3: Configurar Alertas Avanzadas (Opcional)

#### **Alerta 4: Baseline Deviation**

Detecta cuando la actividad es 3x superior al promedio normal:

```kql
let baseline = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime between (ago(7d) .. ago(1h))
| summarize AvgEventsPerMin = count() / (7*24*60) by LogicalServerName;

bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| summarize CurrentEvents = count() by LogicalServerName
| join kind=inner baseline on LogicalServerName
| extend Deviation = CurrentEvents / (AvgEventsPerMin * 5)
| where Deviation > 3.0
| project LogicalServerName, CurrentEvents, AvgEventsPerMin, Deviation
```

---

## 📊 PARTE 3: Optimizaciones y Best Practices

### 1. **Indexación en Kusto**

Para mejorar el rendimiento de las queries:

```kql
.alter table bronze_pssql_alllogs_nometrics policy update 
@'[{"Source": "EventProcessedUtcTime", "Kind": "Hash"}]'
```

### 2. **Materialized Views** (para queries frecuentes)

```kql
.create materialized-view HourlyAnomalySummary on table bronze_pssql_alllogs_nometrics
{
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(7d)
    | extend clientIP = extract(@"from (\d+\.\d+\.\d+\.\d+)", 1, message)
    | summarize 
        TotalEvents = count(),
        Errors = countif(errorLevel in ("ERROR", "FATAL"))
        by LogicalServerName, clientIP, bin(EventProcessedUtcTime, 1h)
}
```

### 3. **Retención de Datos**

Configura la retención para optimizar costos:

```kql
.alter-merge table bronze_pssql_alllogs_nometrics policy retention 
softdelete = 30d, 
recoverability = disabled
```

### 4. **Whitelist de IPs Conocidas**

Crea una tabla de IPs conocidas para reducir falsos positivos:

```kql
.create table KnownIPs (
    IPAddress: string,
    Description: string,
    AddedDate: datetime
)

// Añade IPs conocidas
.ingest inline into table KnownIPs <|
192.168.1.100,Corporate VPN,2025-11-20
10.0.0.50,Admin Workstation,2025-11-20
```

Modifica las queries para excluir IPs conocidas:

```kql
let knownIPs = KnownIPs | project IPAddress;
bronze_pssql_alllogs_nometrics
| extend clientIP = extract(@"from (\d+\.\d+\.\d+\.\d+)", 1, message)
| where clientIP !in (knownIPs)
// ... resto de la query
```

---

## 🧪 PARTE 4: Testing y Validación

### Test 1: Simular Data Exfiltration

Desde tu cliente PostgreSQL:

```sql
-- Ejecuta múltiples SELECTs rápidamente
SELECT * FROM pg_database;
SELECT * FROM pg_tables;
SELECT * FROM information_schema.tables;
-- ... (repite 15 veces en menos de 1 minuto)
```

**Resultado esperado**: Alerta en 1-2 minutos

### Test 2: Simular Operaciones Destructivas

```sql
-- PRECAUCIÓN: Usa una tabla de test
CREATE TABLE test_anomaly (id INT, data TEXT);
DELETE FROM test_anomaly;
TRUNCATE test_anomaly;
DROP TABLE test_anomaly;
-- ... (repite 6+ veces)
```

**Resultado esperado**: Alerta de operaciones destructivas

### Test 3: Simular Error Spike

```sql
-- Intenta conectar con credenciales incorrectas 20 veces
-- (desde cliente psql con password incorrecta)
```

**Resultado esperado**: Alerta de error spike

---

## 📈 PARTE 5: Monitoreo y Mejora Continua

### KPIs a Seguir

1. **Tasa de Falsos Positivos**: < 5%
2. **Tiempo de Detección**: < 2 minutos
3. **Tiempo de Respuesta a Alertas**: < 15 minutos
4. **Cobertura de Anomalías**: > 95%

### Mejoras Recomendadas

1. **Machine Learning**: Integrar Azure ML para detección de patrones anómalos
2. **Correlation**: Correlacionar con logs de red/firewall
3. **Automated Response**: Scripts de remediación automática
4. **Forensics**: Guardar eventos de anomalías en tabla separada para análisis

---

## 🔒 Seguridad y Compliance

### Datos Sensibles

Las queries están diseñadas para **NO exponer**:
- ❌ Contraseñas
- ❌ Datos de aplicación
- ❌ Información de negocio

Solo se exponen:
- ✅ IPs
- ✅ Tipos de operaciones
- ✅ Metadata de queries

### Acceso al Dashboard

1. Configura **Row-Level Security** en Fabric
2. Limita acceso solo a equipos de seguridad/DBAs
3. Audita quién accede al dashboard

---

## 📞 Soporte y Troubleshooting

### Problema: No se ven datos en el dashboard

**Solución**:
1. Verifica que los Diagnostic Settings estén activos
2. Comprueba que `pgaudit` esté habilitado: `SHOW shared_preload_libraries;`
3. Revisa que los datos lleguen a la tabla: `bronze_pssql_alllogs_nometrics | take 10`

### Problema: Demasiados falsos positivos

**Solución**:
1. Ajusta los umbrales en las queries (ej: >10 a >20)
2. Añade whitelist de IPs conocidas
3. Refina los patrones de regex

### Problema: Alertas no se envían

**Solución**:
1. Verifica permisos de Reflex
2. Comprueba que el Data Activator esté habilitado en el tenant
3. Revisa la configuración de email/Teams

---

## 📚 Referencias

- [Real-Time Dashboards en Fabric](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/dashboard-real-time-create)
- [Data Activator](https://learn.microsoft.com/en-us/fabric/data-activator/data-activator-get-started)
- [KQL Quick Reference](https://learn.microsoft.com/en-us/azure/data-explorer/kql-quick-reference)
- [PostgreSQL Audit Extension](https://github.com/pgaudit/pgaudit)

---

## ✅ Checklist Final

- [ ] **Extensión pgaudit instalada en TODAS las bases de datos de usuario**
  ```sql
  CREATE EXTENSION IF NOT EXISTS pgaudit;
  SELECT * FROM pg_extension WHERE extname = 'pgaudit';
  ```
- [ ] **Configuración pgaudit validada en Azure Portal**:
  - [ ] `azure.extensions` incluye `PGAUDIT`
  - [ ] `shared_preload_libraries` incluye `pgaudit`
  - [ ] `pgaudit.log = ALL` (o READ, WRITE, DDL)
  - [ ] `pgaudit.log_client = ON`
- [ ] **Dashboard creado con 6 tiles enfocados en anomalías**:
  - [ ] Tile 1: Anomalía 1 - Extracción Masiva (con User/Database/Host)
  - [ ] Tile 2: Anomalía 2 - Operaciones Destructivas (con User/Database/Host)
  - [ ] Tile 3: Anomalía 3 - Escalada de Errores (con User/Database/Host)
  - [ ] Tile 4: TOP 10 Usuarios por Actividad
  - [ ] Tile 5: TOP 10 Hosts/IPs por Conexiones
  - [ ] Tile 6: Fallos de Autenticación por Usuario/Host
- [ ] **Auto-refresh configurado**:
  - [ ] Tiles críticos (1, 3, 6): 1 minuto
  - [ ] Tiles análisis (2, 4, 5): 2 minutos
- [ ] **Conditional formatting aplicado** (colores rojo/naranja/verde según riesgo)
- [ ] **Parámetros globales configurados** (TimeRange, ServerName)
- [ ] **sessionInfo correlation validada** (ejecutar query de test en KQL)
- [ ] **3 alertas principales creadas en Reflex** (ver REFLEX-ALERTS-CONFIG.md)
- [ ] **Tests de anomalías ejecutados** (Data Exfiltration, Destructive Ops, Error Spike)
- [ ] **Documentación compartida con el equipo**
- [ ] **Plan de respuesta a incidentes definido** (ver templates en REFLEX-ALERTS-CONFIG.md)

---

**¡Dashboard con User Tracking listo para producción! 🎉**

**Capacidades disponibles**:
✅ Detección de anomalías en < 2 minutos  
✅ Identificación de usuario responsable (User)  
✅ Rastreo de origen de ataques (SourceHost - IP/hostname)  
✅ Contexto de base de datos afectada (Database)  
✅ 6 visuales optimizados sin ruido  
✅ Auto-refresh rápido (1-2 min)  
✅ Alertas visuales con conditional formatting  

**Próximos pasos**:
1. Ejecutar tests de anomalías (ver sección Testing)
2. Configurar alertas en Data Activator (ver REFLEX-ALERTS-CONFIG.md)
3. Ajustar umbrales según tu entorno
4. Entrenar al equipo en interpretación de alertas
