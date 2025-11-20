# 📊 Resumen Visual - Sistema de Alertas PostgreSQL

**Fecha**: 20/11/2025  
**Estado**: ✅ Listo para producción

---

## 🎯 Flujo Rápido: Configurar una Alerta en 5 Minutos

```
┌─────────────────────────────────────────────────────────────┐
│ PASO 1: Abrir ALERTAS-QUERIES-ESPECIFICAS.md               │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ • Ir a la sección de la alerta que quieres configurar │  │
│ │ • Ejemplo: "ALERTA 1: Data Exfiltration"              │  │
│ └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PASO 2: Copiar Query Completa                              │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ // ALERTA 1: Data Exfiltration - Query Completa       │  │
│ │ let sessionInfo = ...                                  │  │
│ │ bronze_pssql_alllogs_nometrics                        │  │
│ │ | where EventProcessedUtcTime >= ago(5m)             │  │
│ │ | where category == "PostgreSQLLogs"                 │  │
│ │ | where message contains "AUDIT:"                    │  │
│ │ ...                                                    │  │
│ │ | project TimeGenerated, AnomalyType, ServerName...  │  │
│ └────────────────────────────────────────────────────────┘  │
│                   [Ctrl+C para copiar]                      │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PASO 3: En Data Activator (Reflex)                         │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ 1. Click "Get data" → "KQL Database"                  │  │
│ │ 2. Pega la query completa [Ctrl+V]                    │  │
│ │ 3. Click "Next"                                        │  │
│ └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PASO 4: Configurar Trigger                                 │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ • Condition: SelectCount > 15                          │  │
│ │ • Evaluate: Every 1 minute                             │  │
│ │ • Suppress: 5 minutes                                  │  │
│ │ • Severity: Critical                                   │  │
│ └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ PASO 5: Configurar Email/Teams                             │
│ ┌────────────────────────────────────────────────────────┐  │
│ │ Copiar template de email desde:                       │  │
│ │ ALERTAS-QUERIES-ESPECIFICAS.md → Sección de la alerta │  │
│ │                                                        │  │
│ │ Subject: 🚨 ALERTA CRÍTICA - Posible Extracción...   │  │
│ │ Body: Contiene placeholders {User}, {Database}...     │  │
│ └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ ✅ ¡LISTO! Alerta configurada en 5 minutos                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 📚 Estructura de Documentos - Mapa Visual

```
📂 docs/
│
├── 📄 ALERTAS-QUERIES-ESPECIFICAS.md  ⭐ NUEVO - USA ESTE PARA ALERTAS
│   ├── 📋 Prerequisites (pgaudit, config)
│   ├── 🚨 ALERTA 1: Data Exfiltration
│   │   ├── ✅ Query COMPLETA (lista para copiar/pegar)
│   │   ├── 🔧 Configuración paso a paso (6 pasos)
│   │   ├── 📧 Template Email
│   │   ├── 💬 Template Teams
│   │   └── 🧪 Test de la alerta
│   │
│   ├── ⚠️ ALERTA 2: Mass Destructive Ops
│   │   ├── ✅ Query COMPLETA
│   │   ├── 🔧 Configuración (5 pasos)
│   │   ├── 📧 Template Email
│   │   └── 🧪 Test
│   │
│   ├── 🔴 ALERTA 3: Critical Error Spike
│   │   ├── ✅ Query COMPLETA con extracción dual
│   │   ├── 🔧 Configuración (7 pasos)
│   │   ├── 📧 Template Email
│   │   ├── 💬 Template Teams
│   │   ├── 🤖 Power Automate (opcional)
│   │   └── 🧪 Test
│   │
│   ├── 📊 ALERTA BONUS: Baseline Deviation
│   │   ├── ✅ Query COMPLETA
│   │   └── 🔧 Configuración
│   │
│   ├── 🔧 Troubleshooting
│   │   ├── Test 1: Verificar datos
│   │   ├── Test 2: Verificar logs AUDIT
│   │   ├── Test 3: Verificar sessionInfo
│   │   └── Soluciones específicas
│   │
│   └── ✅ Checklist Final
│       ├── Prerequisitos
│       ├── Alertas configuradas
│       ├── Tests ejecutados
│       └── Tabla resumen
│
├── 📄 REFLEX-ALERTS-CONFIG.md  (Guía de configuración - referencia)
│   ├── 🚀 Quick Start → Usa ALERTAS-QUERIES-ESPECIFICAS.md
│   ├── 🚨 Alerta 1 (resumen, query de referencia)
│   ├── ⚠️ Alerta 2 (resumen, query de referencia)
│   ├── 🔴 Alerta 3 (resumen, query de referencia)
│   ├── 🔧 Configuración Avanzada
│   │   ├── Enriquecer con UserContext/HostContext
│   │   ├── Integración SIEM
│   │   ├── Notificaciones Push
│   │   └── Testing
│   │
│   ├── 📱 Templates de Respuesta a Incidentes
│   │   ├── Data Exfiltration Response
│   │   ├── Destructive Operations Response
│   │   └── Error Spike Response
│   │
│   └── ✅ Checklist de Implementación
│
└── 📄 kql-queries-PRODUCTION.kql  (Para DASHBOARD, no alertas)
    ├── Anomalía 1 (Data Exfiltration)
    ├── Anomalía 2 (Destructive Ops)
    ├── Anomalía 3 (Error Spike)
    ├── Dashboard Principal (UNION)
    ├── 8 Tiles para Dashboard
    ├── 4 Análisis Avanzado
    └── 3 Queries de Validación
```

---

## 🔀 Diferencia entre Archivos

### ❓ ¿Cuándo usar cada archivo?

```
┌──────────────────────────────────────────────────────────────────┐
│                    CONFIGURAR ALERTAS                            │
│                                                                  │
│  USAR: ALERTAS-QUERIES-ESPECIFICAS.md ⭐                        │
│  ✅ Queries COMPLETAS e INDEPENDIENTES                          │
│  ✅ Lista para copiar/pegar sin modificar                       │
│  ✅ Incluye sessionInfo + detección + enrichment + threshold    │
│  ✅ Instrucciones paso a paso específicas para cada alerta      │
│  ✅ Templates de Email/Teams con placeholders exactos           │
│  ✅ Tests incluidos                                             │
│                                                                  │
│  NO USAR: kql-queries-PRODUCTION.kql                            │
│  ⚠️ Queries optimizadas para dashboard, NO para alertas        │
│  ⚠️ Faltan instrucciones específicas de configuración          │
│  ⚠️ Templates genéricos                                         │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    CREAR DASHBOARD                               │
│                                                                  │
│  USAR: kql-queries-PRODUCTION.kql                               │
│  ✅ Queries validadas para tiles (1-8)                          │
│  ✅ Queries de análisis avanzado                                │
│  ✅ Dashboard principal (UNION de anomalías)                    │
│  ✅ Queries de validación                                       │
│                                                                  │
│  COMPLEMENTAR CON: DASHBOARD-SETUP-GUIDE.md                     │
│  ✅ Guía detallada de configuración de tiles                    │
│  ✅ Optimizaciones de performance                               │
│  ✅ Auto-refresh, cross-filtering, variables                    │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                GUÍA DE CONFIGURACIÓN DE ALERTAS                  │
│                                                                  │
│  USAR: REFLEX-ALERTS-CONFIG.md                                  │
│  ✅ Guía completa de configuración (referencia)                 │
│  ✅ Configuración avanzada (UserContext, SIEM, Push)            │
│  ✅ Templates de respuesta a incidentes                         │
│  ✅ Troubleshooting avanzado                                    │
│  ✅ Métricas de efectividad                                     │
│                                                                  │
│  NOTA: Ahora referencia a ALERTAS-QUERIES-ESPECIFICAS.md       │
│        para las queries específicas                             │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📋 Tabla Comparativa de Queries

| Aspecto | ALERTAS-QUERIES-ESPECIFICAS.md | kql-queries-PRODUCTION.kql |
|---------|--------------------------------|----------------------------|
| **Propósito** | Configurar alertas en Data Activator | Crear dashboard y análisis |
| **Queries completas** | ✅ Sí (incluye todo) | ⚠️ No (faltan pasos) |
| **sessionInfo incluida** | ✅ Sí, en cada query | ❌ Separada |
| **Instrucciones específicas** | ✅ Paso a paso para cada alerta | ❌ Genéricas |
| **Templates Email/Teams** | ✅ Con placeholders exactos | ❌ No incluidos |
| **Tests incluidos** | ✅ Comandos SQL/bash específicos | ❌ No |
| **Troubleshooting** | ✅ Específico para alertas | ⚠️ General |
| **Facilidad de uso** | ⭐⭐⭐⭐⭐ Copiar/pegar directo | ⭐⭐⭐ Requiere ensamblaje |
| **Casos de uso** | **Solo alertas** | Dashboard + análisis |

---

## 🎯 Resumen de las 4 Alertas

### ALERTA 1: Data Exfiltration 🚨
```yaml
Detecta: >15 operaciones SELECT en 5 minutos
Threshold: SelectCount > 15
Evaluación: Cada 1 minuto
Severidad: Critical
Test: 20 SELECTs rápidos desde psql
```

### ALERTA 2: Mass Destructive Ops ⚠️
```yaml
Detecta: >5 operaciones destructivas (DELETE/UPDATE/TRUNCATE/DROP) en 2 minutos
Threshold: OperationCount > 5
Evaluación: Cada 2 minutos
Severidad: High
Test: 6 DELETEs/TRUNCATEs
```

### ALERTA 3: Critical Error Spike 🔴
```yaml
Detecta: >15 errores críticos (ERROR/FATAL/PANIC) en 1 minuto
Threshold: ErrorCount > 15
Evaluación: Cada 1 minuto
Severidad: Critical
Test: 20 intentos de autenticación fallidos
```

### ALERTA BONUS: Baseline Deviation 📊
```yaml
Detecta: Actividad 3x superior al promedio de 7 días
Threshold: DeviationFactor > 3.0
Evaluación: Cada 5 minutos
Severidad: Medium (High si >5x)
Test: Generar 3x tráfico normal
```

---

## ✅ Checklist Rápido

### Para configurar tu primera alerta (5-10 min):

- [ ] Verificar prerequisitos (pgaudit instalado)
- [ ] Abrir `ALERTAS-QUERIES-ESPECIFICAS.md`
- [ ] Ir a la sección de la alerta deseada (ej: ALERTA 1)
- [ ] Copiar la query completa
- [ ] En Data Activator: Get data → KQL Database → Pegar query
- [ ] Configurar trigger (copiar valores de threshold/evaluación)
- [ ] Copiar template de email/Teams
- [ ] Ejecutar test para validar

### Para configurar las 4 alertas (20-30 min):

- [ ] Alerta 1: Data Exfiltration (5 min)
- [ ] Alerta 2: Mass Destructive Ops (5 min)
- [ ] Alerta 3: Critical Error Spike (7 min - incluye Power Automate)
- [ ] Alerta BONUS: Baseline Deviation (3 min)
- [ ] Tests de validación (10 min)

---

## 🔗 Enlaces Rápidos

| Quiero... | Ir a... |
|-----------|---------|
| Configurar una alerta AHORA | `ALERTAS-QUERIES-ESPECIFICAS.md` → Sección de la alerta |
| Ver guía completa de alertas | `REFLEX-ALERTS-CONFIG.md` |
| Crear dashboard | `kql-queries-PRODUCTION.kql` + `DASHBOARD-SETUP-GUIDE.md` |
| Hacer troubleshooting | `ALERTAS-QUERIES-ESPECIFICAS.md` → Sección 6 |
| Ver checklist de implementación | `DEPLOYMENT-CHECKLIST.md` Fase 4 |
| Entender la arquitectura | `README.md` o `EXECUTIVE-SUMMARY.md` |

---

**🎉 ¡Todo listo para configurar alertas de forma rápida y clara!**

**⭐ RECUERDA**: Para alertas, usa SIEMPRE `ALERTAS-QUERIES-ESPECIFICAS.md` (queries completas listas para copiar/pegar).
