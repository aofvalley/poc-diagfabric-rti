# 🚀 Checklist de Despliegue - PostgreSQL Anomaly Detection

**Versión**: 1.0 - Validado 20/11/2025  
**Tiempo estimado**: 30-45 minutos  
**Requisitos previos**: Acceso a Microsoft Fabric workspace, PostgreSQL Flexible Server configurado con Diagnostic Settings → Real-Time Hub

---

## ✅ FASE 1: Validación de Ingesta de Datos (5 min)

### 1.1 Verificar tabla KQL Database

```kql
// Ejecutar en KQL Query Editor
bronze_pssql_alllogs_nometrics
| summarize 
    LastEvent = max(EventProcessedUtcTime),
    FirstEvent = min(EventProcessedUtcTime),
    TotalEvents = count(),
    TimeRange = datetime_diff('day', max(EventProcessedUtcTime), min(EventProcessedUtcTime))
| extend 
    Status = iff(datetime_diff('minute', now(), LastEvent) < 5, "✅ Fresh data", "⚠️ Stale data"),
    LatencyMinutes = datetime_diff('minute', now(), LastEvent)
```

**Esperado**:
- ✅ `Status = "✅ Fresh data"`
- ✅ `LatencyMinutes < 5`
- ✅ `TotalEvents > 1000`

❌ **Si falla**: Verifica Event Stream y Diagnostic Settings en Azure Portal.

---

### 1.2 Validar logs de AUDIT

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| summarize 
    TotalLogs = count(),
    AuditLogs = countif(message contains "AUDIT:"),
    ErrorLogs = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    WarningLogs = countif(errorLevel == "WARNING")
    by LogicalServerName
| extend 
    AuditCoverage = round((todouble(AuditLogs) / TotalLogs) * 100, 2),
    ErrorRate = round((todouble(ErrorLogs) / TotalLogs) * 100, 2)
```

**Esperado**:
- ✅ `AuditCoverage > 10%` (mínimo 10% de logs deben ser AUDIT)
- ✅ `AuditLogs > 50`

❌ **Si falla**: Verificar que `pgaudit` está habilitado y configurado correctamente en PostgreSQL Server Parameters.

---

### 1.3 **TEST 1**: Validar extracción de campos AUDIT

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| extend 
    AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
    TableName = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,[A-Z ]+,([^,]*),", 1, message),
    QueryText = trim('"', extract(@",,,([^<]+)<", 1, message))
| take 20
| project EventProcessedUtcTime, backend_type, AuditOperation, AuditStatement, TableName, QueryText
```

**Esperado**:
- ✅ `AuditOperation`: valores como `READ`, `WRITE`, `DDL`, `MISC`
- ✅ `AuditStatement`: valores como `SELECT`, `UPDATE`, `DELETE`, `CREATE TABLE`, `BEGIN`, `COMMIT`
- ✅ `QueryText`: SQL completo extraído (ej: `SELECT pg_catalog.pg_is_in_recovery()`)
- ✅ `TableName`: puede estar vacío (normal para operaciones de sistema)

❌ **Si falla**: Los regex patterns están mal configurados. Revisar formato de logs AUDIT.

---

## ✅ FASE 2: Despliegue de Queries de Anomalías (10 min)

### 2.1 Ejecutar Anomalía 1: Data Exfiltration

Abrir **`kql-queries-PRODUCTION.kql`** → Copiar líneas **12-41** → Ejecutar

```kql
// ANOMALÍA 1: Extracción Masiva de Datos
// Detecta: >10 SELECTs en 1 minuto por sesión

let suspiciousDataAccess = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
...
```

**Esperado**:
- Si HAY anomalías: Tabla con columnas `TimeGenerated`, `AnomalyType`, `ServerName`, `QueryCount`, `SampleQueries`
- Si NO hay anomalías: Resultado vacío (esto es **NORMAL** y **BUENO**)

✅ **Validado**: Query ejecuta sin errores

---

### 2.2 Ejecutar Anomalía 2: Destructive Operations

Copiar líneas **48-80** de `kql-queries-PRODUCTION.kql` → Ejecutar

```kql
// ANOMALÍA 2: Operaciones Destructivas Masivas
// Detecta: >5 DELETE/UPDATE/TRUNCATE en 2 minutos

let destructiveOperations = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(10m)
...
```

**Esperado**:
- Si HAY anomalías: Tabla con `OperationCount`, `Operations`, `TablesAffected`
- Si NO hay anomalías: Resultado vacío

✅ **Validado**: Query ejecuta sin errores

---

### 2.3 Ejecutar Anomalía 3: Error Spike

Copiar líneas **87-125** de `kql-queries-PRODUCTION.kql` → Ejecutar

```kql
// ANOMALÍA 3: Escalada de Errores Críticos
// Detecta: >15 errores/min

let errorSpike = 
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
...
```

**Esperado**:
- Si HAY anomalías: Tabla con `ErrorCount`, `ErrorTypes`, `ErrorCodes`
- Si NO hay anomalías: Resultado vacío

✅ **Validado**: Query ejecuta sin errores

---

### 2.4 Ejecutar Dashboard Principal (UNION de las 3 anomalías)

Copiar líneas **131-137** → Ejecutar

```kql
// DASHBOARD PRINCIPAL: Todas las Anomalías
union
    (suspiciousDataAccess),
    (destructiveOperations),
    (errorSpike)
| order by TimeGenerated desc
| take 100;
```

**Esperado**:
- Resultado vacío SI no hay anomalías (estado normal)
- Si hay anomalías: Muestra TODAS las detectadas en las últimas 5-10 min

✅ **Validado**: Esta es la query principal para el dashboard

---

## ✅ FASE 3: Creación del Real-Time Dashboard (15 min)

### 3.1 Crear Dashboard en Fabric

1. **Fabric Portal** → Tu Workspace → **+ New** → **Real-Time Dashboard**
2. **Nombre**: `PostgreSQL Security Monitoring`
3. **Add data source**:
   - Type: **Kusto (KQL Database)**
   - Database: Seleccionar tu KQL Database
   - Click **Add**

✅ **Checkpoint**: Data source conectado correctamente

---

### 3.2 Crear Tile 1: Actividad General por Servidor

1. **New tile** → **Add query**
2. Copiar query de `kql-queries-PRODUCTION.kql` líneas **157-167**:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| summarize 
    TotalEvents = count(),
    Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    Warnings = countif(errorLevel == "WARNING"),
    AuditLogs = countif(message contains "AUDIT:")
    by LogicalServerName, bin(EventProcessedUtcTime, 2m)
| render timechart;
```

3. **Tile settings**:
   - Visual: **Time chart**
   - Auto-refresh: **2 minutes**
   - Title: `Actividad General por Servidor (última hora)`

✅ **Checkpoint**: Tile 1 creado y refrescando automáticamente

---

### 3.3 Crear Tile 2: Distribución de Operaciones AUDIT

1. **New tile** → **Add query**
2. Copiar líneas **173-182**:

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

3. **Tile settings**:
   - Visual: **Pie chart**
   - Auto-refresh: **5 minutes**
   - Title: `Distribución de Operaciones AUDIT (últimas 6h)`

✅ **Checkpoint**: Tile 2 mostrando distribución SELECT/UPDATE/DELETE/etc.

---

### 3.4 Crear Tile 3: Top 15 Tablas Más Accedidas

Copiar líneas **188-199** → Visual: **Table** → Auto-refresh: **5 min**

### 3.5 Crear Tile 4: Timeline de Operaciones por Tipo

Copiar líneas **205-219** → Visual: **Time chart** → Auto-refresh: **2 min**

### 3.6 Crear Tile 5: Errores por Categoría

Copiar líneas **225-240** → Visual: **Area chart** → Auto-refresh: **5 min**

### 3.7 Crear Tile 6: Actividad por Backend Type

Copiar líneas **246-254** → Visual: **Time chart** → Auto-refresh: **5 min**

---

### 3.8 **OPCIONAL**: Tiles adicionales (Tiles 7-8)

Ver **`DASHBOARD-SETUP-GUIDE.md`** página 15-20 para:
- **Tile 7**: Operaciones Destructivas Recientes (líneas 260-277)
- **Tile 8**: Top Códigos de Error (líneas 283-304)

---

### 3.9 Guardar y organizar layout

1. **Save dashboard** → Nombre: `PostgreSQL Security Monitoring`
2. **Organize tiles**: Arrastrar/redimensionar para layout óptimo
3. **Set refresh schedule**: General dashboard refresh → **1 minute**

✅ **FASE 3 COMPLETADA**: Dashboard operativo con 6-8 tiles

---

## ✅ FASE 4: Configuración de Alertas (Reflex) (10 min)

### 4.1 Crear Reflex Item

1. **Fabric Portal** → Tu Workspace → **+ New** → **Reflex**
2. **Nombre**: `PostgreSQL_Anomaly_Alerts`
3. **Get data** → **EventStream** (si disponible) o **Real-Time Dashboard**

✅ **Checkpoint**: Reflex item creado

---

### 4.2 Configurar Alerta 1: Data Exfiltration

Seguir **`REFLEX-ALERTS-CONFIG.md`** página 3-8:

1. **+ New alert** → Nombre: `Alert_DataExfiltration`
2. **Data source**: Query de Anomalía 1 (Data Exfiltration)
3. **Condition**:
   ```
   AnomalyType = "Potential Data Exfiltration"
   AND QueryCount > 15
   ```
4. **Action**: Email
   - **To**: `security-team@domain.com`
   - **Subject**: `🚨 ALERTA: Posible Data Exfiltration en PostgreSQL {{ServerName}}`
   - **Body**: Ver plantilla en página 6 de REFLEX-ALERTS-CONFIG.md
5. **Suppress**: 5 minutes
6. **Save & Activate**

✅ **Checkpoint**: Alerta 1 configurada y activa

---

### 4.3 Configurar Alerta 2: Mass Destructive Operations

1. **+ New alert** → Nombre: `Alert_MassDestructiveOps`
2. **Condition**: `AnomalyType = "Mass Destructive Operations" AND OperationCount > 5`
3. **Action**: Email + Microsoft Teams (opcional)
4. **Suppress**: 10 minutes

✅ **Checkpoint**: Alerta 2 configurada

---

### 4.4 Configurar Alerta 3: Error Spike

1. **+ New alert** → Nombre: `Alert_ErrorSpike`
2. **Condition**: `AnomalyType = "Critical Error Spike" AND ErrorCount > 20`
3. **Action**: Email + Teams notification
4. **Suppress**: 3 minutes

✅ **Checkpoint**: Alerta 3 configurada

---

## ✅ FASE 5: Testing y Validación (10 min)

### 5.1 Test de Anomalía 1: Simular Data Exfiltration

Ejecutar en PostgreSQL (psql o Azure Data Studio):

```sql
-- Generar 20 SELECTs rápidos para disparar anomalía
DO $$
BEGIN
  FOR i IN 1..20 LOOP
    PERFORM * FROM pg_catalog.pg_tables LIMIT 10;
    PERFORM pg_sleep(0.1);
  END LOOP;
END $$;
```

**Esperar 2-5 minutos** → Verificar:
- ✅ Dashboard muestra anomalía en Tile 1 o query principal
- ✅ Alerta de email recibida (si configurada)

---

### 5.2 Test de Anomalía 2: Simular Destructive Operations

```sql
-- Crear tabla temporal
CREATE TABLE test_anomaly (id INT, data TEXT);

-- Generar 10 DELETEs/UPDATEs
DO $$
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO test_anomaly VALUES (i, 'test');
    DELETE FROM test_anomaly WHERE id = i;
  END LOOP;
END $$;

-- Limpiar
DROP TABLE test_anomaly;
```

**Esperar 2-5 minutos** → Verificar anomalía detectada

---

### 5.3 Test de Anomalía 3: Simular Error Spike

```sql
-- Intentar acceder a tabla inexistente 20 veces
DO $$
BEGIN
  FOR i IN 1..20 LOOP
    BEGIN
      PERFORM * FROM tabla_que_no_existe;
    EXCEPTION WHEN OTHERS THEN
      -- Silenciar error para continuar loop
    END;
  END LOOP;
END $$;
```

**Esperar 2-5 minutos** → Verificar spike de errores en dashboard

---

### 5.4 Validar cobertura completa

Ejecutar query de validación final:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(30m)
| summarize 
    TotalEvents = count(),
    AuditEvents = countif(message contains "AUDIT:"),
    Errors = countif(errorLevel in ("ERROR", "FATAL", "PANIC")),
    Anomalies_Detected = 0  // Actualizar manualmente tras tests
| extend 
    AuditCoverage = round((todouble(AuditEvents) / TotalEvents) * 100, 2),
    ErrorRate = round((todouble(Errors) / TotalEvents) * 100, 2)
```

**Esperado**:
- ✅ `AuditCoverage > 15%` (tras tests de simulación)
- ✅ `Errors > 20` (tras test de Error Spike)
- ✅ `TotalEvents > 500` (actividad reciente)

---

## ✅ CHECKLIST FINAL DE DESPLIEGUE

### Fase 1: Validación de Datos
- [ ] Tabla `bronze_pssql_alllogs_nometrics` recibiendo datos (latencia < 5 min)
- [ ] Logs AUDIT presentes (cobertura > 10%)
- [ ] TEST 1 ejecutado exitosamente (extracción de Operation/Statement/QueryText)

### Fase 2: Queries de Anomalías
- [ ] Anomalía 1 (Data Exfiltration) ejecuta sin errores
- [ ] Anomalía 2 (Destructive Operations) ejecuta sin errores
- [ ] Anomalía 3 (Error Spike) ejecuta sin errores
- [ ] Dashboard principal (UNION) ejecuta sin errores

### Fase 3: Real-Time Dashboard
- [ ] Dashboard creado en Fabric con nombre `PostgreSQL Security Monitoring`
- [ ] Data source KQL Database conectado
- [ ] Tile 1: Actividad General (auto-refresh 2 min)
- [ ] Tile 2: Distribución AUDIT (auto-refresh 5 min)
- [ ] Tile 3: Top Tablas (auto-refresh 5 min)
- [ ] Tile 4: Timeline Operaciones (auto-refresh 2 min)
- [ ] Tile 5: Errores por Categoría (auto-refresh 5 min)
- [ ] Tile 6: Backend Type (auto-refresh 5 min)
- [ ] Layout organizado y guardado

### Fase 4: Alertas Reflex
- [ ] Reflex item `PostgreSQL_Anomaly_Alerts` creado
- [ ] Alerta 1: Data Exfiltration (condición: QueryCount > 15)
- [ ] Alerta 2: Destructive Ops (condición: OperationCount > 5)
- [ ] Alerta 3: Error Spike (condición: ErrorCount > 20)
- [ ] Email notifications configuradas
- [ ] Teams notifications configuradas (opcional)

### Fase 5: Testing
- [ ] Test Data Exfiltration ejecutado → Anomalía detectada
- [ ] Test Destructive Ops ejecutado → Anomalía detectada
- [ ] Test Error Spike ejecutado → Anomalía detectada
- [ ] Alertas de email recibidas correctamente
- [ ] Dashboard reflejando anomalías en tiempo real

---

## 📊 Métricas de Éxito

Después de 24-48 horas de operación, validar:

- ✅ **Latencia de ingesta**: < 5 minutos (media)
- ✅ **Cobertura AUDIT**: > 15% de logs totales
- ✅ **False positive rate**: < 5% (ajustar umbrales si es mayor)
- ✅ **Alert response time**: < 3 minutos (detección → notificación)
- ✅ **Dashboard uptime**: 99.9% (auto-refresh funcionando)

---

## 🔧 Troubleshooting Rápido

### Problema: No llegan datos a KQL Database
- Verificar **Diagnostic Settings** en PostgreSQL Flexible Server
- Revisar **Event Stream** status en Real-Time Hub
- Comprobar **table mapping** en Event Stream configuration

### Problema: Queries devuelven columnas vacías (QueryText, TableName)
- Ejecutar **TEST 1** de `kql-validation-queries.kql`
- Verificar formato de logs AUDIT: debe ser `AUDIT: SESSION,num,num,OP,STATEMENT,table,,,query,<not logged>`
- Revisar que `pgaudit.log` está configurado correctamente en Server Parameters

### Problema: Demasiadas alertas (false positives)
- Aumentar umbrales en queries de anomalías:
  - Data Exfiltration: `QueryCount > 15` (en lugar de 10)
  - Destructive Ops: `OperationCount > 10` (en lugar de 5)
  - Error Spike: `ErrorCount > 30` (en lugar de 15)
- Añadir filtros por `backend_type` para excluir conexiones de monitorización

### Problema: Dashboard no refresca automáticamente
- Verificar configuración de **auto-refresh** en cada tile (debe estar activado)
- Comprobar **data source connection** (debe estar activa)
- Revisar **browser cache** (hacer Ctrl+F5 para hard refresh)

---

## 📞 Soporte y Recursos

- **Documentación detallada**: Ver `DASHBOARD-SETUP-GUIDE.md` y `REFLEX-ALERTS-CONFIG.md`
- **Queries validadas**: `kql-queries-PRODUCTION.kql`
- **Testing**: `kql-validation-queries.kql`
- **Arquitectura**: `README.md`

---

**🎉 ¡DESPLIEGUE COMPLETADO!**

Tu solución de detección de anomalías PostgreSQL está ahora operativa y monitorizando en tiempo real.
