# ⚡ Quick Start

**PostgreSQL Anomaly Detection con Microsoft Fabric**

## 🎯 Paso 1: Verificar Datos (1 min)

Abre **Fabric Portal** → Tu Workspace → **KQL Query Editor** → Ejecuta:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| take 10
```

✅ **Esperado**: Ver 10 filas con logs AUDIT recientes  
❌ **Si falla**: Verificar que pgaudit esté habilitado en PostgreSQL

## 🎯 Paso 2: Ejecutar Detección de Anomalías (2 min)

Abre `queries/kql-queries-PRODUCTION.kql` y ejecuta las 3 queries principales:
- **Anomalía 1**: Data Exfiltration (líneas ~26-70)
- **Anomalía 2**: Destructive Operations (líneas ~76-145)
- **Anomalía 3**: Error Spike (líneas ~151-210)

## 🎯 Paso 3: Probar con Script de Demo (5 min)

Ejecuta `TEST-ANOMALY-TRIGGERS.sql` en tu PostgreSQL para generar anomalías de prueba.

Espera 1-2 minutos y vuelve a ejecutar las queries. Deberías ver resultados.

## 📚 Documentación Adicional

- **DATA-AGENT-INSTRUCTIONS.md** - Configurar agente IA para análisis
- **DATA-SOURCE-INSTRUCTIONS.md** - Referencia completa de queries y patrones
- **ANOMALY-DETECTION-SETUP.kql** - Setup para ML-based anomaly detection

---

**Versión**: 2.0  
**Última actualización**: 21/11/2025
