# 🎯 PostgreSQL Anomaly Detection - Setup Unificado

Este documento describe el archivo unificado `UNIFIED-ANOMALY-DETECTION.kql` que consolida todo el sistema de detección de anomalías para PostgreSQL en Microsoft Fabric Real-Time Intelligence.

## 📋 Contenido del Archivo Unificado

### **SECCIÓN 1: Setup - Creación de Infraestructura**

#### 1.1-1.2: Tabla Principal de Métricas de Actividad
```kql
.create table postgres_activity_metrics (...)
.create-or-alter function postgres_activity_metrics_transform() {...}
```
**Propósito**: Tabla de métricas agregadas en ventanas de 5 minutos con dimensiones temporales (hora del día, día de la semana) para ML.

**Columnas clave**:
- `ActivityCount`, `AuditLogs`, `Errors`, `Connections`
- `UniqueUsers`: Detecta cardinalidad anormal de usuarios
- `SelectOps`, `WriteOps`, `DDLOps`: Desglose de operaciones
- `PrivilegeOps`: GRANT/REVOKE para detectar escalada de privilegios
- `HourOfDay`, `DayOfWeek`: Patrones temporales

#### 1.3-1.4: Update Policy y Carga Histórica
```kql
.alter table postgres_activity_metrics policy update @'[...]'
.set-or-append postgres_activity_metrics <| ...
```
**Propósito**: Pipeline automático que actualiza la tabla en tiempo real + carga de 30 días de histórico para entrenar el modelo de ML.

#### 1.5-1.6: Tablas Auxiliares
- **`postgres_error_metrics`**: Métricas de errores por servidor (ventanas de 1 minuto)
- **`postgres_user_metrics`**: Actividad por usuario con correlación de sesiones (ventanas de 1 hora)

---

### **SECCIÓN 2: Queries de Anomalías en Tiempo Real**

#### 2.1 Extracción Masiva de Datos (Data Exfiltration)
**Threshold**: >15 SELECTs en 5 minutos  
**Detecta**: Queries masivas, COPY, pg_dump  
**Severidad**: MEDIUM (15-30), HIGH (30-50), CRITICAL (>50)

#### 2.2 Operaciones Destructivas Masivas
**Threshold**: >5 operaciones destructivas en 2 minutos  
**Detecta**: DELETE, UPDATE, TRUNCATE, DROP TABLE/DATABASE  
**Severidad**: MEDIUM (5-10), HIGH (10-20), CRITICAL (>20)

#### 2.3 Escalada de Errores Críticos
**Threshold**: >3 errores en 1 minuto  
**Detecta**: ERROR, FATAL, PANIC, códigos SQL de error  
**Categorías**: Authentication, Permission, Connection, Resource, Other  
**Severidad**: MEDIUM (3-8), HIGH (8-15), CRITICAL (>15)

#### 2.4 Escalada de Privilegios
**Threshold**: >3 operaciones de privilegios en 5 minutos  
**Detecta**: GRANT, REVOKE, ALTER ROLE, CREATE/DROP ROLE  
**Severidad**: MEDIUM (3-5), HIGH (5-10), CRITICAL (>10)

#### 2.5 Reconocimiento Cross-Schema (Lateral Movement)
**Threshold**: >4 schemas diferentes accedidos en 10 minutos  
**Detecta**: Acceso a múltiples schemas (movimiento lateral)  
**Severidad**: MEDIUM (4-5), HIGH (5-8), CRITICAL (>8)

#### 2.6 Enumeración de Schema de Sistema (Deep Scan)
**Threshold**: >10 queries a tablas de sistema en 5 minutos  
**Detecta**: pg_catalog, information_schema, pg_tables, pg_class, etc.  
**Severidad**: MEDIUM (10-15), HIGH (15-30), CRITICAL (>30)  
**RiskLevel**: 🔴 HIGH (>5 tablas), 🟠 MEDIUM

#### 2.7 ML Anomaly Detection - Desviación de Baseline
**Algoritmo**: `series_decompose_anomalies()` con sensibilidad 1.5  
**Lookback**: 7 días para establecer baseline normal  
**Detección**: Anomalías altas (📈) o bajas (📉)  
**Severidad**: MEDIUM (score 1.5-2.0), HIGH (2.0-3.0), CRITICAL (>3.0)

---

### **SECCIÓN 3: Dashboard Principal**

**Query unificada** que combina todas las anomalías en una sola vista:
```kql
union
    (suspiciousDataAccess),
    (destructiveOperations),
    (errorSpike),
    (privilegeEscalation),
    (crossSchemaRecon),
    (deepSchemaEnum)
| order by TimeGenerated desc
| take 100;
```

**Vista**: Top 100 anomalías más recientes de todos los tipos, ordenadas por timestamp.

---

### **SECCIÓN 4: Dashboards de Métricas Operacionales**

#### 4.1 Actividad General por Servidor (1h)
Gráfico de líneas con total de eventos, errores, warnings y audit logs por servidor.

#### 4.2 Distribución de Operaciones AUDIT (6h)
Gráfico circular con tipos de operaciones: SELECT, INSERT, UPDATE, DELETE, DDL, etc.

#### 4.3 Top 15 Tablas Más Accedidas (6h)
Lista de tablas con mayor número de accesos, tipos de objeto y último acceso.

#### 4.4 Timeline de Operaciones AUDIT (1h)
Gráfico de líneas por tipo de operación (SELECT, WRITE, DELETE, INSERT, DDL, MISC).

#### 4.5 Errores por Categoría (24h)
Gráfico de área con categorías: Auth, Permission, Connection, Resource, Other.

#### 4.6 Actividad por Backend Type (1h)
Gráfico de líneas comparando `client backend` vs `autovacuum`, `checkpointer`, etc.

#### 4.7 TOP 10 Usuarios por Actividad (24h)
Tabla con: TotalActivity, AuditLogs, Connections, Errors, Databases, LastActivity.

#### 4.8 TOP 10 Hosts/IPs por Conexiones (24h)
Tabla con: TotalConnections, UniqueUsers, ErrorRate, Riesgo (HIGH/MEDIUM/LOW).

#### 4.9 Heat Map User + Database (24h)
Matriz de actividad por combinación usuario-database (ActivityCount > 10).

#### 4.10 Fallos de Autenticación (24h)
Tabla con intentos fallidos por usuario/host, ThreatLevel (CRITICAL/HIGH/MEDIUM/LOW).

#### 4.11 Top Códigos de Error (24h)
Top 15 códigos SQL de error con descripción y categoría.

---

### **SECCIÓN 5: Queries de Monitoreo y Validación**

#### 5.1 Verificar Estado de las Tablas de Métricas
```kql
postgres_activity_metrics | order by Timestamp desc | take 20;
```
Confirma que las tablas se están actualizando correctamente.

#### 5.2 Verificar Frescura de Datos
Muestra latencia de los datos (✅ Fresh < 5min, ⚠️ Stale > 5min).

#### 5.3 Cobertura de AUDIT Logs
Porcentaje de logs que son AUDIT vs total, por servidor.

#### 5.4 Distribución de Backend Types
Count de eventos por tipo de backend (validación de filtros).

---

### **SECCIÓN 6: Troubleshooting & Mantenimiento**

#### Ver Update Policies activas
```kql
.show table postgres_activity_metrics policy update
```

#### Ver errores de ingesta
```kql
.show ingestion failures
| where Table in ("postgres_activity_metrics", "postgres_error_metrics", "postgres_user_metrics")
```

#### Forzar refresh manual (comentado por defecto)
```kql
// .refresh table postgres_activity_metrics
```

---

### **SECCIÓN 7: Cleanup (Opcional)**

Comandos para eliminar todas las tablas y funciones (SOLO para reiniciar desde cero):
```kql
// .drop table postgres_activity_metrics ifexists
// .drop table postgres_error_metrics ifexists
// .drop table postgres_user_metrics ifexists
// ...
```

---

## 🚀 Guía de Implementación

### Paso 1: Crear las Tablas de Métricas
Ejecuta las queries de la **SECCIÓN 1** (1.1 a 1.6) en orden:

1. Crear `postgres_activity_metrics`
2. Crear función `postgres_activity_metrics_transform()`
3. Configurar Update Policy
4. Cargar datos históricos (30 días)
5. Repetir para `postgres_error_metrics`
6. Repetir para `postgres_user_metrics`

**Tiempo estimado**: 5-10 minutos (dependiendo del volumen de datos históricos).

---

### Paso 2: Verificar que las Tablas se Actualizan
Ejecuta las queries de la **SECCIÓN 5.1**:
```kql
postgres_activity_metrics | order by Timestamp desc | take 20;
```

**Esperado**: Deberías ver registros con timestamps recientes (últimos 5-10 minutos).

---

### Paso 3: Configurar Anomaly Detector en Fabric UI

> **⚠️ IMPORTANTE**: Para que la anomalía ML (2.7) funcione, debes configurar el detector de anomalías en Fabric UI.

1. Abre tu **KQL Database** en Fabric Real-Time Intelligence
2. Click en la tabla `postgres_activity_metrics`
3. Click en **"Anomaly detection"** (botón superior)
4. Configurar:
   - **Table**: `postgres_activity_metrics`
   - **Timestamp column**: `Timestamp`
   - **Value to watch**: `ActivityCount`
   - **Group by dimension**: `ServerName`
   - **Sensitivity**: `Medium` (ajustar después según resultados)
   - **Lookback period**: `7 days`
5. Click **"Create"**
6. Espera **5-10 minutos** para que entrene el modelo

---

### Paso 4: Crear Dashboards en Fabric

#### Dashboard 1: **Anomalías en Tiempo Real**
- Pin la query de **SECCIÓN 3** (Dashboard Principal)
- Visualización: **Tabla** con columnas: TimeGenerated, AnomalyType, Severity, ServerName, User
- Refresh: **Auto-refresh cada 1 minuto**

#### Dashboard 2: **Métricas Operacionales**
Crea tiles individuales con las queries de **SECCIÓN 4**:

| Tile | Query | Tipo de Gráfico | Refresh |
|------|-------|-----------------|---------|
| 4.1 | Actividad General | Timechart | 2min |
| 4.2 | Distribución AUDIT | Piechart | 5min |
| 4.3 | Top Tablas | Tabla | 5min |
| 4.4 | Timeline AUDIT | Timechart | 2min |
| 4.5 | Errores Categoría | Areachart | 5min |
| 4.6 | Backend Type | Timechart | 2min |
| 4.7 | TOP Users | Tabla | 10min |
| 4.8 | TOP Hosts | Tabla | 10min |
| 4.9 | Heat Map User+DB | Tabla | 10min |
| 4.10 | Fallos Auth | Tabla | 10min |
| 4.11 | Top Códigos Error | Tabla | 10min |

---

### Paso 5: Configurar Alertas

Para cada anomalía crítica, configura alertas en Fabric:

#### Alerta 1: Data Exfiltration
- **Query**: `suspiciousDataAccess` (SECCIÓN 2.1)
- **Condición**: `Severity == "CRITICAL"`
- **Frecuencia**: Cada 5 minutos
- **Acción**: Email + Teams

#### Alerta 2: Operaciones Destructivas
- **Query**: `destructiveOperations` (SECCIÓN 2.2)
- **Condición**: `Severity in ("CRITICAL", "HIGH")`
- **Frecuencia**: Cada 2 minutos
- **Acción**: Email + Teams + SMS

#### Alerta 3: Escalada de Privilegios
- **Query**: `privilegeEscalation` (SECCIÓN 2.4)
- **Condición**: `Severity in ("CRITICAL", "HIGH")`
- **Frecuencia**: Cada 5 minutos
- **Acción**: Email + Teams + Incident in Sentinel

#### Alerta 4: ML Anomaly Detection
- **Query**: `mlAnomalyDetection` (SECCIÓN 2.7)
- **Condición**: `Severity == "CRITICAL" and abs(DeviationScore) > 3.0`
- **Frecuencia**: Cada 5 minutos
- **Acción**: Email + Teams

---

## 📊 Métricas Clave para Monitoreo

### Métricas de Seguridad
1. **Anomalías detectadas por tipo** (últimas 24h)
2. **Severidad de anomalías** (CRITICAL/HIGH/MEDIUM)
3. **Usuarios con comportamiento anómalo** (últimas 24h)
4. **Hosts/IPs sospechosas** (ErrorRate > 10%)
5. **Fallos de autenticación** (FailedAttempts > 10)

### Métricas Operacionales
1. **Latencia de datos** (debe ser < 5 minutos)
2. **Cobertura de AUDIT logs** (debe ser > 80%)
3. **Tasa de errores** (ErrorRate por servidor)
4. **Actividad por hora del día** (baseline para ML)
5. **Backend Types distribution** (validar filtros)

### Métricas de ML
1. **Desviación del baseline** (DeviationScore)
2. **Anomalías altas vs bajas** (📈 vs 📉)
3. **Precisión del modelo** (false positives)
4. **Baseline ajustado** (ExpectedBaseline vs ActivityCount)

---

## 🛠️ Troubleshooting

### Problema 1: Las tablas de métricas no se actualizan
**Solución**:
1. Verificar que la Update Policy está activa:
   ```kql
   .show table postgres_activity_metrics policy update
   ```
2. Ver errores de ingesta:
   ```kql
   .show ingestion failures | where Table == "postgres_activity_metrics"
   ```
3. Forzar refresh manual:
   ```kql
   .refresh table postgres_activity_metrics
   ```

### Problema 2: ML Anomaly Detection no retorna resultados
**Causas posibles**:
- El modelo aún no ha entrenado (espera 5-10 minutos después de crear el detector)
- No hay suficientes datos históricos (mínimo 7 días)
- La sensibilidad es demasiado alta (ajusta a 1.0 o 1.2)

**Solución**:
```kql
// Verificar que hay datos históricos
postgres_activity_metrics
| where Timestamp >= ago(7d)
| summarize count() by ServerName
```

### Problema 3: Demasiados falsos positivos
**Solución**: Ajustar thresholds en las queries de anomalías:
- `suspiciousDataAccess`: Aumentar de 15 a 25 SELECTs
- `destructiveOperations`: Aumentar de 5 a 10 operaciones
- `errorSpike`: Aumentar de 3 a 5 errores
- ML Anomaly: Reducir sensibilidad de 1.5 a 1.8

### Problema 4: Correlación User/Database/Host no funciona
**Causas posibles**:
- Los logs de conexión no están llegando
- El `processId` no coincide entre logs AUDIT y CONNECTION

**Solución**:
```kql
// Verificar logs de conexión
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "connection authorized"
| take 10
```

---

## 📚 Diferencias con Archivos Previos

### Cambios respecto a `kql-queries-PRODUCTION.kql`
- ✅ **Agregado**: Secciones de Setup completas (tablas, funciones, policies)
- ✅ **Agregado**: Severidad dinámica en todas las anomalías
- ✅ **Mejorado**: Correlación inline en lugar de `let sessionInfo` global
- ✅ **Organizado**: Estructura modular por secciones numeradas

### Cambios respecto a `ANOMALY-DETECTION-SETUP.kql`
- ✅ **Agregado**: Todas las queries de anomalías RTI (7 tipos)
- ✅ **Agregado**: Dashboards operacionales completos (11 tiles)
- ✅ **Agregado**: Queries de validación y troubleshooting
- ✅ **Mejorado**: Documentación inline en cada sección

---

## 🎯 Próximos Pasos Recomendados

1. **Optimización de Thresholds**: Después de 1 semana, ajustar los thresholds según tu baseline real
2. **Tuning del ML**: Ajustar la sensibilidad del modelo de anomalías (1.0 - 2.0)
3. **Alertas Avanzadas**: Integrar con Microsoft Sentinel para SOAR
4. **Dashboards Custom**: Crear vistas específicas por equipo (Security, DBA, DevOps)
5. **Retención de Datos**: Configurar políticas de retención para las tablas de métricas (por defecto 90 días)

---

## 📧 Soporte

Para preguntas o problemas:
1. Revisar la **SECCIÓN 6: Troubleshooting**
2. Verificar la **SECCIÓN 5: Queries de Validación**
3. Consultar logs de ingesta: `.show ingestion failures`

---

**Versión**: 1.0 - Unified Setup  
**Última actualización**: 2026-01-25  
**Autor**: Anomaly Detection Team
