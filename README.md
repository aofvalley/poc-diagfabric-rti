# 🎯 PostgreSQL Anomaly Detection con Microsoft Fabric

Monitorización en tiempo real y detección automática de anomalías de seguridad para Azure PostgreSQL Flexible Server.

## 🚨 Anomalías Detectadas

| Anomalía | Umbral | Severidad |
|----------|---------|-----------|
| **Data Exfiltration** (SELECTs masivos) | >15 queries/5min | 🔴 Crítica |
| **Mass Destructive Ops** (DELETE/UPDATE) | >5 ops/2min | 🟠 Alta |
| **Error Spike** (auth/permisos) | >15 errores/min | 🔴 Crítica |

## 📁 Estructura del Proyecto

```
├── README.md                           # Este archivo
├── TEST-ANOMALY-TRIGGERS.sql           # Script de pruebas para demo
│
├── queries/
│   ├── kql-queries-PRODUCTION.kql      # ⭐ Queries principales del dashboard
│   └── ANOMALY-DETECTION-SETUP.kql     # Setup para ML Anomaly Detection
│
└── docs/
    ├── QUICKSTART.md                   # ⚡ Guía rápida de inicio
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

Abre `queries/kql-queries-PRODUCTION.kql` y ejecuta las 3 anomalías principales.

### 3. Probar con el script de demo

Ejecuta `TEST-ANOMALY-TRIGGERS.sql` en tu PostgreSQL para generar anomalías de prueba.

## 📚 Documentación

- **QUICKSTART.md** - Configuración paso a paso
- **DATA-AGENT-INSTRUCTIONS.md** - Configurar agente IA para análisis de logs
- **DATA-SOURCE-INSTRUCTIONS.md** - Referencia completa de la tabla y queries

## 🔧 Troubleshooting

**No hay datos**: Verifica que Diagnostic Settings estén activos en PostgreSQL  
**User/Host = "UNKNOWN"**: Revisa que pgaudit esté habilitado (`SHOW pgaudit.log;`)  
**Queries lentas**: Ajusta las ventanas de tiempo (usa `ago(5m)` en vez de `ago(24h)`)

---

**Versión**: 2.0  
**Última actualización**: 21/11/2025
