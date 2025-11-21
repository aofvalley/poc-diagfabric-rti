# 📊 Guía Completa: Dashboard + Reflex Alerts

**PostgreSQL Anomaly Detection - Configuración Paso a Paso**

---

## 🎨 PARTE 1: Configurar Dashboard en Fabric

### Paso 1: Crear Dashboard (2 min)

1. Abre **Fabric Portal** → Tu Workspace
2. **+ New** → **Real-Time Dashboard**
3. Nombre: `PostgreSQL Security Monitor`
4. **Create**

### Paso 2: Conectar Data Source (1 min)

1. En el dashboard recién creado, click **Manage** (arriba derecha)
2. **Data sources** → **+ Add data source**
3. Selecciona tu **KQL Database** (donde está `bronze_pssql_alllogs_nometrics`)
4. **Add**

### Paso 3: Añadir Tiles del Dashboard (15 min)

#### 🔴 TILE 1: Anomalía 1 - Data Exfiltration

1. **+ Add tile** → **KQL Query**
2. Copia esta query desde `kql-queries-PRODUCTION.kql` (líneas ~26-70):

```kql
// ============================================================================
// ANOMALÍA 1: Data Exfiltration Detection
// ============================================================================
let sessionInfo = bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized:"
    | extend 
        processId = tostring(extract(@"connection authorized: user=.+ database=.+ application_name=.+ (\d+)", 1, message)),
        User = tostring(extract(@"connection authorized: user=([^ ]+)", 1, message)),
        Database = tostring(extract(@"database=([^ ]+)", 1, message)),
        ClientIP = tostring(extract(@"host=([^\(]+)", 1, message))
    | where isnotempty(processId) and isnotempty(User) and isnotempty(Database)
    | project processId, User, Database, ClientIP, EventProcessedUtcTime
    | summarize arg_max(EventProcessedUtcTime, *) by processId;
let suspiciousDataAccess = bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(5m)
    | where message contains "AUDIT: SESSION"
    | where message contains ",READ,SELECT,"
    | extend 
        processId = tostring(extract(@"AUDIT: SESSION,(\d+),", 1, message)),
        Operation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
        Statement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
        QueryText = trim('"', extract(@",,,([^<]+)<", 1, message))
    | where isnotempty(processId)
    | join kind=leftouter (sessionInfo) on processId
    | extend 
        User = iff(isnotempty(User), User, "UNKNOWN"),
        Database = iff(isnotempty(Database), Database, "UNKNOWN"),
        ClientIP = iff(isnotempty(ClientIP), ClientIP, "UNKNOWN")
    | summarize 
        SelectCount = count(),
        FirstQuery = min(EventProcessedUtcTime),
        LastQuery = max(EventProcessedUtcTime),
        SampleQuery = any(QueryText)
        by User, Database, ClientIP, bin(EventProcessedUtcTime, 1m)
    | where SelectCount > 15
    | extend 
        AnomalyType = "Potential Data Exfiltration",
        Severity = "HIGH",
        Duration = LastQuery - FirstQuery
    | project 
        DetectedAt = LastQuery,
        AnomalyType,
        Severity,
        User,
        Database,
        ClientIP,
        SelectCount,
        Duration,
        SampleQuery
    | order by DetectedAt desc;
suspiciousDataAccess
```

3. **Visual type**: Table
4. **Tile name**: `🔴 Anomalía 1: Data Exfiltration (>15 SELECTs/min)`
5. **Auto-refresh**: 2 minutes
6. **Apply changes**

---

#### 🟠 TILE 2: Anomalía 2 - Destructive Operations

1. **+ Add tile** → **KQL Query**
2. Copia esta query desde `kql-queries-PRODUCTION.kql` (líneas ~76-145):

```kql
// ============================================================================
// ANOMALÍA 2: Mass Destructive Operations Detection
// ============================================================================
let sessionInfo = bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized:"
    | extend 
        processId = tostring(extract(@"connection authorized: user=.+ database=.+ application_name=.+ (\d+)", 1, message)),
        User = tostring(extract(@"connection authorized: user=([^ ]+)", 1, message)),
        Database = tostring(extract(@"database=([^ ]+)", 1, message)),
        ClientIP = tostring(extract(@"host=([^\(]+)", 1, message))
    | where isnotempty(processId) and isnotempty(User) and isnotempty(Database)
    | project processId, User, Database, ClientIP, EventProcessedUtcTime
    | summarize arg_max(EventProcessedUtcTime, *) by processId;
let destructiveOperations = bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(2m)
    | where message contains "AUDIT: SESSION"
    | where message contains ",WRITE,"
    | where message contains_any(",DELETE,", ",UPDATE,", ",TRUNCATE,", ",DROP,")
    | extend 
        processId = tostring(extract(@"AUDIT: SESSION,(\d+),", 1, message)),
        Operation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
        Statement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
        QueryText = trim('"', extract(@",,,([^<]+)<", 1, message))
    | where Statement in ("DELETE", "UPDATE", "TRUNCATE", "DROP")
    | where isnotempty(processId)
    | join kind=leftouter (sessionInfo) on processId
    | extend 
        User = iff(isnotempty(User), User, "UNKNOWN"),
        Database = iff(isnotempty(Database), Database, "UNKNOWN"),
        ClientIP = iff(isnotempty(ClientIP), ClientIP, "UNKNOWN")
    | summarize 
        OperationCount = count(),
        FirstOperation = min(EventProcessedUtcTime),
        LastOperation = max(EventProcessedUtcTime),
        Operations = make_set(Statement),
        SampleQuery = any(QueryText)
        by User, Database, ClientIP
    | where OperationCount > 5
    | extend 
        AnomalyType = "Mass Destructive Operations",
        Severity = "CRITICAL",
        Duration = LastOperation - FirstOperation
    | project 
        DetectedAt = LastOperation,
        AnomalyType,
        Severity,
        User,
        Database,
        ClientIP,
        OperationCount,
        Operations,
        Duration,
        SampleQuery
    | order by DetectedAt desc;
destructiveOperations
```

3. **Visual type**: Table
4. **Tile name**: `🟠 Anomalía 2: Destructive Operations (>5 ops/2min)`
5. **Auto-refresh**: 1 minute
6. **Apply changes**

---

#### 🔴 TILE 3: Anomalía 3 - Error Spike

1. **+ Add tile** → **KQL Query**
2. Copia esta query desde `kql-queries-PRODUCTION.kql` (líneas ~151-210):

```kql
// ============================================================================
// ANOMALÍA 3: Error Spike Detection (Brute Force / Misconfiguration)
// ============================================================================
let sessionInfo = bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized:"
    | extend 
        processId = tostring(extract(@"connection authorized: user=.+ database=.+ application_name=.+ (\d+)", 1, message)),
        User = tostring(extract(@"connection authorized: user=([^ ]+)", 1, message)),
        Database = tostring(extract(@"database=([^ ]+)", 1, message)),
        ClientIP = tostring(extract(@"host=([^\(]+)", 1, message))
    | where isnotempty(processId) and isnotempty(User) and isnotempty(Database)
    | project processId, User, Database, ClientIP, EventProcessedUtcTime
    | summarize arg_max(EventProcessedUtcTime, *) by processId;
let errorSpike = bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(30m)  // ⚠️ TROUBLESHOOTING: Expandido a 30m
    | where errorLevel in ("ERROR", "FATAL", "PANIC")
    | where message contains_any("authentication failed", "permission denied", "does not exist", "connection")
    | extend 
        processId = tostring(extract(@"connection authorized: user=.+ database=.+ application_name=.+ (\d+)", 1, message)),
        DirectUser = tostring(extract(@"for user ""([^""]+)""", 1, message)),
        ErrorCode = extract(@"^([0-9A-Z]{5}):", 1, message),
        ErrorType = case(
            message contains "authentication failed", "AUTH_FAILED",
            message contains "permission denied", "PERMISSION_DENIED",
            message contains "does not exist", "OBJECT_NOT_FOUND",
            message contains "connection", "CONNECTION_ERROR",
            "OTHER"
        )
    | join kind=leftouter (sessionInfo) on processId
    | extend 
        FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN")),
        Database = iff(isnotempty(Database), Database, "UNKNOWN"),
        ClientIP = iff(isnotempty(ClientIP), ClientIP, "UNKNOWN")
    | summarize 
        ErrorCount = count(),
        FirstError = min(EventProcessedUtcTime),
        LastError = max(EventProcessedUtcTime),
        ErrorTypes = make_set(ErrorType),
        ErrorCodes = make_set(ErrorCode),
        SampleMessage = any(message)
        by FinalUser, Database, ClientIP, bin(EventProcessedUtcTime, 1m)
    // ⚠️ TROUBLESHOOTING: Threshold temporalmente removido
    // | where ErrorCount > 15  // Restaurar después de validar que aparecen datos
    | extend 
        AnomalyType = "Error Spike",
        Severity = "CRITICAL",
        Duration = LastError - FirstError
    | project 
        DetectedAt = LastError,
        AnomalyType,
        Severity,
        User = FinalUser,
        Database,
        ClientIP,
        ErrorCount,
        ErrorTypes,
        ErrorCodes,
        Duration,
        SampleMessage
    | order by ErrorCount desc;  // ⚠️ TROUBLESHOOTING: Ordenar por ErrorCount
errorSpike
```

3. **Visual type**: Table
4. **Tile name**: `🔴 Anomalía 3: Error Spike (>15 errores/min)`
5. **Auto-refresh**: 1 minute
6. **Apply changes**

> **⚠️ IMPORTANTE**: Esta query está en modo troubleshooting (30m window, sin threshold). Una vez que valides que aparecen datos, edita el tile y:
> - Cambia línea 16: `ago(30m)` → `ago(5m)`
> - Descomenta línea 45: `| where ErrorCount > 15`

---

#### 📊 TILE 4: Actividad por Servidor (Time Chart)

1. **+ Add tile** → **KQL Query**
2. Pega esta query:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(15m)
| summarize
    TotalEvents = count(),
    Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    Warnings = countif(errorLevel == "WARNING")
    by LogicalServerName, bin(EventProcessedUtcTime, 1m)
| render timechart
```

3. **Visual type**: Time chart (auto-detect)
4. **Tile name**: `📈 Actividad por Servidor (últimos 15 min)`
5. **Auto-refresh**: 1 minute
6. **Apply changes**

---

#### 🌍 TILE 5: Top IPs con Actividad (24h)

1. **+ Add tile** → **KQL Query**
2. Pega esta query:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "connection authorized:"
| extend ClientIP = tostring(extract(@"host=([^\(]+)", 1, message))
| where isnotempty(ClientIP)
| summarize 
    Connections = count(),
    UniqueUsers = dcount(extract(@"user=([^ ]+)", 1, message)),
    UniqueDatabases = dcount(extract(@"database=([^ ]+)", 1, message)),
    FirstSeen = min(EventProcessedUtcTime),
    LastSeen = max(EventProcessedUtcTime)
    by ClientIP
| order by Connections desc
| take 10
```

3. **Visual type**: Table
4. **Tile name**: `🌍 Top 10 IPs (últimas 24h)`
5. **Auto-refresh**: 5 minutes
6. **Apply changes**

---

#### 👤 TILE 6: Top Usuarios Más Activos (24h)

1. **+ Add tile** → **KQL Query**
2. Pega esta query:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "AUDIT: SESSION"
| extend User = tostring(extract(@"user=([^ ]+)", 1, message))
| where isnotempty(User)
| summarize 
    Operations = count(),
    Databases = dcount(extract(@"database=([^ ]+)", 1, message)),
    Reads = countif(message contains ",READ,"),
    Writes = countif(message contains ",WRITE,")
    by User
| order by Operations desc
| take 10
```

3. **Visual type**: Table
4. **Tile name**: `👤 Top 10 Usuarios Activos (24h)`
5. **Auto-refresh**: 5 minutes
6. **Apply changes**

---

### Paso 4: Guardar y Publicar Dashboard

1. **Save** (arriba derecha)
2. Verifica que todos los tiles se refrescan correctamente
3. **Publish** → Share con tu equipo

---

## 🔔 PARTE 2: Configurar Reflex Alerts (Data Activator)

### Paso 1: Crear Reflex Item (3 min)

1. Vuelve a tu **Workspace** en Fabric
2. **+ New** → **Reflex**
3. Nombre: `PostgreSQL_Security_Alerts`
4. **Create**

### Paso 2: Conectar a Dashboard (2 min)

1. En Reflex recién creado, **Get data**
2. Selecciona **Real-Time Dashboard**
3. Selecciona tu dashboard `PostgreSQL Security Monitor`
4. Click **Connect**

### Paso 3: Crear Alerta 1 - Data Exfiltration (5 min)

1. **+ New alert**
2. **Select data**: Selecciona el tile `🔴 Anomalía 1: Data Exfiltration`
3. **Configure alert**:
   - **Name**: `Alert_DataExfiltration`
   - **Condition**: `SelectCount > 15`
   - **Time window**: `Every 2 minutes`
   - **Grouping**: `User, Database, ClientIP`
4. **Actions**:
   - **Email**: Añade tu dirección de email
   - **Subject**: `🚨 ALERTA: Posible Data Exfiltration Detectada`
   - **Body template**:
     ```
     ANOMALÍA DETECTADA: Data Exfiltration
     
     Usuario: {User}
     Base de datos: {Database}
     IP Cliente: {ClientIP}
     Número de SELECTs: {SelectCount}
     Duración: {Duration}
     
     Query de ejemplo:
     {SampleQuery}
     
     Detectado a las: {DetectedAt}
     
     Por favor, investiga inmediatamente.
     ```
5. **Save & Activate**

---

### Paso 4: Crear Alerta 2 - Destructive Operations (5 min)

1. **+ New alert**
2. **Select data**: Selecciona el tile `🟠 Anomalía 2: Destructive Operations`
3. **Configure alert**:
   - **Name**: `Alert_DestructiveOps`
   - **Condition**: `OperationCount > 5`
   - **Time window**: `Every 1 minute`
   - **Grouping**: `User, Database, ClientIP`
4. **Actions**:
   - **Email**: Añade tu dirección de email
   - **Subject**: `🚨 CRÍTICO: Operaciones Destructivas Masivas Detectadas`
   - **Body template**:
     ```
     ANOMALÍA CRÍTICA: Mass Destructive Operations
     
     Usuario: {User}
     Base de datos: {Database}
     IP Cliente: {ClientIP}
     Operaciones ejecutadas: {OperationCount}
     Tipos: {Operations}
     Duración: {Duration}
     
     Query de ejemplo:
     {SampleQuery}
     
     Detectado a las: {DetectedAt}
     
     ⚠️ ACCIÓN INMEDIATA REQUERIDA
     ```
5. **Teams** (opcional):
   - Añade un webhook de Teams para notificaciones en canal
6. **Save & Activate**

---

### Paso 5: Crear Alerta 3 - Error Spike (5 min)

1. **+ New alert**
2. **Select data**: Selecciona el tile `🔴 Anomalía 3: Error Spike`
3. **Configure alert**:
   - **Name**: `Alert_ErrorSpike`
   - **Condition**: `ErrorCount > 15`
   - **Time window**: `Every 1 minute`
   - **Grouping**: `User, Database, ClientIP`
4. **Actions**:
   - **Email**: Añade tu dirección de email
   - **Subject**: `🚨 ALERTA: Spike de Errores Detectado (Posible Brute Force)`
   - **Body template**:
     ```
     ANOMALÍA DETECTADA: Error Spike
     
     Usuario: {User}
     Base de datos: {Database}
     IP Cliente: {ClientIP}
     Número de errores: {ErrorCount}
     Tipos de error: {ErrorTypes}
     Códigos: {ErrorCodes}
     Duración: {Duration}
     
     Mensaje de ejemplo:
     {SampleMessage}
     
     Detectado a las: {DetectedAt}
     
     Posible brute force attack o misconfiguration.
     ```
5. **Save & Activate**

---

## ✅ PARTE 3: Validar Configuración

### Test 1: Generar Anomalías de Prueba

1. Abre **Azure Data Studio** o **psql**
2. Conecta a tu PostgreSQL (base de datos `adventureworks`)
3. Ejecuta `TEST-ANOMALY-TRIGGERS.sql` (líneas 50-100 para Anomalía 1)
4. Espera 2-3 minutos
5. Vuelve al dashboard y verifica que aparece la anomalía en el tile correspondiente

### Test 2: Verificar Alertas

1. Después de ejecutar el test anterior, espera 3-5 minutos
2. Verifica tu email
3. Deberías recibir un email con el subject `🚨 ALERTA: Posible Data Exfiltration Detectada`
4. Si no lo recibes, revisa:
   - ✅ Reflex alert está **Activated** (no en Draft)
   - ✅ Email configurado correctamente en la acción
   - ✅ Threshold configurado correctamente (`SelectCount > 15`)

---

## 🔧 TROUBLESHOOTING

### Problema: Dashboard muestra "No data"

**Solución**:
1. Verifica que Event Stream está ingesting data:
   ```kql
   bronze_pssql_alllogs_nometrics
   | where EventProcessedUtcTime >= ago(5m)
   | take 10
   ```
2. Si está vacío, revisa:
   - ✅ Diagnostic Settings habilitado en Azure Portal
   - ✅ Event Hub recibiendo eventos
   - ✅ Event Stream en Fabric conectado correctamente

### Problema: Anomalía 3 no muestra nada

**Solución** (ya aplicada en la query arriba):
- Query en modo troubleshooting: `ago(30m)` y sin threshold
- Una vez que veas datos, restaura configuración de producción

### Problema: Alertas no se disparan

**Solución**:
1. Verifica que el tile en el dashboard tiene datos
2. Asegúrate de que la condición en Reflex coincide con la columna del tile
3. Verifica que el threshold es alcanzable (prueba con valor más bajo temporalmente)

---

## 📚 Queries Adicionales Útiles

### Query: Ver Todas las Anomalías Combinadas

```kql
union
    (suspiciousDataAccess | extend AnomalyType = "Data Exfiltration"),
    (destructiveOperations | extend AnomalyType = "Destructive Operations"),
    (errorSpike | extend AnomalyType = "Error Spike")
| order by DetectedAt desc
| take 100
```

### Query: Histórico de Anomalías (últimas 24h)

```kql
// Cambiar ago(5m) → ago(24h) en cada query individual
// y ejecutar la query combinada de arriba
```

---

**Versión**: 1.0  
**Última actualización**: 21/11/2025  
**Autor**: Alfonso Domínguez
