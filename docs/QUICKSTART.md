# ⚡ Quick Start - 5 Minutos

**PostgreSQL Anomaly Detection con Microsoft Fabric**

---

## 🎯 Paso 1: Verificar Datos (30 segundos)

Abre **Fabric Portal** → Tu Workspace → **KQL Query Editor** → Ejecuta:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| take 10
```

✅ **Esperado**: Ver 10 filas con logs recientes  
❌ **Si falla**: Revisar Event Stream configuration

---

## 🎯 Paso 2: Validar Extracción (1 min)

Copia y ejecuta este query:

```kql
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(1h)
| where message contains "AUDIT:"
| extend 
    AuditOperation = extract(@"AUDIT: SESSION,\d+,\d+,([A-Z]+),", 1, message),
    AuditStatement = extract(@"AUDIT: SESSION,\d+,\d+,[A-Z]+,([A-Z ]+),", 1, message),
    QueryText = trim('"', extract(@",,,([^<]+)<", 1, message))
| take 10
| project EventProcessedUtcTime, AuditOperation, AuditStatement, QueryText
```

✅ **Esperado**: Ver `READ`, `WRITE`, `SELECT`, `UPDATE` en columnas  
❌ **Si falla**: Ver `kql-validation-queries.kql` TEST 1

---

## 🎯 Paso 3: Ejecutar Primera Anomalía (1 min)

Abre **`kql-queries-PRODUCTION.kql`** → Copia líneas **12-41** → Ejecuta

✅ **Esperado**: Query ejecuta sin errores (resultado puede estar vacío = no hay anomalías)

---

## 🎯 Paso 4: Crear Dashboard (2 min)

1. **+ New** → **Real-Time Dashboard** → Nombre: `PostgreSQL Security`
2. **Add data source** → Tu KQL Database → **Add**
3. **New tile** → Copia query de `kql-queries-PRODUCTION.kql` líneas **157-167**
4. **Visual**: Time chart → **Auto-refresh**: 2 min → **Save**

✅ **Listo**: Ya tienes tu primer tile monitorizando actividad

---

## 🎯 Paso 5: Crear Primera Alerta (1 min)

1. **+ New** → **Reflex** → Nombre: `PostgreSQL_Alerts`
2. **Get data** → **EventStream** o **Dashboard**
3. **+ New alert**:
   - Nombre: `Alert_DataExfiltration`
   - Condición: `AnomalyType = "Potential Data Exfiltration"`
   - Action: Email → tu dirección
4. **Save & Activate**

✅ **Listo**: Recibirás email cuando se detecte anomalía

---

## 📚 Siguiente Paso

Sigue **`DEPLOYMENT-CHECKLIST.md`** para:
- Añadir 5 tiles más al dashboard (10 min)
- Configurar 2 alertas adicionales (5 min)
- Ejecutar tests de validación (10 min)

---

## 📁 Archivos Importantes

| Archivo | Uso |
|---------|-----|
| `kql-queries-PRODUCTION.kql` | 📊 Queries validadas para dashboard y alertas |
| `DEPLOYMENT-CHECKLIST.md` | ✅ Despliegue completo paso a paso |
| `DASHBOARD-SETUP-GUIDE.md` | 🎨 Configuración detallada dashboard |
| `REFLEX-ALERTS-CONFIG.md` | 🔔 Configuración alertas avanzadas |
| `EXECUTIVE-SUMMARY.md` | 📈 Resumen ejecutivo para management |

---

**🎉 ¡En 5 minutos tienes monitorización básica funcionando!**
