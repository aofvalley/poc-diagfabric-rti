# 🚀 Quick Start - Queries para Dashboard Real-Time

Este archivo contiene las queries más importantes ya listas para copiar y pegar directamente en tu dashboard de Microsoft Fabric Real-Time Intelligence.

---

## 📊 DASHBOARD 1: Anomalías en Tiempo Real

### Query Principal: Todas las Anomalías (Top 100)
```kql
// ============================================================================
// DASHBOARD PRINCIPAL - TODAS LAS ANOMALÍAS
// ============================================================================

let suspiciousDataAccess = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| where category == "PostgreSQLLogs"
| where message contains "AUDIT:"
| where message has_any ("SELECT", "COPY", "pg_dump")
| where backend_type == "client backend"
| extend 
    AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    DirectUser = extract(@"user=([^\s,]+)", 1, message),
    DirectDatabase = extract(@"database=([^\s,]+)", 1, message),
    DirectHost = extract(@"host=([^\s]+)", 1, message),
    TableName = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| where FinalUser != "azuresu"
| summarize 
    SelectCount = count(),
    FirstSeen = min(EventProcessedUtcTime),
    LastSeen = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, processId
| where SelectCount > 15
| extend 
    AnomalyType = "Data Exfiltration",
    Severity = case(SelectCount > 50, "CRITICAL", SelectCount > 30, "HIGH", "MEDIUM")
| project TimeGenerated = LastSeen, AnomalyType, Severity, ServerName = LogicalServerName, User, SelectCount;

let destructiveOperations = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
| where category == "PostgreSQLLogs"
| where message contains "AUDIT:"
| where message has_any ("DELETE", "UPDATE", "TRUNCATE", "DROP")
| where backend_type == "client backend"
| extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| summarize 
    OperationCount = count(),
    FirstOp = min(EventProcessedUtcTime),
    LastOp = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, bin(EventProcessedUtcTime, 2m)
| where OperationCount > 5
| extend 
    AnomalyType = "Destructive Operations",
    Severity = case(OperationCount > 20, "CRITICAL", OperationCount > 10, "HIGH", "MEDIUM")
| project TimeGenerated = LastOp, AnomalyType, Severity, ServerName = LogicalServerName, User, OperationCount;

let errorSpike = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(15m)
| where category == "PostgreSQLLogs"
| where errorLevel in ("ERROR", "FATAL", "PANIC")
| extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| summarize 
    ErrorCount = count(),
    FirstError = min(EventProcessedUtcTime),
    LastError = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, bin(EventProcessedUtcTime, 1m)
| where ErrorCount > 3
| extend 
    AnomalyType = "Error Spike",
    Severity = case(ErrorCount > 15, "CRITICAL", ErrorCount > 8, "HIGH", "MEDIUM")
| project TimeGenerated = LastError, AnomalyType, Severity, ServerName = LogicalServerName, User, ErrorCount;

let privilegeEscalation = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
| where category == "PostgreSQLLogs"
| where message has_any ("GRANT", "REVOKE", "ALTER ROLE", "CREATE ROLE")
| extend DirectUser = extract(@"user=([^\s,]+)", 1, message)
| join kind=leftouter (
    bronze_pssql_alllogs_nometrics
    | where EventProcessedUtcTime >= ago(24h)
    | where message contains "connection authorized"
    | extend UserName = extract(@"user=([^\s,]+)", 1, message)
    | where isnotempty(UserName)
    | summarize User = any(UserName) by processId, LogicalServerName
) on processId, LogicalServerName
| extend FinalUser = iff(isnotempty(DirectUser), DirectUser, iff(isnotempty(User), User, "UNKNOWN"))
| where FinalUser != "azuresu"
| summarize 
    PrivilegeOpsCount = count(),
    FirstOp = min(EventProcessedUtcTime),
    LastOp = max(EventProcessedUtcTime),
    User = any(FinalUser)
    by LogicalServerName, bin(EventProcessedUtcTime, 5m)
| where PrivilegeOpsCount > 3
| extend 
    AnomalyType = "Privilege Escalation",
    Severity = case(PrivilegeOpsCount > 10, "CRITICAL", PrivilegeOpsCount > 5, "HIGH", "MEDIUM")
| project TimeGenerated = LastOp, AnomalyType, Severity, ServerName = LogicalServerName, User, PrivilegeOpsCount;

union (suspiciousDataAccess), (destructiveOperations), (errorSpike), (privilegeEscalation)
| order by TimeGenerated desc
| take 100;
```

**Config Dashboard**:
- **Tipo**: Tabla
- **Auto-refresh**: 1 minuto
- **Columnas visibles**: TimeGenerated, AnomalyType, Severity, ServerName, User

---

## 📈 DASHBOARD 2: Métricas en Tiempo Real

### Tile 1: Actividad General por Servidor (1h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where isnotempty(LogicalServerName)
| summarize 
    TotalEvents = count(),
    Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    Warnings = countif(errorLevel == "WARNING"),
    AuditLogs = countif(message contains "AUDIT:")
    by LogicalServerName, bin(EventProcessedUtcTime, 2m)
| render timechart
```
**Config**: Timechart | Auto-refresh: 2 min

---

### Tile 2: Distribución de Operaciones AUDIT (6h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(6h)
| where message contains "AUDIT:"
| extend AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message)
| where isnotempty(AuditStatement)
| summarize Count = count() by AuditStatement
| order by Count desc
| take 10
| render piechart;
```
**Config**: Piechart | Auto-refresh: 5 min

---

### Tile 3: Timeline de Operaciones por Tipo (1h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| extend OperationType = case(
    message contains ",READ," or message contains ",SELECT,", "SELECT",
    message contains ",WRITE," or message contains ",UPDATE,", "WRITE",
    message contains ",DELETE,", "DELETE",
    message contains ",INSERT,", "INSERT",
    message contains ",DDL,", "DDL",
    "OTHER"
)
| summarize Count = count() by OperationType, bin(EventProcessedUtcTime, 2m)
| render timechart;
```
**Config**: Timechart | Auto-refresh: 2 min

---

### Tile 4: TOP 10 Usuarios por Actividad (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| extend UserName = extract(@"user=([^\s,]+)", 1, message)
| where isnotempty(UserName)
| summarize 
    TotalActivity = count(),
    AuditLogs = countif(message contains "AUDIT:"),
    Connections = countif(message contains "connection authorized"),
    Errors = countif(errorLevel in ("ERROR", "FATAL")),
    LastActivity = max(EventProcessedUtcTime)
    by UserName
| top 10 by TotalActivity desc
| project UserName, TotalActivity, AuditLogs, Connections, Errors, LastActivity;
```
**Config**: Tabla | Auto-refresh: 10 min

---

### Tile 5: Errores por Categoría (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where errorLevel in ("ERROR", "FATAL", "PANIC")
| extend ErrorCategory = case(
    message contains "authentication", "Auth Errors",
    message contains "permission", "Permission Errors",
    message contains "connection", "Connection Errors",
    sqlerrcode startswith "28", "Auth Errors",
    sqlerrcode startswith "42", "Permission Errors",
    sqlerrcode startswith "08", "Connection Errors",
    sqlerrcode startswith "53", "Resource Errors",
    "Other Errors"
)
| summarize Count = count() by ErrorCategory, bin(EventProcessedUtcTime, 30m)
| render areachart;
```
**Config**: Areachart | Auto-refresh: 5 min

---

### Tile 6: Fallos de Autenticación (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| where message contains "authentication failed" 
    or message contains "password authentication failed"
    or sqlerrcode == "28P01"
| extend 
    UserName = extract(@"user=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message)
| summarize 
    FailedAttempts = count(),
    FirstAttempt = min(EventProcessedUtcTime),
    LastAttempt = max(EventProcessedUtcTime)
    by UserName, ClientHost
| extend ThreatLevel = case(
    FailedAttempts > 20, "CRITICAL",
    FailedAttempts > 10, "HIGH",
    FailedAttempts > 5, "MEDIUM",
    "LOW"
)
| order by FailedAttempts desc
| take 20
| project UserName, ClientHost, FailedAttempts, ThreatLevel, FirstAttempt, LastAttempt;
```
**Config**: Tabla | Auto-refresh: 10 min

---

### Tile 7: TOP Hosts por Conexiones (24h)
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(24h)
| extend 
    ClientHost = extract(@"host=([^\s]+)", 1, message),
    UserName = extract(@"user=([^\s,]+)", 1, message)
| where isnotempty(ClientHost)
| summarize 
    TotalConnections = count(),
    UniqueUsers = dcount(UserName),
    Errors = countif(errorLevel in ("ERROR", "FATAL")),
    LastSeen = max(EventProcessedUtcTime)
    by ClientHost
| extend 
    ErrorRate = round((todouble(Errors) / TotalConnections) * 100, 2),
    Riesgo = case(
        round((todouble(Errors) / TotalConnections) * 100, 2) > 20, "HIGH",
        round((todouble(Errors) / TotalConnections) * 100, 2) > 5, "MEDIUM",
        "LOW"
    )
| top 10 by TotalConnections desc
| project ClientHost, TotalConnections, UniqueUsers, Errors, ErrorRate, Riesgo, LastSeen;
```
**Config**: Tabla | Auto-refresh: 10 min

---

## 🎯 DASHBOARD 3: Anomalías ML (Baseline Deviation)

### Query ML: Desviación del Baseline
```kql
postgres_activity_metrics
| where Timestamp >= ago(7d)
| where isnotempty(ServerName)
| make-series ActivitySeries = sum(ActivityCount) default=0 
    on Timestamp step 5m 
    by ServerName
| extend (anomalies, score, baseline) = 
    series_decompose_anomalies(ActivitySeries, 1.5, -1, 'linefit')
| mv-expand Timestamp to typeof(datetime), 
    ActivitySeries to typeof(long), 
    anomalies to typeof(int), 
    score to typeof(double), 
    baseline to typeof(double)
| where anomalies != 0
| where Timestamp >= ago(1h)
| extend 
    AnomalyDirection = iff(anomalies > 0, "📈 Above Normal", "📉 Below Normal"),
    Severity = case(
        abs(score) > 3.0, "CRITICAL",
        abs(score) > 2.0, "HIGH",
        "MEDIUM"
    )
| project 
    Timestamp,
    ServerName,
    AnomalyDirection,
    Severity,
    ActivityCount = ActivitySeries,
    ExpectedBaseline = round(baseline, 0),
    DeviationScore = round(score, 2)
| order by abs(DeviationScore) desc
| take 20;
```
**Config**: Tabla | Auto-refresh: 5 min

---

## 🔍 DASHBOARD 4: Monitoreo de Salud del Sistema

### Query: Frescura de Datos
```kql
bronze_pssql_alllogs_nometrics
| summarize 
    LastEvent = max(EventProcessedUtcTime),
    TotalEvents = count()
| extend 
    Status = iff(datetime_diff('minute', now(), LastEvent) < 5, "✅ Fresh", "⚠️ Stale"),
    LatencyMinutes = datetime_diff('minute', now(), LastEvent)
| project Status, LatencyMinutes, LastEvent, TotalEvents;
```
**Config**: Card/KPI | Auto-refresh: 1 min

---

### Query: Cobertura de AUDIT Logs
```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| summarize 
    TotalLogs = count(),
    AuditLogs = countif(message contains "AUDIT:"),
    ErrorLogs = countif(errorLevel in ("ERROR", "FATAL", "PANIC"))
    by LogicalServerName
| extend 
    AuditCoverage = round((todouble(AuditLogs) / TotalLogs) * 100, 2),
    ErrorRate = round((todouble(ErrorLogs) / TotalLogs) * 100, 2)
| project LogicalServerName, TotalLogs, AuditCoverage, ErrorRate;
```
**Config**: Tabla | Auto-refresh: 5 min

---

### Query: Estado de Tablas de Métricas
```kql
postgres_activity_metrics
| summarize 
    LastUpdate = max(Timestamp),
    TotalRecords = count(),
    AvgActivity = avg(ActivityCount),
    MaxErrors = max(Errors)
    by ServerName
| extend 
    Status = iff(datetime_diff('minute', now(), LastUpdate) < 10, "✅ Healthy", "⚠️ Delayed"),
    DelayMinutes = datetime_diff('minute', now(), LastUpdate)
| project ServerName, Status, DelayMinutes, LastUpdate, TotalRecords, AvgActivity, MaxErrors;
```
**Config**: Tabla | Auto-refresh: 5 min

---

## 📋 Checklist de Implementación

### ✅ Paso 1: Crear Infraestructura (una sola vez)
Ejecuta todas las queries de la **SECCIÓN 1** del archivo `UNIFIED-ANOMALY-DETECTION.kql`:
- [ ] Crear tabla `postgres_activity_metrics`
- [ ] Crear función `postgres_activity_metrics_transform()`
- [ ] Configurar Update Policy
- [ ] Cargar datos históricos (30 días)
- [ ] Crear tabla `postgres_error_metrics`
- [ ] Crear tabla `postgres_user_metrics`

### ✅ Paso 2: Configurar Dashboard 1 - Anomalías
- [ ] Crear nuevo Dashboard "PostgreSQL - Anomalías en Tiempo Real"
- [ ] Pegar query principal (Dashboard 1)
- [ ] Configurar auto-refresh a 1 minuto
- [ ] Agregar filtros por ServerName y Severity

### ✅ Paso 3: Configurar Dashboard 2 - Métricas
- [ ] Crear nuevo Dashboard "PostgreSQL - Métricas Operacionales"
- [ ] Agregar Tile 1 (Actividad General) - Timechart
- [ ] Agregar Tile 2 (Distribución AUDIT) - Piechart
- [ ] Agregar Tile 3 (Timeline Operaciones) - Timechart
- [ ] Agregar Tile 4 (TOP Usuarios) - Tabla
- [ ] Agregar Tile 5 (Errores Categoría) - Areachart
- [ ] Agregar Tile 6 (Fallos Auth) - Tabla
- [ ] Agregar Tile 7 (TOP Hosts) - Tabla

### ✅ Paso 4: Configurar Dashboard 3 - ML
- [ ] Configurar Anomaly Detector en Fabric UI (ver README-UNIFIED-SETUP.md)
- [ ] Crear Dashboard "PostgreSQL - ML Anomalies"
- [ ] Pegar query ML (Dashboard 3)
- [ ] Configurar auto-refresh a 5 minutos

### ✅ Paso 5: Configurar Dashboard 4 - Salud
- [ ] Crear Dashboard "PostgreSQL - System Health"
- [ ] Agregar query Frescura de Datos (KPI)
- [ ] Agregar query Cobertura AUDIT (Tabla)
- [ ] Agregar query Estado Métricas (Tabla)

### ✅ Paso 6: Configurar Alertas
- [ ] Crear alerta para Data Exfiltration (Severity = CRITICAL)
- [ ] Crear alerta para Destructive Operations (Severity >= HIGH)
- [ ] Crear alerta para Privilege Escalation (Severity >= HIGH)
- [ ] Crear alerta para ML Anomalies (DeviationScore > 3.0)

---

## 🎨 Personalización de Dashboards

### Colores Recomendados por Severidad
- **CRITICAL**: 🔴 Rojo (`#DC3545`)
- **HIGH**: 🟠 Naranja (`#FD7E14`)
- **MEDIUM**: 🟡 Amarillo (`#FFC107`)
- **LOW**: 🟢 Verde (`#28A745`)

### Iconos Recomendados
- **Data Exfiltration**: 📥 (download)
- **Destructive Operations**: 💣 (bomb)
- **Error Spike**: ⚡ (lightning)
- **Privilege Escalation**: 🔐 (lock)
- **ML Anomaly**: 🤖 (robot)

### Layout Sugerido
```
Dashboard 1: Anomalías
┌─────────────────────────┐
│  Tabla Principal (100%) │
│  [TimeGenerated | Type  │
│   | Severity | Server]  │
└─────────────────────────┘

Dashboard 2: Métricas
┌──────────┬──────────┐
│ Tile 1   │ Tile 2   │
│ (50%)    │ (50%)    │
├──────────┴──────────┤
│ Tile 3 (100%)       │
├──────────┬──────────┤
│ Tile 4   │ Tile 5   │
│ (50%)    │ (50%)    │
├──────────┼──────────┤
│ Tile 6   │ Tile 7   │
│ (50%)    │ (50%)    │
└──────────┴──────────┘

Dashboard 3: ML
┌─────────────────────────┐
│  Tabla ML (100%)        │
│  [Timestamp | Direction│
│   | Score | Baseline]   │
└─────────────────────────┘

Dashboard 4: Salud
┌─────┬─────┬─────┬─────┐
│ KPI │ KPI │ KPI │ KPI │
│ (25%)     (25%)   (25%)│
├─────────────────────────┤
│ Tabla Cobertura (100%)  │
├─────────────────────────┤
│ Tabla Estado (100%)     │
└─────────────────────────┘
```

---

**Versión**: 1.0 Quick Start  
**Última actualización**: 2026-01-25
