# 🚨 Queries Específicas para Alertas en Data Activator (Reflex)

**Versión**: 3.0 - Queries Completas y Listas para Usar  
**Fecha**: 20/11/2025  
**Estado**: ✅ Validado con datos reales

> **IMPORTANTE**: Estas queries están listas para copiar/pegar directamente en Data Activator.  
> Cada query es independiente y contiene TODA la lógica necesaria.

---

## 📋 Prerequisitos Antes de Configurar Alertas

### 1. Extensión pgaudit Instalada
```sql
-- Ejecutar en CADA base de datos de usuario:
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Verificar instalación:
SELECT * FROM pg_extension WHERE extname = 'pgaudit';
```

### 2. Configuración pgaudit en Server Parameters
```bash
# En Azure Portal > PostgreSQL Server > Server parameters:
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'read, write, ddl'
pgaudit.log_catalog = 'off'
pgaudit.log_parameter = 'on'
pgaudit.log_relation = 'on'
```

### 3. Verificar que llegan logs AUDIT
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| take 10
```
**Si esta query NO retorna datos, las alertas NO funcionarán. Verifica prerequisitos 1 y 2.**

---

## 🔴 ALERTA 1: Extracción Masiva de Datos (Data Exfiltration)

### ¿Qué Detecta?
- Más de **15 operaciones SELECT** en una ventana de **5 minutos** desde la misma sesión
- Queries con `COPY` o `pg_dump` (exportación de datos)
- Solo actividad de **usuarios reales** (excluye workers internos de PostgreSQL)

### Query Completa para Data Activator

```kql
// ============================================================================
// ALERTA 1: Data Exfiltration - Query Completa
// ============================================================================
// Copiar esta query COMPLETA en Data Activator
// Evaluación recomendada: Cada 1 minuto
// ============================================================================

// Paso 1: Construir tabla de sesiones (correlación User/Database/Host)
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

// Paso 2: Detectar actividad sospechosa de lectura
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)  // Ventana de detección: últimos 5 minutos
| where category == "PostgreSQLLogs"
| where message contains "AUDIT:"
| where message has_any ("SELECT", "COPY", "pg_dump")
| where backend_type == "client backend"  // SOLO usuarios reales
| extend 
    AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
    TableName = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message),
    QueryText = trim('"', extract(@",,,([^<]+)<", 1, message)),
    ProcessSession = strcat(LogicalServerName, "-", processId)
| where AuditOperation == "READ" or AuditStatement == "SELECT"
// Paso 3: Enriquecer con User/Database/Host
| join kind=leftouter sessionInfo on processId, LogicalServerName
// Paso 4: Agrupar por sesión y contar
| summarize 
    SelectCount = count(),
    FirstSeen = min(EventProcessedUtcTime),
    LastSeen = max(EventProcessedUtcTime),
    TablesAccessed = make_set(TableName, 10),
    SampleQueries = make_set(QueryText, 3),  // Cambio: make_set en lugar de make_list
    User = any(User),
    Database = any(Database),
    SourceHost = any(SourceHost)
    by ProcessSession, LogicalServerName, backend_type, processId
// Paso 5: Aplicar threshold (>15 SELECTs en 5 min)
| where SelectCount > 15
// Paso 6: Formatear output para alerta
| extend AnomalyType = "Potential Data Exfiltration"
| project 
    TimeGenerated = LastSeen,
    AnomalyType,
    ServerName = LogicalServerName,
    User = iff(isempty(User), "UNKNOWN", User),
    Database = iff(isempty(Database), "UNKNOWN", Database),
    SourceHost = iff(isempty(SourceHost), "UNKNOWN", SourceHost),
    ProcessID = processId,
    SelectCount,
    TimeWindow = strcat(format_datetime(FirstSeen, 'HH:mm:ss'), " - ", format_datetime(LastSeen, 'HH:mm:ss')),
    TablesAccessed = strcat_array(TablesAccessed, ", "),
    SampleQueries = strcat_array(SampleQueries, " ||| ")  // Ahora funciona porque make_set retorna array
| order by SelectCount desc
```

### Configuración en Data Activator

**Paso a Paso:**

1. **Crear Reflex Item**:
   - En tu Workspace → **+ New** → **Reflex**
   - Nombre: `Alert_DataExfiltration`

2. **Get Data**:
   - Click **Get data** → **KQL Database**
   - Selecciona tu database
   - **Pega la query completa de arriba** ☝️
   - Click **Next**

3. **Configurar Trigger**:
   - **Object to monitor**: Resultado de la query
   - **Event**: When data arrives
   - **Filter** (opcional, para reducir falsos positivos):
     ```
     User != "UNKNOWN" 
     AND User !in ("etl_service", "backup_admin", "monitoring_user")
     AND SelectCount > 20
     ```

4. **Alert Rule**:
   - **Condition**: `SelectCount > 15`
   - **Evaluate**: Every **1 minute**
   - **Suppress for**: **5 minutes**
   - **Severity**: **Critical**

5. **Actions - Email**:
   ```yaml
   To: security-team@company.com, dba-team@company.com
   Subject: 🚨 ALERTA CRÍTICA - Posible Extracción de Datos PostgreSQL
   Body: |
     ⚠️ ANOMALÍA DETECTADA: Extracción Masiva de Datos
     
     📊 DETALLES:
     • Tipo: {AnomalyType}
     • Servidor: {ServerName}
     • Usuario: {User}
     • Base de Datos: {Database}
     • IP/Host Origen: {SourceHost}
     • ProcessID: {ProcessID}
     
     📈 ACTIVIDAD SOSPECHOSA:
     • Operaciones SELECT: {SelectCount} en 5 minutos
     • Ventana Temporal: {TimeWindow}
     
     📋 TABLAS ACCEDIDAS:
     {TablesAccessed}
     
     🔍 QUERIES EJECUTADAS (muestra):
     {SampleQueries}
     
     ⚡ ACCIONES INMEDIATAS:
     1. Verificar si el usuario {User} está autorizado para esta actividad
     2. Si es sospechoso, terminar sesión:
        SELECT pg_terminate_backend({ProcessID});
     3. Revisar histórico completo del usuario
     4. Si SourceHost es desconocido, bloquear IP en firewall
     
     🔗 [Ver Dashboard](link_to_dashboard)
   ```

6. **Actions - Teams** (opcional):
   ```yaml
   Channel: #security-alerts
   Message: |
     🚨 **CRÍTICO - Data Exfiltration PostgreSQL**
     
     **Usuario**: {User}
     **Database**: {Database}
     **Origen**: {SourceHost}
     **SELECTs**: {SelectCount} en 5 min
     **Tablas**: {TablesAccessed}
     
     [Ver Dashboard](link)
   ```

### Test de la Alerta

Ejecuta esto para disparar la alerta:

```sql
-- Conectarse a una base de datos
\c testdb

-- Ejecutar 20 SELECTs rápidamente
DO $$
BEGIN
    FOR i IN 1..20 LOOP
        PERFORM * FROM pg_tables LIMIT 1;
    END LOOP;
END $$;
```

**Verificación**: Deberías recibir la alerta en **< 2 minutos**.

---

## ⚠️ ALERTA 2: Operaciones Destructivas Masivas

### ¿Qué Detecta?
- Más de **5 operaciones destructivas** (DELETE/UPDATE/TRUNCATE/DROP) en una ventana de **2 minutos**
- Solo actividad de **usuarios reales** (excluye workers/vacuums automáticos)
- Identifica tablas afectadas y operaciones ejecutadas

### Query Completa para Data Activator

```kql
// ============================================================================
// ALERTA 2: Mass Destructive Operations - Query Completa
// ============================================================================
// Copiar esta query COMPLETA en Data Activator
// Evaluación recomendada: Cada 2 minutos
// ============================================================================

// Paso 1: Construir tabla de sesiones (correlación User/Database/Host)
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

// Paso 2: Detectar operaciones destructivas
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)  // Ventana de búsqueda: 10 minutos
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
// Paso 3: Enriquecer con User/Database/Host
| join kind=leftouter sessionInfo on processId, LogicalServerName
// Paso 4: Agrupar por servidor y ventanas de 2 minutos
| summarize 
    OperationCount = count(),
    Operations = make_set(AuditStatement),
    TablesAffected = make_set(TableAffected),
    FirstOccurrence = min(EventProcessedUtcTime),
    LastOccurrence = max(EventProcessedUtcTime),
    SampleQueries = make_set(QueryText, 3),  // Cambio: make_set en lugar de take_any
    User = any(User),
    Database = any(Database),
    SourceHost = any(SourceHost)
    by LogicalServerName, backend_type, bin(EventProcessedUtcTime, 2m)
// Paso 5: Aplicar threshold (>5 ops destructivas en 2 min)
| where OperationCount > 5
// Paso 6: Filtrar solo usuarios reales (NO workers)
| where backend_type == "client backend"
// Paso 7: Formatear output para alerta
| extend AnomalyType = "Mass Destructive Operations"
| project 
    TimeGenerated = LastOccurrence,
    AnomalyType,
    ServerName = LogicalServerName,
    User = iff(isempty(User), "UNKNOWN", User),
    Database = iff(isempty(Database), "UNKNOWN", Database),
    SourceHost = iff(isempty(SourceHost), "UNKNOWN", SourceHost),
    OperationCount,
    Operations = strcat_array(Operations, ", "),
    TablesAffected = strcat_array(TablesAffected, ", "),
    TimeWindow = strcat(format_datetime(FirstOccurrence, 'HH:mm:ss'), " - ", format_datetime(LastOccurrence, 'HH:mm:ss')),
    SampleQueries = strcat_array(SampleQueries, " ||| ")  // Ahora funciona porque make_set retorna array
| order by OperationCount desc
```

### Configuración en Data Activator

**Paso a Paso:**

1. **Crear Reflex Item**:
   - Nombre: `Alert_MassDestructiveOps`

2. **Get Data**:
   - **Pega la query completa de arriba** ☝️

3. **Configurar Trigger**:
   - **Filter** (opcional):
     ```
     User != "UNKNOWN" 
     AND User !in ("etl_service", "maintenance_user")
     AND Database !in ("testdb", "staging_db")
     AND OperationCount > 5
     ```

4. **Alert Rule**:
   - **Condition**: `OperationCount > 5`
   - **Evaluate**: Every **2 minutes**
   - **Suppress for**: **10 minutes**
   - **Severity**: **High**

5. **Actions - Email**:
   ```yaml
   To: dba-team@company.com, app-owners@company.com
   Subject: ⚠️ ALERTA - Operaciones Destructivas Masivas en PostgreSQL
   Body: |
     ⚠️ OPERACIONES DESTRUCTIVAS DETECTADAS
     
     📊 DETALLES:
     • Tipo: {AnomalyType}
     • Servidor: {ServerName}
     • Usuario: {User}
     • Base de Datos: {Database}
     • IP/Host Origen: {SourceHost}
     
     🔥 ACTIVIDAD DESTRUCTIVA:
     • Operaciones: {OperationCount} en 2 minutos
     • Tipos: {Operations}
     • Ventana: {TimeWindow}
     
     📋 TABLAS AFECTADAS:
     {TablesAffected}
     
     🔍 QUERIES EJECUTADAS (muestra):
     {SampleQueries}
     
     ⚡ ACCIONES INMEDIATAS:
     1. Verificar si {User} está autorizado para estas operaciones
     2. Revisar integridad de datos en tablas: {TablesAffected}
     3. Validar backups recientes disponibles
     4. Si no autorizado, revocar permisos:
        REVOKE ALL ON DATABASE {Database} FROM {User};
     
     🔗 [Ver Dashboard](link_to_dashboard)
   ```

### Test de la Alerta

```sql
-- Crear tabla de test
CREATE TABLE test_destructive_ops (id SERIAL, data TEXT);
INSERT INTO test_destructive_ops SELECT generate_series(1,100), 'test';

-- Ejecutar 6 operaciones destructivas rápidamente
DELETE FROM test_destructive_ops WHERE id = 1;
DELETE FROM test_destructive_ops WHERE id = 2;
UPDATE test_destructive_ops SET data = 'x' WHERE id = 3;
DELETE FROM test_destructive_ops WHERE id = 4;
TRUNCATE test_destructive_ops;
DROP TABLE test_destructive_ops;
```

**Verificación**: Deberías recibir la alerta en **< 3 minutos**.

---

## 🔴 ALERTA 3: Escalada de Errores Críticos (Error Spike)

### ¿Qué Detecta?
- Más de **15 errores críticos** (ERROR/FATAL/PANIC) en una ventana de **1 minuto**
- Categoriza errores: Authentication, Permission, Connection, Resources
- Identifica códigos SQL específicos y usuarios afectados

### Query Completa para Data Activator

```kql
// ============================================================================
// ALERTA 3: Critical Error Spike - Query Completa
// ============================================================================
// Copiar esta query COMPLETA en Data Activator
// Evaluación recomendada: Cada 1 minuto
// ============================================================================

// Paso 1: Construir tabla de sesiones (correlación User/Database/Host)
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

// Paso 2: Detectar errores críticos
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)  // Ventana de búsqueda: 5 minutos
| where category == "PostgreSQLLogs"
| where errorLevel in ("ERROR", "FATAL", "PANIC")
    or (sqlerrcode != "00000" and sqlerrcode != "")
// Paso 3: Categorizar errores
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
    // Extraer User/Database/Host directamente de mensajes de error
    DirectUser = extract(@"user=([^\s,]+)", 1, message),
    DirectDatabase = extract(@"database=([^\s,]+)", 1, message),
    DirectHost = extract(@"host=([^\s]+)", 1, message)
// Paso 4: Enriquecer con sessionInfo (fallback)
| join kind=leftouter sessionInfo on processId, LogicalServerName
| extend
    FinalUser = iff(isnotempty(DirectUser), DirectUser, User),
    FinalDatabase = iff(isnotempty(DirectDatabase), DirectDatabase, Database),
    FinalHost = iff(isnotempty(DirectHost), DirectHost, SourceHost)
// Paso 5: Agrupar por servidor y ventanas de 1 minuto
| summarize 
    ErrorCount = count(),
    ErrorTypes = make_set(ErrorCategory),
    ErrorCodes = make_set(sqlerrcode),
    FirstError = min(EventProcessedUtcTime),
    LastError = max(EventProcessedUtcTime),
    SampleErrors = make_set(message, 3),  // Cambio: make_set en lugar de take_any
    User = any(FinalUser),
    Database = any(FinalDatabase),
    SourceHost = any(FinalHost)
    by LogicalServerName, backend_type, bin(EventProcessedUtcTime, 1m)
// Paso 6: Aplicar threshold (>15 errores por minuto)
| where ErrorCount > 15
// Paso 7: Formatear output para alerta
| extend AnomalyType = "Critical Error Spike"
| project 
    TimeGenerated = LastError,
    AnomalyType,
    ServerName = LogicalServerName,
    User = iff(isempty(User), "UNKNOWN", User),
    Database = iff(isempty(Database), "UNKNOWN", Database),
    SourceHost = iff(isempty(SourceHost), "UNKNOWN", SourceHost),
    BackendType = backend_type,
    ErrorCount,
    ErrorTypes = strcat_array(ErrorTypes, ", "),
    ErrorCodes = strcat_array(ErrorCodes, ", "),
    TimeWindow = strcat(format_datetime(FirstError, 'HH:mm:ss'), " - ", format_datetime(LastError, 'HH:mm:ss')),
    SampleErrors = strcat_array(SampleErrors, " ||| ")  // Ahora funciona porque make_set retorna array
| order by ErrorCount desc
```

### Configuración en Data Activator

**Paso a Paso:**

1. **Crear Reflex Item**:
   - Nombre: `Alert_ErrorSpike`

2. **Get Data**:
   - **Pega la query completa de arriba** ☝️

3. **Configurar Trigger**:
   - **Filter de Alta Prioridad**:
     ```
     ErrorTypes contains "Authentication Failure" 
     AND ErrorCount > 10
     AND SourceHost != "UNKNOWN"
     ```

4. **Alert Rule**:
   - **Condition**: `ErrorCount > 15`
   - **Evaluate**: Every **1 minute**
   - **Suppress for**: **5 minutes**
   - **Severity**: **Critical**

5. **Actions - Email**:
   ```yaml
   To: security-team@company.com, sre-team@company.com
   Subject: 🔴 CRÍTICO - Escalada de Errores PostgreSQL
   Body: |
     🔴 PICO DE ERRORES DETECTADO - POSIBLE ATAQUE O FALLO CRÍTICO
     
     📊 DETALLES:
     • Tipo: {AnomalyType}
     • Servidor: {ServerName}
     • Usuario: {User}
     • Base de Datos: {Database}
     • IP/Host Origen: {SourceHost}
     
     🔥 PICO DE ERRORES:
     • Total Errores: {ErrorCount} en 1 minuto
     • Categorías: {ErrorTypes}
     • Códigos SQL: {ErrorCodes}
     • Ventana: {TimeWindow}
     
     📋 EJEMPLOS DE ERRORES:
     {SampleErrors}
     
     ⚡ ACCIONES INMEDIATAS:
     
     🔒 SI ES BRUTE FORCE (Authentication Failure):
     1. Bloquear IP {SourceHost} en firewall/NSG
     2. Verificar intentos de autenticación del usuario {User}
     3. Revisar si la cuenta {User} está comprometida
     
     🔌 SI ES CONNECTION ERROR:
     1. Verificar límites de conexión: SHOW max_connections;
     2. Revisar conexiones activas: SELECT count(*) FROM pg_stat_activity;
     3. Escalar recursos si es necesario
     
     🚫 SI ES PERMISSION DENIED:
     1. Revisar intentos de escalada de privilegios
     2. Auditar permisos del usuario {User}
     3. Correlacionar con logs de aplicación
     
     🔗 [Ver Dashboard](link_to_dashboard) | [Incident Response](link)
   ```

6. **Actions - Teams**:
   ```yaml
   Channel: #security-alerts
   Message: |
     🔴 **CRÍTICO - Error Spike PostgreSQL**
     
     **Server**: {ServerName}
     **User**: {User}
     **Database**: {Database}
     **Origen**: {SourceHost}
     
     **Errores**: {ErrorCount} en 1 min
     **Tipos**: {ErrorTypes}
     **Códigos**: {ErrorCodes}
     
     ⚠️ **REVISAR INMEDIATAMENTE**
     
     [Ver Dashboard](link)
   ```

7. **Actions - Power Automate** (Acción Automática):
   ```yaml
   Flow: Auto_Block_BruteForce
   Condition: 
     ErrorTypes contains "Authentication Failure" 
     AND ErrorCount > 30 
     AND SourceHost != "UNKNOWN"
   
   Actions:
     1. Create P1 Security Incident in ServiceNow
     2. Add SourceHost to NSG Block List (requires IP, not hostname)
     3. Notify Security Operations Center
   
   Note: Auto-blocking only works if SourceHost is a valid IP address.
         If SourceHost is hostname/UNKNOWN, escalate to manual review.
   ```

### Test de la Alerta

**Objetivo**: Generar más de 15 errores en 1 minuto para disparar la alerta.

**Método**: Intentar conectarte con contraseña incorrecta 20 veces (genera errores de autenticación).

#### Opción 1: Desde Bash/Terminal (Linux/Mac/Windows Git Bash)

```bash
# Cambia 'yourserver', 'testuser' por tus valores reales
# La contraseña WRONG_PASSWORD es incorrecta a propósito para generar errores

for i in {1..20}; do
  psql "host=yourserver.postgres.database.azure.com user=testuser password=WRONG_PASSWORD dbname=postgres" -c "SELECT 1;" 2>/dev/null
  echo "Intento $i completado"
done
```

#### Opción 2: Desde PowerShell (Windows)

```powershell
# Cambia 'yourserver', 'testuser' por tus valores reales

1..20 | ForEach-Object {
  psql "host=yourserver.postgres.database.azure.com user=testuser password=WRONG_PASSWORD dbname=postgres" -c "SELECT 1;" 2>$null
  Write-Host "Intento $_ completado"
}
```

#### Opción 3: Manualmente desde psql (más lento)

```bash
# Ejecuta este comando 20 veces rápidamente (copia/pega múltiples veces)
psql "host=yourserver.postgres.database.azure.com user=testuser password=WRONG_PASSWORD dbname=postgres"
# Presiona Enter cuando pida password (o escribe cualquier cosa incorrecta)
```

**Lo que sucede:**
1. Cada intento de conexión con password incorrecta genera un error de autenticación
2. PostgreSQL registra el error en los logs (errorLevel = "FATAL", sqlerrcode = "28P01")
3. Los logs llegan a tu KQL Database
4. La alerta detecta >15 errores en 1 minuto y se dispara

**Verificación**: Deberías recibir la alerta CRÍTICA en **< 2 minutos** con:
- ErrorCount >= 20
- ErrorTypes = "Authentication Failure"
- User = "testuser" (el usuario que intentó autenticar)
- SourceHost = tu IP o hostname

---

## 📊 ALERTA BONUS: Desviación del Baseline (Actividad Inusual)

### ¿Qué Detecta?
- Actividad **3x superior** al promedio de los últimos 7 días
- Útil para detectar ataques DDoS o actividad anómala no categorizada

### Query Completa para Data Activator

```kql
// ============================================================================
// ALERTA BONUS: Baseline Deviation - Query Completa
// ============================================================================
// Copiar esta query COMPLETA en Data Activator
// Evaluación recomendada: Cada 5 minutos
// ============================================================================

// Paso 1: Calcular baseline (promedio últimos 7 días, excluyendo última hora)
let baseline = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime between (ago(7d) .. ago(1h))
| summarize AvgEventsPerMin = count() / (7*24*60) by LogicalServerName;

// Paso 2: Medir actividad actual (últimos 5 minutos)
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| summarize 
    CurrentEvents = count() / 5,
    TimeWindow = strcat(
        format_datetime(min(EventProcessedUtcTime), 'HH:mm:ss'), 
        " - ", 
        format_datetime(max(EventProcessedUtcTime), 'HH:mm:ss')
    )
    by LogicalServerName
// Paso 3: Comparar con baseline
| join kind=inner baseline on LogicalServerName
// Paso 4: Calcular desviación
| extend DeviationFactor = round(CurrentEvents / AvgEventsPerMin, 2)
// Paso 5: Aplicar threshold (>3x del promedio)
| where DeviationFactor > 3.0
// Paso 6: Formatear output para alerta
| extend AnomalyType = "Baseline Deviation"
| project 
    TimeGenerated = now(),
    AnomalyType,
    ServerName = LogicalServerName,
    CurrentEventsPerMin = round(CurrentEvents, 0),
    BaselineEventsPerMin = round(AvgEventsPerMin, 0),
    DeviationFactor,
    TimeWindow,
    Severity = case(
        DeviationFactor > 10, "Critical",
        DeviationFactor > 5, "High",
        "Medium"
    )
| order by DeviationFactor desc
```

### Configuración en Data Activator

1. **Crear Reflex Item**: `Alert_BaselineDeviation`
2. **Get Data**: Pega la query completa
3. **Alert Rule**:
   - **Condition**: `DeviationFactor > 3.0`
   - **Evaluate**: Every **5 minutes**
   - **Suppress for**: **15 minutes**
   - **Severity**: **Medium** (o **High** si `DeviationFactor > 5`)

4. **Actions - Email**:
   ```yaml
   Subject: 📈 ALERTA - Actividad Inusual en PostgreSQL
   Body: |
     📈 DESVIACIÓN DEL BASELINE DETECTADA
     
     • Servidor: {ServerName}
     • Actividad Actual: {CurrentEventsPerMin} eventos/min
     • Baseline (7d avg): {BaselineEventsPerMin} eventos/min
     • Desviación: {DeviationFactor}x el promedio
     • Severidad: {Severity}
     • Ventana: {TimeWindow}
     
     ⚡ ACCIONES:
     1. Revisar dashboard para identificar tipo de actividad
     2. Correlacionar con eventos de aplicación
     3. Si es ataque, aplicar rate limiting o bloqueo de IPs
     
     [Ver Dashboard](link)
   ```

---

## 🔧 Troubleshooting de Alertas

### Problema: "No retorna datos" al crear alerta

**Diagnóstico**:
```kql
// Test 1: Verificar que llegan datos en general
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| take 10

// Test 2: Verificar logs AUDIT
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| take 10

// Test 3: Verificar sessionInfo
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "connection authorized"
| take 10
```

**Soluciones**:
- Si Test 1 falla: Verificar ingesta de datos en KQL Database
- Si Test 2 falla: Verificar que pgaudit está instalado y configurado
- Si Test 3 falla: Verificar que llegan CONNECTION logs (puede ser problema de log level)

### Problema: "User/Database/SourceHost siempre sale UNKNOWN"

**Causa**: La correlación no encuentra sesiones activas en sessionInfo.

**Soluciones**:
1. Aumentar lookback de sessionInfo de 24h a 7d:
   ```kql
   let sessionInfo = 
   bronze_pssql_alllogs_nometrics
   | where EventProcessedUtcTime >= ago(7d)  // Cambiar de 24h a 7d
   ...
   ```

2. Verificar que pgaudit está instalado:
   ```sql
   SELECT * FROM pg_extension WHERE extname = 'pgaudit';
   ```

3. Verificar configuración:
   ```sql
   SHOW shared_preload_libraries;  -- Debe incluir 'pgaudit'
   SHOW pgaudit.log;  -- Debe incluir 'read, write, ddl'
   ```

### Problema: "Demasiadas alertas (fatiga)"

**Soluciones**:
1. **Aumentar thresholds**:
   - Data Exfiltration: De 15 a 25 SELECTs
   - Destructive Ops: De 5 a 10 operaciones
   - Error Spike: De 15 a 25 errores

2. **Aumentar supresión**: De 5min a 15min

3. **Añadir filtros exclusivos**:
   ```kql
   // Excluir service accounts conocidos
   | where User !in ("etl_service", "backup_admin", "monitoring_user")
   
   // Excluir bases de datos de test
   | where Database !in ("testdb", "staging_db")
   
   // Excluir IPs internas conocidas
   | where SourceHost !in ("10.0.1.100", "10.0.2.50")
   ```

### Problema: "Alertas llegan tarde"

**Soluciones**:
1. **Reducir intervalo de evaluación**: De 2min a 30 segundos

2. **Verificar latencia de ingesta**:
   ```kql
   bronze_pssql_alllogs_nometrics
   | where EventProcessedUtcTime >= ago(10m)
   | extend IngestionDelay = datetime_diff('second', ingestion_time(), EventProcessedUtcTime)
   | summarize AvgDelay = avg(IngestionDelay), MaxDelay = max(IngestionDelay)
   ```
   - Si AvgDelay > 60s: Problema de ingesta, revisar Event Hub/Stream Analytics

3. **Optimizar query** (si es muy lenta):
   - Reducir lookback de sessionInfo de 24h a 12h
   - Limitar `make_set()` a menos elementos: `make_set(TableName, 5)`

---

## ✅ Checklist Final de Implementación

Antes de dar por terminada la configuración, verifica:

- [ ] **Prerequisitos**:
  - [ ] pgaudit instalado en todas las bases de datos de usuario
  - [ ] shared_preload_libraries incluye 'pgaudit'
  - [ ] pgaudit.log configurado correctamente
  - [ ] Logs AUDIT llegan a KQL Database (verificado con query de test)

- [ ] **Alertas Configuradas**:
  - [ ] Alerta 1: Data Exfiltration (SelectCount > 15)
  - [ ] Alerta 2: Mass Destructive Ops (OperationCount > 5)
  - [ ] Alerta 3: Critical Error Spike (ErrorCount > 15)
  - [ ] (Opcional) Alerta Bonus: Baseline Deviation (DeviationFactor > 3)

- [ ] **Destinatarios Configurados**:
  - [ ] Emails de Security Team configurados
  - [ ] Emails de DBA Team configurados
  - [ ] Canal de Teams #security-alerts configurado
  - [ ] (Opcional) Power Automate flows configurados

- [ ] **Filtros de Exclusión** (para reducir falsos positivos):
  - [ ] Service accounts excluidos: etl_service, backup_admin, monitoring_user
  - [ ] Bases de datos de test excluidas: testdb, staging_db
  - [ ] (Opcional) IPs internas conocidas excluidas

- [ ] **Tests Ejecutados**:
  - [ ] Test Alerta 1: 20 SELECTs dispararon alerta ✅
  - [ ] Test Alerta 2: 6 DELETEs/TRUNCATEs dispararon alerta ✅
  - [ ] Test Alerta 3: 20 intentos de auth fallidos dispararon alerta ✅
  - [ ] Correlación User/Database/Host funciona correctamente ✅

- [ ] **Documentación**:
  - [ ] Playbook de respuesta a incidentes creado
  - [ ] Equipo entrenado en interpretar alertas
  - [ ] On-call rotation definida

---

## 📚 Resumen de Queries

| Alerta | Threshold | Ventana | Evaluación | Severidad | Archivo de Query |
|--------|-----------|---------|------------|-----------|------------------|
| **Data Exfiltration** | SelectCount > 15 | 5 min | Cada 1 min | Critical | Sección "ALERTA 1" arriba |
| **Mass Destructive Ops** | OperationCount > 5 | 2 min | Cada 2 min | High | Sección "ALERTA 2" arriba |
| **Critical Error Spike** | ErrorCount > 15 | 1 min | Cada 1 min | Critical | Sección "ALERTA 3" arriba |
| **Baseline Deviation** | DeviationFactor > 3.0 | 5 min | Cada 5 min | Medium | Sección "ALERTA BONUS" arriba |

---

**¡Sistema de Alertas Listo para Producción! 🚀**

Cada query es **independiente**, **completa** y **lista para copiar/pegar** directamente en Data Activator.
