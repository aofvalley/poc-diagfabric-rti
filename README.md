# 🎯 PostgreSQL Anomaly Detection con Microsoft Fabric

Monitorización en tiempo real y detección automática de anomalías de seguridad para Azure PostgreSQL Flexible Server.

## 🚨 Anomalías Detectadas

### Anomalías Básicas (SIEM-detectable)
| Anomalía | Umbral | Severidad |
|----------|--------|-----------|
| **Data Exfiltration** (SELECTs masivos) | >15 queries/5min | 🔴 Crítica |
| **Mass Destructive Ops** (DELETE/UPDATE) | >5 ops/2min | 🟠 Alta |
| **Error Spike** (auth/permisos) | >15 errores/min | 🔴 Crítica |

### 🔴 Anomalías Avanzadas v3 (Defender NO detecta)
| Anomalía | Umbral | Por qué Defender falla |
|----------|--------|------------------------|
| **Privilege Escalation** | >3 GRANTs/5min | Ve eventos individuales, no secuencias |
| **Cross-Schema Recon** | >4 schemas/10min | No correlaciona movimiento lateral |
| **Deep Schema Enum** | >10 pg_catalog/5min | No detecta patrón de reconocimiento |
| **ML Baseline Deviation** | score >1.5 | No tiene baseline del usuario |

## 📁 Estructura del Proyecto

```
├── README.md                           # Este archivo
├── TEST-ANOMALY-TRIGGERS.sql           # Script de pruebas para demo
│
├── queries/
│   ├── kql-queries-PRODUCTION.kql      # ⭐ Queries principales (7 anomalías)
│   └── ANOMALY-DETECTION-SETUP.kql     # Setup ML con métricas mejoradas
│
└── docs/
    ├── QUICKSTART.md                   # ⚡ Guía rápida
    ├── ADVANCED-ANOMALIES.md           # 🔴 NEW: Guía anomalías avanzadas
    ├── DATA-AGENT-INSTRUCTIONS.md      # Instrucciones para agente IA
    └── DATA-SOURCE-INSTRUCTIONS.md     # Documentación de la tabla
```

## 🚀 Quick Start

### 1. Validar que los datos llegan

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| take 20
```

### 2. Ejecutar queries de detección

Abre `queries/kql-queries-PRODUCTION.kql` y ejecuta las 7 anomalías.

### 3. Probar con el script de demo

Ejecuta `TEST-ANOMALY-TRIGGERS.sql` en tu PostgreSQL para generar anomalías de prueba.
- **Tests 1-4**: Anomalías básicas
- **Tests 5-8**: Anomalías avanzadas (v3)

## 📚 Documentación

- **QUICKSTART.md** - Configuración paso a paso
- **ADVANCED-ANOMALIES.md** - ⭐ Guía anomalías avanzadas (Defender-proof)
- **DATA-AGENT-INSTRUCTIONS.md** - Configurar agente IA para análisis de logs
- **DATA-SOURCE-INSTRUCTIONS.md** - Referencia completa de la tabla y queries

## 🔧 Troubleshooting

**No hay datos**: Verifica que Diagnostic Settings estén activos en PostgreSQL  
**User/Host = "UNKNOWN"**: Revisa que pgaudit esté habilitado (`SHOW pgaudit.log;`)  
**ML no detecta**: Asegura 7+ días de histórico en `postgres_activity_metrics`

---

**Versión**: 3.0  
**Última actualización**: 12/01/2026
