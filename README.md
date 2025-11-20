# 🎯 PostgreSQL Anomaly Detection - Solución Completa

## 📖 Resumen

Monitorización en tiempo real y detección automática de anomalías de seguridad para Azure PostgreSQL Flexible Server usando Microsoft Fabric.

**Detecta**:
- 🚨 **Data exfiltration** (dump masivo de datos)
- 🗑️ **Operaciones destructivas** en masa (DELETE/UPDATE/TRUNCATE)
- ⚠️ **Escalada de errores** (auth failures, permission denied)

**Estado**: ✅ PRODUCCIÓN (validado 20/11/2025)

---

## 🏗️ Arquitectura de la Solución

```
┌─────────────────────────────────────────────────────────────┐
│                PostgreSQL Flexible Server                   │
│  - pgaudit habilitado                                       │
│  - Diagnostic Settings → Real-Time Hub                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Microsoft Fabric Real-Time Hub                 │
│  - Event Stream ingestion                                   │
│  - Auto-mapping a KQL Database                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    KQL Database (Fabric)                    │
│  Tabla: bronze_pssql_alllogs_nometrics                      │
│  - Logs de PostgreSQL                                       │
│  - Audit logs (CRUD operations)                             │
│  - Métricas de sesiones                                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
┌──────────────────┐        ┌──────────────────┐
│  Real-Time       │        │  Data Activator  │
│  Dashboard       │        │  (Reflex)        │
│  - 6 tiles       │        │  - 3 alertas     │
│  - Auto-refresh  │        │  - Email/Teams   │
└──────────────────┘        └────────┬─────────┘
                                     │
                                     ▼
                            ┌──────────────────┐
                            │  Notificaciones  │
                            │  - Email         │
                            │  - Teams         │
                            │  - Power Automate│
                            └──────────────────┘
```

---

## 🚨 Anomalías Detectadas

| # | Anomalía | Descripción | Umbral | Severidad | Validación |
|---|----------|-------------|---------|-----------|------------|
| 1 | **Data Exfiltration** | Extracción masiva de datos (SELECTs) por sesión | >10 SELECTs/min | 🔴 Crítica | ✅ Validado |
| 2 | **Mass Destructive Ops** | DELETE/UPDATE/TRUNCATE en masa | >5 ops/2min | 🟠 Alta | ✅ Validado |
| 3 | **Error Spike** | Pico de errores de auth/permisos/conexión | >15 errores/min | 🔴 Crítica | ✅ Validado |

**Nota**: Los umbrales son ajustables según tu baseline. Valores recomendados basados en producción típica PostgreSQL.

---

## 📁 Estructura del Proyecto

```
poc-diagfabric-rti/
│
├── README.md                      # Este archivo - Quick Start
│
├── queries/
│   └── kql-queries-PRODUCTION.kql # ⭐ Queries validadas (copiar/pegar en Fabric)
│
├── docs/
│   ├── QUICKSTART.md              # ⚡ Empezar en 5 minutos
│   ├── DEPLOYMENT-CHECKLIST.md    # ✅ Despliegue completo (30-45 min)
│   ├── DASHBOARD-SETUP-GUIDE.md   # 📊 Crear dashboard paso a paso
│   ├── REFLEX-ALERTS-CONFIG.md    # 🔔 Configurar alertas
│   └── EXECUTIVE-SUMMARY.md       # 📈 KPIs, ROI, costos
│
└── deprecated/                     # Archivos históricos (ignorar)
```

---

## 🚀 Quick Start (10 minutos)

### 1️⃣ Validar datos (2 min)

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| extend 
    Operation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    Statement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message)
| take 20
```

### 2️⃣ Detectar anomalías (3 min)

Ejecuta las 3 queries de `queries/kql-queries-PRODUCTION.kql`:
- Líneas 12-65: Data Exfiltration
- Líneas 71-114: Destructive Operations  
- Líneas 120-137: Error Spike

### 3️⃣ Crear dashboard (5 min)

Sigue `docs/DASHBOARD-SETUP-GUIDE.md` para crear los tiles básicos.
| 5. Errores por Categoría | 225-240 | 5 min |
| 6. Actividad por Backend Type | 246-254 | 5 min |

**Acceso**: Fabric Portal → Tu Workspace → **+ New** → **Real-Time Dashboard**

---

### 🔔 **PASO 4: Configurar Alertas en Reflex (3 min)**

Sigue la guía **`REFLEX-ALERTS-CONFIG.md`** para crear 3 alertas críticas:

1. **Alert_DataExfiltration**: Dispara cuando `QueryCount > 15` en 5 min
2. **Alert_MassDestructiveOps**: Dispara cuando `OperationCount > 5` en 10 min
3. **Alert_ErrorSpike**: Dispara cuando `ErrorCount > 20` en 1 min

**Acciones disponibles**: Email + Microsoft Teams + Power Automate (plantillas incluidas en guía)

**✅ ¡Listo!** Ahora tienes monitorización completa de anomalías PostgreSQL en tiempo real.

---

## 📊 Dashboard - Paneles Incluidos

### Panel 1: 🚨 Anomalías Detectadas (Tiempo Real)
- **Tipo**: Table
- **Refresh**: 30s
- **Muestra**: Últimas 50 anomalías con detalles (IP, servidor, tipo)

### Panel 2: 📈 Actividad por Servidor
- **Tipo**: Time chart
- **Refresh**: 1min
- **Muestra**: Total eventos, errores, warnings (última hora)

### Panel 3: 🌐 Top 10 IPs por Actividad
- **Tipo**: Table
- **Refresh**: 5min
- **Muestra**: IPs más activas con % de errores (24h)

### Panel 4: ⚠️ Timeline de Errores por Categoría
- **Tipo**: Area chart
- **Refresh**: 2min
- **Muestra**: Distribución temporal de tipos de error (24h)

### Panel 5: 🗑️ Operaciones Destructivas Recientes
- **Tipo**: Table
- **Refresh**: 2min
- **Muestra**: DELETE/UPDATE/TRUNCATE con tablas afectadas (6h)

### Panel 6: 👥 Sesiones Activas vs Idle
- **Tipo**: Time chart
- **Refresh**: 30s
- **Muestra**: Sesiones activas e idle en tiempo real (30min)

---

## 🔔 Alertas Configuradas

### Alerta 1: Data Exfiltration 🔴
- **Trigger**: >10 SELECTs en 5min desde misma IP
- **Notificación**: Email + Teams (#security-alerts)
- **Suppress**: 5 minutos
- **Auto-acción**: Opcional - Bloqueo temporal de IP

### Alerta 2: Mass Destructive Operations 🟠
- **Trigger**: >5 DELETE/UPDATE/TRUNCATE en 10min
- **Notificación**: Email a DBAs + App Owners
- **Suppress**: 10 minutos
- **Info**: Tablas afectadas, tipos de operaciones

### Alerta 3: Error Spike 🔴
- **Trigger**: >15 errores/min (auth, permisos, conexiones)
- **Notificación**: Email + Teams + Incident ticket
- **Suppress**: 3 minutos
- **Auto-acción**: Bloqueo de IP si >30 errores de auth

### Alerta 4 (Bonus): Baseline Deviation 🟡
- **Trigger**: Actividad 3x superior al promedio (7 días)
- **Notificación**: Email a Performance Team
- **Suppress**: 15 minutos
- **Info**: Factor de desviación calculado

---

## 📚 Documentación Adicional

- `docs/QUICKSTART.md` - Empezar en 5 minutos
- `docs/DEPLOYMENT-CHECKLIST.md` - Despliegue completo paso a paso
- `docs/DASHBOARD-SETUP-GUIDE.md` - Crear dashboard con tiles
- `docs/REFLEX-ALERTS-CONFIG.md` - Configurar alertas
- `docs/EXECUTIVE-SUMMARY.md` - KPIs, ROI, costos

---

## 🔧 Troubleshooting

**No se ven datos**: Verifica ingesta ejecutando `bronze_pssql_alllogs_nometrics | count`  
**Queries lentas**: Revisa `docs/DASHBOARD-SETUP-GUIDE.md` sección de optimización  
**Alertas no llegan**: Verifica permisos en `docs/REFLEX-ALERTS-CONFIG.md`

---

## 📞 Soporte

**Archivos clave**:
- Queries: `queries/kql-queries-PRODUCTION.kql`
- Deployment: `docs/DEPLOYMENT-CHECKLIST.md`
- Troubleshooting: `docs/DASHBOARD-SETUP-GUIDE.md` (sección final)

// 2. Verificar latencia de ingesta
bronze_pssql_alllogs_nometrics
| extend Latency = EventProcessedUtcTime - todatetime(timestamp)
| summarize avg(Latency), max(Latency)
```

**Soluciones**:
1. Verificar que Diagnostic Settings estén activos en Azure Portal
2. Comprobar que Real-Time Hub esté en estado "Running"
3. Revisar errores en Event Stream

### Problema: Demasiadas alertas (fatiga)

**Soluciones**:
1. Aumentar umbrales (ej: ErrorCount > 20 en vez de > 15)
2. Implementar whitelist de IPs conocidas
3. Usar alertas compuestas: `(Condition1 AND Duration > 5m)`
4. Aumentar tiempo de supresión (de 5min a 15min)

### Problema: Queries del dashboard lentas

**Optimizaciones**:
```kql
// 1. Crear índice en columna de tiempo
.alter table bronze_pssql_alllogs_nometrics policy partitioning 
```json
{
  "PartitionKeys": [
    {
      "ColumnName": "EventProcessedUtcTime",
      "Kind": "Hash",
      "Properties": {
        "Function": "StartOfDay"
      }
    }
  ]
}
```

// 2. Materialized view para queries frecuentes
.create materialized-view HourlyStats on table bronze_pssql_alllogs_nometrics
{
    bronze_pssql_alllogs_nometrics
    | summarize 
        Events = count(),
        Errors = countif(errorLevel == "ERROR")
        by LogicalServerName, bin(EventProcessedUtcTime, 1h)
}
```

---

## 🔒 Seguridad y Compliance

### Datos Sensibles
- ✅ No se exponen passwords ni datos de aplicación
- ✅ Solo metadata: IPs, tipos de operaciones, códigos de error
- ✅ Logs almacenados en región compliance (uksouth)

### Control de Acceso
```yaml
Dashboard Access:
  - Security Team: Read
  - DBA Team: Read + Edit
  - SRE Team: Read

Reflex Alerts:
  - Security Team: Manage alerts
  - DBA Team: View alert history

KQL Database:
  - Security Team: db_viewer
  - DBA Team: db_viewer + db_ingestor
```

---

**Versión**: 2.0 - Queries validadas  
**Última actualización**: 2025-11-20  
**Estado**: ✅ Listo para producción
