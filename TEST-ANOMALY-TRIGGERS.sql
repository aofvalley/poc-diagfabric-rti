-- ============================================================================
-- SCRIPT DE PRUEBA: Generar Anomalías para Dashboard PostgreSQL
-- ============================================================================
-- Propósito: Ejecutar queries que activen las 7 anomalías del dashboard v3
-- Base de datos: adventureworks (con pgaudit habilitado)
-- Ejecutar con: psql o Azure Data Studio
-- Versión: 3.0 (Actualizada 19/01/2026 - Alineada con queries PRODUCTION v3)
-- ============================================================================
--
-- 📋 PREREQUISITOS ANTES DE LA DEMO:
-- 1. ✅ Extensión pgaudit instalada: SELECT * FROM pg_extension WHERE extname = 'pgaudit';
-- 2. ✅ pgaudit configurado: SHOW pgaudit.log; (debe ser 'ALL' o incluir 'READ, WRITE')
-- 3. ✅ Diagnostic Settings habilitado en Azure Portal (PostgreSQLLogs enabled)
-- 4. ✅ Event Stream funcionando en Fabric (verificar ingesta)
-- 5. ✅ Tabla bronze_pssql_alllogs_nometrics recibiendo datos
-- 6. ✅ Tabla postgres_activity_metrics creada (para Anomalía 7 ML)
-- 7. ✅ Dashboard creado con queries de kql-queries-PRODUCTION.kql
-- 8. ✅ Alertas configuradas en Data Activator (opcional para demo)
--
-- ════════════════════════════════════════════════════════════════════════════
-- 📊 MAPEO DE TESTS → ANOMALÍAS KQL (kql-queries-PRODUCTION.kql)
-- ════════════════════════════════════════════════════════════════════════════
-- │ TEST │ ANOMALÍA KQL                    │ THRESHOLD            │ LINEAS KQL │
-- ├──────┼─────────────────────────────────┼──────────────────────┼────────────┤
-- │  1   │ Potential Data Exfiltration     │ >15 SELECTs / 5 min  │ 26-95      │
-- │  2   │ Mass Destructive Operations     │ >5 ops / 2 min       │ 97-166     │
-- │  3   │ Critical Error Spike            │ (sin threshold/debug)│ 169-245    │
-- │  4   │ Privilege Escalation            │ >3 priv ops / 5 min  │ 252-314    │
-- │  5   │ Cross-Schema Reconnaissance     │ >4 schemas / 10 min  │ 316-374    │
-- │  6   │ Deep Schema Enumeration         │ >10 queries / 5 min  │ 377-455    │
-- │  7   │ ML Baseline Deviation           │ score > 1.5 (ML)     │ 461-498    │
-- └──────┴─────────────────────────────────┴──────────────────────┴────────────┘
--
-- 🎯 FLUJO DE LA DEMO (orden recomendado):
-- 1. Ejecutar TEST 1 (Data Exfiltration) → Esperar 1-2 min → Mostrar dashboard
-- 2. Ejecutar TEST 2 (Destructive Ops) → Esperar 1-2 min → Mostrar dashboard
-- 3. Ejecutar TEST 3 (Error Spike) → Esperar 1-2 min → Mostrar dashboard
-- 4. Ejecutar TEST 4 (Privilege Escalation) → Esperar 1-2 min → Mostrar dashboard
-- 5. Ejecutar TEST 5 (Cross-Schema Recon) → Esperar 1-2 min → Mostrar dashboard
-- 6. Ejecutar TEST 6 (Deep Schema Enum) → Esperar 1-2 min → Mostrar dashboard
-- 7. Ejecutar TEST 7 (ML Baseline) → Esperar 5-10 min → Mostrar dashboard
-- 8. (Opcional) TEST AUTH (Brute Force) → Con script externo
--
-- ⏱️ TIEMPO TOTAL DE DEMO: ~20-30 minutos (2-3 min por test + explicación)
-- ============================================================================

-- ============================================================================
-- TEST 1: ANOMALÍA 1 - Extracción Masiva de Datos (Data Exfiltration)
-- ============================================================================
-- 📊 Requisito: >15 SELECTs en 5 minutos (Query: kql-queries-PRODUCTION.kql líneas 26-70)
-- 🎯 Estrategia: Ejecutar 20 SELECTs consecutivos para activar la alerta
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Potential Data Exfiltration
--    - SelectCount: ~20
--    - TablesAccessed: Lista de tablas accedidas
--    - SampleQueries: Primeras 3 queries ejecutadas
--    - User/Database/SourceHost: Debe mostrar tu información (no "UNKNOWN")
-- ============================================================================

-- 🔍 FASE 1: Reconocimiento de tablas del sistema (patrón típico de ataque)
-- Estas queries simulan un atacante explorando la estructura de la base de datos
SELECT * FROM pg_catalog.pg_tables WHERE schemaname = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_class WHERE relkind = 'r' LIMIT 1;
SELECT * FROM information_schema.tables WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM information_schema.columns WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_namespace LIMIT 1;
SELECT * FROM pg_catalog.pg_attribute LIMIT 1;

-- 📦 FASE 2: Extracción de datos de negocio (simular exfiltración real)
-- Estas queries simulan un atacante extrayendo datos sensibles
SELECT * FROM sales.customer LIMIT 100;
SELECT * FROM sales.salesorderheader LIMIT 100;
SELECT * FROM sales.salesorderdetail LIMIT 100;
SELECT * FROM person.person LIMIT 100;
SELECT * FROM person.address LIMIT 100;
SELECT * FROM production.product LIMIT 100;
SELECT * FROM humanresources.employee LIMIT 100;
SELECT * FROM purchasing.vendor LIMIT 100;

-- 🔢 FASE 3: Queries de conteo (completar threshold de 15+)
-- Estas queries aseguran que superamos el threshold de 15 SELECTs
SELECT COUNT(*) FROM sales.customer;
SELECT COUNT(*) FROM sales.salesorderheader;
SELECT COUNT(*) FROM production.product;
SELECT COUNT(*) FROM person.person;
SELECT COUNT(*) FROM person.address;
SELECT COUNT(*) FROM humanresources.employee;

-- ✅ TOTAL: 20 SELECTs ejecutados en ~30 segundos
-- 🎬 DEMO TIP: Explicar al cliente que esta actividad es sospechosa porque:
--    1. Demasiadas SELECTs en poco tiempo (20 en 5 min es inusual)
--    2. Patrón de reconocimiento (pg_catalog, information_schema)
--    3. Extracción masiva de múltiples tablas sensibles
--    4. Típico de ataques de Data Exfiltration o SQL Injection

-- ⏸️ PAUSA PARA LA DEMO (1-2 minutos):
-- Mientras esperas la ingesta, explica al cliente:
-- - "Estos logs se están enviando a Event Hub en tiempo real"
-- - "Stream Analytics está procesando y enriqueciendo los datos"
-- - "En 1-2 minutos veremos la anomalía en el dashboard de Fabric"
-- Luego, abre el dashboard y muestra la Anomalía 1 con todos los detalles.
-- ============================================================================


-- ============================================================================
-- TEST 2: ANOMALÍA 2 - Operaciones Destructivas Masivas
-- ============================================================================
-- 📊 Requisito: >5 operaciones destructivas en ventanas de 2 minutos
--             (Query: kql-queries-PRODUCTION.kql líneas 76-122)
-- 🎯 Estrategia: Crear tabla temporal y ejecutar 6 UPDATEs/DELETEs rápidamente
-- ⏱️ Tiempo de ejecución: ~1 minuto
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Mass Destructive Operations
--    - OperationCount: 6
--    - Operations: UPDATE, DELETE
--    - TablesAffected: temp_test_anomaly
--    - SampleMessages: Queries UPDATE/DELETE ejecutadas
--    - User/Database/SourceHost: Debe mostrar tu información
-- ============================================================================

-- 🏗️ PREPARACIÓN: Crear tabla temporal para pruebas
-- (Esta tabla solo existe durante la demo, se elimina al final)
DROP TABLE IF EXISTS temp_test_anomaly CASCADE;
CREATE TABLE temp_test_anomaly (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    value INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 📥 INSERTAR DATOS: Crear 10 registros de prueba
INSERT INTO temp_test_anomaly (name, value) VALUES 
    ('Test Record 1', 100),
    ('Test Record 2', 200),
    ('Test Record 3', 300),
    ('Test Record 4', 400),
    ('Test Record 5', 500),
    ('Test Record 6', 600),
    ('Test Record 7', 700),
    ('Test Record 8', 800),
    ('Test Record 9', 900),
    ('Test Record 10', 1000);

-- ⚠️ FASE DESTRUCTIVA: Ejecutar 6 operaciones destructivas EN MENOS DE 2 MINUTOS
-- IMPORTANTE: Ejecuta estas 6 queries rápidamente (copy/paste todo el bloque)
UPDATE temp_test_anomaly SET name = 'Updated Record 1', value = 9999 WHERE id = 1;
UPDATE temp_test_anomaly SET name = 'Updated Record 2', value = 9999 WHERE id = 2;
UPDATE temp_test_anomaly SET name = 'Updated Record 3', value = 9999 WHERE id = 3;
DELETE FROM temp_test_anomaly WHERE id = 4;
DELETE FROM temp_test_anomaly WHERE id = 5;
UPDATE temp_test_anomaly SET name = 'Updated Record 6', value = 9999 WHERE id = 6;

-- ✅ TOTAL: 6 operaciones destructivas ejecutadas en < 2 minutos
-- 🎬 DEMO TIP: Explicar al cliente que esta actividad es sospechosa porque:
--    1. Demasiadas operaciones destructivas en poco tiempo (6 en 2 min)
--    2. Patrón típico de:
--       - Insider threat (empleado malicioso)
--       - Ransomware modificando/eliminando datos
--       - Error humano (script ejecutado sin WHERE clause)
--       - SQL Injection atacando datos
--    3. La query detecta: UPDATE, DELETE, TRUNCATE, DROP TABLE/DATABASE
--    4. El threshold de >5 en 2 min filtra mantenimiento normal

-- ⏸️ PAUSA PARA LA DEMO (1-2 minutos):
-- Explicar al cliente mientras esperas:
-- - "La query agrupa operaciones destructivas en ventanas de 2 minutos"
-- - "bin(EventProcessedUtcTime, 2m) permite detectar ráfagas de actividad"
-- - "Si un usuario ejecuta 6 DELETEs/UPDATEs en 2 min, es anormal"
-- Luego, abre el dashboard y muestra la Anomalía 2 con:
-- - OperationCount = 6
-- - Operations = "UPDATE, DELETE"
-- - TablesAffected = "temp_test_anomaly"
-- - SampleMessages con las queries ejecutadas
-- ============================================================================


-- ============================================================================
-- TEST 3: ANOMALÍA 3 - Escalada de Errores Críticos
-- ============================================================================
-- 📊 Requisito: >15 errores críticos (ERROR/FATAL/PANIC) en 1 minuto
--             (Query: kql-queries-PRODUCTION.kql líneas 128-184)
-- 🎯 Estrategia: Ejecutar 20 queries inválidas consecutivamente
-- ⏱️ Tiempo de ejecución: ~20 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Critical Error Spike
--    - ErrorCount: ~20
--    - ErrorTypes: Permission Error, Other Error
--    - ErrorCodes: 42P01 (undefined_table), 42703 (undefined_column)
--    - User/Database/SourceHost: Debe mostrar tu información
-- ============================================================================

-- ⚠️ IMPORTANTE: Estas queries generarán errores A PROPÓSITO
-- Esto es normal y esperado para demostrar la detección de anomalías

-- 🚨 FASE 1: Errores de tabla inexistente (código 42P01)
-- Simula un atacante intentando acceder a tablas que no existen
SELECT * FROM tabla_que_no_existe_1;
SELECT * FROM tabla_que_no_existe_2;
SELECT * FROM tabla_que_no_existe_3;
SELECT * FROM tabla_que_no_existe_4;
SELECT * FROM tabla_que_no_existe_5;
SELECT * FROM tabla_que_no_existe_6;
SELECT * FROM tabla_que_no_existe_7;
SELECT * FROM tabla_que_no_existe_8;
SELECT * FROM tabla_que_no_existe_9;
SELECT * FROM tabla_que_no_existe_10;

-- 🔍 FASE 2: Errores de columna inválida (código 42703)
-- Simula queries con sintaxis incorrecta o inyección SQL fallida
SELECT columna_invalida FROM sales.customer;
SELECT * FROM sales.customer WHERE columna_invalida = 'test';
SELECT id, nombre_invalido FROM person.person;
SELECT direccion_inexistente FROM person.address;
SELECT codigo_erroneo FROM production.product;

-- 🔒 FASE 3: Más errores para alcanzar threshold de 15+ en 1 minuto
-- EJECUTA ESTE BLOQUE RÁPIDAMENTE (copy/paste todo junto)
SELECT * FROM tabla_inexistente_11;
SELECT * FROM tabla_inexistente_12;
SELECT * FROM tabla_inexistente_13;
SELECT * FROM tabla_inexistente_14;
SELECT * FROM tabla_inexistente_15;
SELECT * FROM tabla_inexistente_16;
SELECT * FROM tabla_inexistente_17;
SELECT * FROM tabla_inexistente_18;

-- ✅ TOTAL: ~23 errores generados en ~20 segundos
-- 🎬 DEMO TIP: Explicar al cliente que esta actividad es crítica porque:
--    1. Más de 15 errores por minuto es extremadamente inusual
--    2. Puede indicar:
--       - 🔴 Brute Force Attack (intentos de autenticación fallidos)
--       - 🔴 SQL Injection (atacante probando queries maliciosas)
--       - 🟠 Aplicación mal configurada (connection string incorrecta)
--       - 🟠 Problema de permisos (usuario sin acceso a tablas)
--    3. La query categoriza errores en tipos:
--       - Authentication Failure (brute force)
--       - Permission Denied (escalada de privilegios)
--       - Connection Error (DoS attack o fallo de red)
--       - Resource Exhausted (out of memory/disk)
--       - Other Error (syntax errors, tablas inexistentes)
--    4. El threshold de >15 por minuto es muy conservador (solo incidentes serios)

-- ⏸️ PAUSA PARA LA DEMO (1-2 minutos):
-- Explicar al cliente mientras esperas:
-- - "La query agrupa errores en ventanas de 1 minuto: bin(EventProcessedUtcTime, 1m)"
-- - "Extrae información del usuario/database/host desde los mensajes de error"
-- - "Si no hay user en el error, correlaciona con CONNECTION logs usando processId"
-- - "Esto permite identificar QUIÉN está generando los errores"
-- 
-- 🔍 TROUBLESHOOTING: Si no ves resultados en el dashboard:
-- 1. Aumenta la ventana de tiempo de 5m a 30m (editado en kql-queries-PRODUCTION.kql)
-- 2. Threshold eliminado temporalmente (muestra todos los buckets de errores)
-- 3. Ordenado por ErrorCount desc para ver los picos primero
-- 4. Fallback triple añadido: DirectUser → SessionUser → "UNKNOWN"
--
-- Luego, abre el dashboard y muestra la Anomalía 3 con:
-- - ErrorCount: Cualquier valor (sin threshold, verás todos los buckets)
-- - ErrorTypes = "Permission Error" (código 42xxx)
-- - ErrorCodes = "42P01, 42703" (undefined_table, undefined_column)
-- - SampleErrors con mensajes de las queries fallidas
-- - User/Database/SourceHost identificados (con fallback a "UNKNOWN" si es necesario)
--
-- ⚙️ PARA PRODUCCIÓN: Después de verificar que funciona:
-- - Restaura ventana a ago(5m)
-- - Agrega de nuevo: | where ErrorCount > 15
-- - Esto filtrará solo anomalías críticas (>15 errores/minuto)
-- ============================================================================


-- ============================================================================
-- TEST AUTH (OPCIONAL): TILE - Fallos de Autenticación (Brute Force)
-- ============================================================================
-- 📊 Requisito: Detectar intentos de brute force (>3 fallos por usuario/host)
--             (Query: kql-queries-PRODUCTION.kql líneas 700-730 - TILE 12)
-- 🎯 Estrategia: Intentar conectarse con contraseña incorrecta 10-20 veces
-- ⏱️ Tiempo de ejecución: ~1-2 minutos
-- 
-- ⚠️ NOTA: Este NO es una Anomalía principal (1-7), es un TILE del dashboard
--          Pero es útil para demostrar detección de brute force attacks
--
-- 📈 Resultado esperado en dashboard:
--    - TILE "Fallos de Autenticación"
--    - User: tu_usuario_test
--    - SourceHost: tu_ip
--    - FailedAttempts: 10-20
--    - ThreatLevel: 🟠 HIGH (si >5 fallos) o 🔴 CRITICAL (si >10 fallos)
-- ============================================================================

-- ⚠️ IMPORTANTE: Este test NO se puede ejecutar desde una conexión autenticada
-- Debes ejecutarlo FUERA de esta sesión SQL, usando terminal o script

-- ════════════════════════════════════════════════════════════════════════════
-- OPCIÓN 1: Script Bash (Linux/Mac/Windows Git Bash) - RECOMENDADO PARA DEMO
-- ════════════════════════════════════════════════════════════════════════════
-- Guarda este script como: test_brute_force.sh
-- Ejecútalo: bash test_brute_force.sh

#!/bin/bash
# CAMBIA ESTOS VALORES POR TUS DATOS REALES:
SERVER="advpsqlfxuk.postgres.database.azure.com"  # Tu servidor PostgreSQL
USER="testuser"                                    # Usuario de prueba
DATABASE="adventureworks"                          # Base de datos
WRONG_PASSWORD="INTENTIONALLY_WRONG_PASSWORD_123"  # Password incorrecta a propósito

echo "🚨 Iniciando test de brute force attack..."
echo "Servidor: $SERVER"
echo "Usuario: $USER"
echo "Generando 20 intentos fallidos en 60 segundos..."
echo ""

for i in {1..20}; do
  echo -n "Intento $i/20... "
  # PGPASSWORD fuerza la password sin prompt interactivo
  # 2>&1 redirige errores para capturar el mensaje
  # grep -q busca el error de autenticación
  PGPASSWORD="$WRONG_PASSWORD" psql -h "$SERVER" -U "$USER" -d "$DATABASE" -c "SELECT 1;" 2>&1 | grep -q "password authentication failed"
  
  if [ $? -eq 0 ]; then
    echo "❌ FAILED (autenticación fallida detectada)"
  else
    echo "⚠️ Error inesperado (verificar conectividad)"
  fi
  
  # Esperar 3 segundos entre intentos para simular ataque realista
  sleep 3
done

echo ""
echo "✅ Test completado: 20 intentos fallidos generados"
echo "⏱️ Espera 1-2 minutos y verifica el dashboard en Fabric"
echo "📊 Busca en TILE 'Fallos de Autenticación':"
echo "   - User: $USER"
echo "   - FailedAttempts: ~20"
echo "   - ThreatLevel: 🔴 CRITICAL"


-- ════════════════════════════════════════════════════════════════════════════
-- OPCIÓN 2: Script PowerShell (Windows) - ALTERNATIVA PARA DEMO EN WINDOWS
-- ════════════════════════════════════════════════════════════════════════════
-- Guarda este script como: test_brute_force.ps1
-- Ejecútalo: powershell -File test_brute_force.ps1

<#
# CAMBIA ESTOS VALORES POR TUS DATOS REALES:
$SERVER = "advpsqlfxuk.postgres.database.azure.com"
$USER = "testuser"
$DATABASE = "adventureworks"
$WRONG_PASSWORD = "INTENTIONALLY_WRONG_PASSWORD_123"

Write-Host "🚨 Iniciando test de brute force attack..." -ForegroundColor Red
Write-Host "Servidor: $SERVER"
Write-Host "Usuario: $USER"
Write-Host "Generando 20 intentos fallidos en 60 segundos..."
Write-Host ""

1..20 | ForEach-Object {
    Write-Host -NoNewline "Intento $_/20... "
    
    # Configurar variable de entorno para password (evita prompt)
    $env:PGPASSWORD = $WRONG_PASSWORD
    
    # Intentar conexión (redirigir errores a $null para evitar spam en consola)
    $result = psql -h $SERVER -U $USER -d $DATABASE -c "SELECT 1;" 2>&1
    
    if ($result -match "password authentication failed") {
        Write-Host "❌ FAILED (autenticación fallida detectada)" -ForegroundColor Red
    } else {
        Write-Host "⚠️ Error inesperado (verificar psql instalado)" -ForegroundColor Yellow
    }
    
    # Esperar 3 segundos entre intentos
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "✅ Test completado: 20 intentos fallidos generados" -ForegroundColor Green
Write-Host "⏱️ Espera 1-2 minutos y verifica el dashboard en Fabric"
Write-Host "📊 Busca en TILE 'Fallos de Autenticación':"
Write-Host "   - User: $USER"
Write-Host "   - FailedAttempts: ~20"
Write-Host "   - ThreatLevel: 🔴 CRITICAL"
#>


-- ════════════════════════════════════════════════════════════════════════════
-- OPCIÓN 3: Script Python (Multiplataforma) - SI NO TIENES PSQL INSTALADO
-- ════════════════════════════════════════════════════════════════════════════
-- Guarda este script como: test_brute_force.py
-- Ejecuta: python test_brute_force.py
-- Prerequisito: pip install psycopg2-binary

<#
import psycopg2
import time

# CAMBIA ESTOS VALORES POR TUS DATOS REALES:
SERVER = "advpsqlfxuk.postgres.database.azure.com"
USER = "testuser"
DATABASE = "adventureworks"
WRONG_PASSWORD = "INTENTIONALLY_WRONG_PASSWORD_123"

print("🚨 Iniciando test de brute force attack...")
print(f"Servidor: {SERVER}")
print(f"Usuario: {USER}")
print("Generando 20 intentos fallidos en 60 segundos...\n")

for i in range(1, 21):
    print(f"Intento {i}/20... ", end="", flush=True)
    
    try:
        # Intentar conectar con password incorrecta
        conn = psycopg2.connect(
            host=SERVER,
            database=DATABASE,
            user=USER,
            password=WRONG_PASSWORD,
            connect_timeout=5
        )
        conn.close()
        print("⚠️ UNEXPECTED: Conexión exitosa (verificar password)")
    
    except psycopg2.OperationalError as e:
        if "password authentication failed" in str(e):
            print("❌ FAILED (autenticación fallida detectada)")
        else:
            print(f"⚠️ Error: {e}")
    
    # Esperar 3 segundos entre intentos
    time.sleep(3)

print("\n✅ Test completado: 20 intentos fallidos generados")
print("⏱️ Espera 1-2 minutos y verifica el dashboard en Fabric")
print("📊 Busca en TILE 'Fallos de Autenticación':")
print(f"   - User: {USER}")
print("   - FailedAttempts: ~20")
print("   - ThreatLevel: 🔴 CRITICAL")
#>


-- ════════════════════════════════════════════════════════════════════════════
-- OPCIÓN 4: Azure Portal (SIN CÓDIGO) - MÁS RÁPIDO PARA DEMO CON CLIENTE
-- ════════════════════════════════════════════════════════════════════════════
-- Si no tienes psql instalado o prefieres evitar scripts:
--
-- 1. Ve a Azure Portal → Tu PostgreSQL Flexible Server
-- 2. Networking → Deshabilita "Public access" temporalmente
-- 3. Desde Azure Data Studio o cualquier cliente, intenta conectarte 20 veces
--    (fallará porque el servidor rechaza conexiones)
-- 4. Restaura "Public access" después del test
--
-- VENTAJA: No requiere instalar nada, muy rápido para demos
-- DESVENTAJA: Genera CONNECTION ERRORS en vez de AUTHENTICATION ERRORS
--             (pero igual dispara la Anomalía 3 - Error Spike)


-- 🎬 DEMO TIP: Explicar al cliente durante la ejecución
-- Mientras el script ejecuta (toma ~60 segundos), explica:
-- - "Este script simula un ataque de brute force"
-- - "Está intentando conectarse con password incorrecta 20 veces"
-- - "Cada intento genera un error de autenticación en PostgreSQL"
-- - "Los logs se envían a Fabric en tiempo real"
-- - "La query detecta >3 fallos del mismo usuario/IP = ThreatLevel HIGH"
-- - "Si son >10 fallos = ThreatLevel CRITICAL (posible ataque)"
--
-- Resultado esperado en dashboard (1-2 min después):
-- - TILE "Fallos de Autenticación":
--   * User: testuser
--   * ClientHost: tu_ip_publica (ej: 203.0.113.45)
--   * FailedAttempts: 20
--   * ThreatLevel: 🔴 CRITICAL
--   * Databases: adventureworks
--   * FirstAttempt / LastAttempt: timestamps del ataque
--
-- - (BONUS) Puede disparar también ANOMALÍA 3 (Error Spike) si >15 fallos/min
-- ============================================================================


-- ============================================================================
-- ============================================================================
--                    🔴 ANOMALÍAS AVANZADAS (Tests 4-7)
--              Patrones que Defender/SIEM NO pueden detectar
-- ============================================================================
-- ============================================================================
-- Estos tests simulan patrones de ataque sofisticados que requieren:
-- ✅ Análisis de baseline comportamental (ML)
-- ✅ Correlación cross-signal (usuario + tiempo + tipo de query)
-- ✅ Comparación con patrones históricos (imposible para SIEM basado en reglas)
--
-- Defender/SIEM vería estos como eventos "normales" individuales porque:
-- ❌ No conocen tus horarios de trabajo
-- ❌ No pueden establecer baselines por usuario
-- ❌ No tienen contexto sobre patrones normales de privilegios
-- ❌ Procesan eventos de forma aislada, no como secuencias de comportamiento
-- ============================================================================


-- ============================================================================
-- TEST 4: ANOMALÍA 4 - Escalada de Privilegios (Privilege Escalation)
-- ============================================================================
-- 📊 Requisito: Detectar >3 operaciones de privilegios en 5 minutos
--             (Query: kql-queries-PRODUCTION.kql líneas 252-314)
-- 🎯 Estrategia: Ejecutar secuencia de GRANTs sospechosa
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 
-- ⚠️ POR QUÉ DEFENDER NO LO DETECTA:
--    - Defender ve "GRANT SELECT TO user" = operación de admin normal ✅
--    - NO detecta la VELOCIDAD (5 GRANTs en 2 minutos = sospechoso)
--    - NO detecta el PATRÓN (mismo usuario otorgando permisos a sí mismo)
--    - NO correlaciona con el rol del usuario (¿es realmente admin?)
--
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Privilege Escalation
--    - Severity: MEDIUM/HIGH
--    - PrivilegeOpsCount: 6+
--    - Operations: GRANT, REVOKE, CREATE ROLE
--    - User: Tu usuario
-- ============================================================================

-- 🏗️ PREPARACIÓN: Crear roles temporales para pruebas
DROP ROLE IF EXISTS test_analyst_v3;
DROP ROLE IF EXISTS test_developer_v3;  
DROP ROLE IF EXISTS test_admin_v3;

CREATE ROLE test_analyst_v3;
CREATE ROLE test_developer_v3;
CREATE ROLE test_admin_v3;

-- ⚠️ FASE SOSPECHOSA: Ejecutar 6 operaciones de privilegios EN MENOS DE 5 MINUTOS
GRANT SELECT ON ALL TABLES IN SCHEMA sales TO test_analyst_v3;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA sales TO test_developer_v3;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales TO test_admin_v3;
GRANT test_analyst_v3 TO test_developer_v3;  -- Escalada: developer hereda analyst
GRANT test_developer_v3 TO test_admin_v3;    -- Escalada: admin hereda developer
REVOKE ALL ON SCHEMA public FROM test_analyst_v3;  -- Revocación sospechosa

-- ✅ TOTAL: 6 operaciones de privilegios en ráfaga
-- 🎬 DEMO TIP: Cada GRANT individual es normal, pero 6 en 2 min = ataque

-- 🧹 LIMPIEZA: Eliminar roles de prueba
DROP ROLE IF EXISTS test_analyst_v3;
DROP ROLE IF EXISTS test_developer_v3;
DROP ROLE IF EXISTS test_admin_v3;


-- ============================================================================
-- TEST 5: ANOMALÍA 5 - Reconocimiento Cross-Schema (Lateral Movement)
-- ============================================================================
-- 📊 Requisito: Detectar mismo usuario accediendo >4 schemas en 10 minutos
--             (Query: kql-queries-PRODUCTION.kql líneas 316-374)
-- 🎯 Estrategia: Ejecutar queries que acceden a múltiples schemas
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 
-- ⚠️ POR QUÉ DEFENDER NO LO DETECTA:
--    - Defender ve "SELECT from sales.X" = query normal ✅
--    - NO correlaciona que el mismo usuario accedió 5 schemas diferentes
--    - NO tiene contexto de que este usuario normalmente usa 1 schema
--    - Movimiento lateral es invisible sin análisis cross-schema
--
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Cross-Schema Reconnaissance
--    - Severity: MEDIUM/HIGH
--    - SchemasAccessed: 5+
--    - SchemaList: sales, production, person, humanresources, purchasing
--    - User: Tu usuario
-- ============================================================================

-- 🔍 Queries que acceden a múltiples schemas en ráfaga
SELECT datname, encoding FROM pg_database WHERE datistemplate = false;
SELECT nspname FROM pg_namespace WHERE nspname NOT LIKE 'pg_%';

-- Acceso a diferentes schemas de negocio
SELECT * FROM sales.customer LIMIT 1;
SELECT * FROM production.product LIMIT 1;
SELECT * FROM person.person LIMIT 1;
SELECT * FROM humanresources.employee LIMIT 1;
SELECT * FROM purchasing.vendor LIMIT 1;

-- Queries de reconocimiento de estructura multi-schema
SELECT table_schema, COUNT(*) as table_count 
FROM information_schema.tables 
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
GROUP BY table_schema;

-- ✅ TOTAL: 8 queries de reconocimiento cross-schema
-- 🎬 DEMO TIP: Usuario normal = 1-2 schemas. 5+ schemas = mapeo de atacante
-- ============================================================================


-- ============================================================================
-- TEST 6: ANOMALÍA 6 - Enumeración Profunda de Schema (Deep Scan)
-- ============================================================================
-- 📊 Requisito: Detectar >10 queries a tablas de sistema en 5 minutos
--             (Query: kql-queries-PRODUCTION.kql líneas 377-455)
-- 🎯 Estrategia: Ejecutar reconocimiento exhaustivo del schema
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 
-- ⚠️ POR QUÉ DEFENDER NO LO DETECTA:
--    - Defender ve "SELECT from pg_tables" = query de metadata ✅
--    - NO detecta la PROFUNDIDAD (atacante mapeando TODA la estructura)
--    - NO detecta la SECUENCIA (pg_tables → pg_columns → pg_proc)
--    - Este patrón es preparación para SQL injection o exfiltración
--
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Deep Schema Enumeration
--    - Severity: MEDIUM/HIGH/CRITICAL
--    - SystemTableQueries: 15+
--    - TablesScanned: pg_tables, pg_class, pg_attribute, pg_proc...
--    - RiskLevel: 🔴 HIGH - Multi-table scan
--    - User: Tu usuario
-- ============================================================================

-- 🔍 FASE 1: Mapeo de estructura de tablas
SELECT schemaname, tablename, tableowner FROM pg_tables 
    WHERE schemaname NOT LIKE 'pg_%' LIMIT 5;
SELECT table_schema, table_name, table_type FROM information_schema.tables 
    WHERE table_schema NOT LIKE 'pg_%' LIMIT 5;
SELECT relname, relkind FROM pg_class WHERE relkind = 'r' LIMIT 5;

-- 🔍 FASE 2: Mapeo de columnas (para saber qué datos robar)
SELECT column_name, data_type, is_nullable FROM information_schema.columns 
    WHERE table_schema = 'sales' LIMIT 10;
SELECT attname, atttypid FROM pg_attribute 
    WHERE attrelid = 'sales.customer'::regclass AND attnum > 0 LIMIT 5;

-- 🔍 FASE 3: Mapeo de funciones y procedimientos
SELECT proname, pronargs FROM pg_proc WHERE pronamespace != 11 LIMIT 5;
SELECT routine_name, routine_type FROM information_schema.routines 
    WHERE routine_schema NOT IN ('pg_catalog', 'information_schema') LIMIT 5;

-- 🔍 FASE 4: Mapeo de constraints y relaciones
SELECT conname, contype FROM pg_constraint LIMIT 5;
SELECT constraint_name, table_name, constraint_type FROM information_schema.table_constraints 
    WHERE table_schema = 'sales' LIMIT 5;
SELECT indexname FROM pg_indexes WHERE schemaname = 'sales' LIMIT 5;

-- 🔍 FASE 5: Información de usuarios y permisos
SELECT rolname, rolsuper FROM pg_roles LIMIT 5;
SELECT grantee, privilege_type, table_name FROM information_schema.table_privileges 
    WHERE table_schema = 'sales' LIMIT 5;

-- ✅ TOTAL: 15+ queries a tablas de sistema en secuencia
-- 🎬 DEMO TIP: 
--    - "Cada query parece inocente"
--    - "La SECUENCIA revela intención: mapear toda la BD"
--    - "Defender ve 15 queries normales, Fabric ve 1 ataque coordinado"
-- ============================================================================


-- ============================================================================
-- TEST 7: ANOMALÍA 7 - Desviación de Baseline ML (ML Baseline Deviation)
-- ============================================================================
-- 📊 Requisito: Generar actividad que desvíe del baseline ML
--             (Query: series_decompose_anomalies en postgres_activity_metrics)
-- 🎯 Estrategia: Ejecutar MUCHAS queries para crear spike de actividad
-- 
-- ⚠️ IMPORTANTE: Este test requiere:
--    1. Tabla postgres_activity_metrics creada (ANOMALY-DETECTION-SETUP.kql)
--    2. Al menos 7 días de datos históricos para baseline
--    3. Ejecutar en horario INUSUAL para tu patrón (ej: 3 AM)
--
-- ⚠️ POR QUÉ DEFENDER NO LO DETECTA:
--    - Defender ve "usuario X ejecutó SELECT" = evento normal ✅
--    - NO sabe que este usuario NUNCA trabaja a las 3 AM
--    - NO tiene baseline del patrón horario de cada usuario
--    - Solo Fabric ML con series_decompose_anomalies puede detectarlo
--
-- 📈 Resultado esperado en dashboard (5-10 min después):
--    - AnomalyType: ML Baseline Deviation
--    - AnomalyDirection: 📈 Above Normal
--    - DeviationScore: >1.5 (debe ser >2.0 para HIGH, >3.0 para CRITICAL)
--    - ServerName: Tu servidor
-- ============================================================================

-- 🕐 FASE 1: Generar SPIKE de actividad (50+ queries en 5 minutos)
-- El objetivo es generar actividad MUY POR ENCIMA del baseline normal

SELECT current_timestamp as access_time, 'ML SPIKE TEST - START' as test_type;

-- 🔥 RÁFAGA 1: Accesos masivos a tablas de negocio (20 queries)
SELECT * FROM sales.customer LIMIT 1;
SELECT * FROM sales.salesorderheader LIMIT 1;
SELECT * FROM sales.salesorderdetail LIMIT 1;
SELECT * FROM sales.store LIMIT 1;
SELECT * FROM sales.salesperson LIMIT 1;
SELECT * FROM person.person LIMIT 1;
SELECT * FROM person.address LIMIT 1;
SELECT * FROM person.emailaddress LIMIT 1;
SELECT * FROM person.phonenumbertype LIMIT 1;
SELECT * FROM person.businessentity LIMIT 1;
SELECT * FROM production.product LIMIT 1;
SELECT * FROM production.productcategory LIMIT 1;
SELECT * FROM production.productsubcategory LIMIT 1;
SELECT * FROM production.productmodel LIMIT 1;
SELECT * FROM production.productinventory LIMIT 1;
SELECT * FROM humanresources.employee LIMIT 1;
SELECT * FROM humanresources.department LIMIT 1;
SELECT * FROM humanresources.shift LIMIT 1;
SELECT * FROM purchasing.vendor LIMIT 1;
SELECT * FROM purchasing.purchaseorderheader LIMIT 1;

-- 🔥 RÁFAGA 2: Queries de conteo (10 queries más)
SELECT COUNT(*) FROM sales.customer;
SELECT COUNT(*) FROM sales.salesorderheader;
SELECT COUNT(*) FROM person.person;
SELECT COUNT(*) FROM production.product;
SELECT COUNT(*) FROM humanresources.employee;
SELECT COUNT(*) FROM purchasing.vendor;
SELECT COUNT(*) FROM sales.salesorderdetail;
SELECT COUNT(*) FROM person.address;
SELECT COUNT(*) FROM production.productinventory;
SELECT COUNT(*) FROM humanresources.department;

-- 🔥 RÁFAGA 3: Queries con agregaciones (10 queries más)
SELECT MAX(totaldue) FROM sales.salesorderheader;
SELECT MIN(totaldue) FROM sales.salesorderheader;
SELECT AVG(listprice) FROM production.product;
SELECT SUM(orderqty) FROM sales.salesorderdetail;
SELECT COUNT(DISTINCT customerid) FROM sales.customer;
SELECT MAX(modifieddate) FROM person.person;
SELECT MIN(hiredate) FROM humanresources.employee;
SELECT AVG(standardcost) FROM production.product;
SELECT SUM(quantity) FROM production.productinventory;
SELECT COUNT(DISTINCT departmentid) FROM humanresources.department;

-- 🔥 RÁFAGA 4: Queries con JOINs (10 queries más - más carga)
SELECT c.customerid, p.firstname FROM sales.customer c 
    JOIN person.person p ON c.personid = p.businessentityid LIMIT 5;
SELECT o.salesorderid, c.customerid FROM sales.salesorderheader o 
    JOIN sales.customer c ON o.customerid = c.customerid LIMIT 5;
SELECT e.businessentityid, d.name FROM humanresources.employee e 
    JOIN humanresources.employeedepartmenthistory edh ON e.businessentityid = edh.businessentityid
    JOIN humanresources.department d ON edh.departmentid = d.departmentid LIMIT 5;
SELECT p.productid, pc.name FROM production.product p 
    JOIN production.productsubcategory ps ON p.productsubcategoryid = ps.productsubcategoryid
    JOIN production.productcategory pc ON ps.productcategoryid = pc.productcategoryid LIMIT 5;
SELECT v.businessentityid, pod.productid FROM purchasing.vendor v 
    JOIN purchasing.purchaseorderheader poh ON v.businessentityid = poh.vendorid
    JOIN purchasing.purchaseorderdetail pod ON poh.purchaseorderid = pod.purchaseorderid LIMIT 5;
SELECT a.addressid, sp.name FROM person.address a 
    JOIN person.stateprovince sp ON a.stateprovinceid = sp.stateprovinceid LIMIT 5;
SELECT p.businessentityid, e.emailaddressid FROM person.person p 
    JOIN person.emailaddress e ON p.businessentityid = e.businessentityid LIMIT 5;
SELECT soh.salesorderid, sod.productid, p.name FROM sales.salesorderheader soh
    JOIN sales.salesorderdetail sod ON soh.salesorderid = sod.salesorderid
    JOIN production.product p ON sod.productid = p.productid LIMIT 5;
SELECT c.customerid, a.city FROM sales.customer c 
    JOIN person.businessentityaddress bea ON c.personid = bea.businessentityid
    JOIN person.address a ON bea.addressid = a.addressid LIMIT 5;
SELECT e.businessentityid, p.firstname, p.lastname FROM humanresources.employee e
    JOIN person.person p ON e.businessentityid = p.businessentityid LIMIT 5;

SELECT current_timestamp as access_time, 'ML SPIKE TEST - END' as test_type;

-- ✅ TOTAL: 52 queries ejecutadas en ráfaga (~1-2 minutos)
-- 🎬 DEMO TIP: 
--    - "Ejecutamos 52 queries en 2 minutos"
--    - "El baseline normal es ~5-10 queries por ventana de 5 minutos"
--    - "ML detecta que esto es 5-10x el baseline = ANOMALÍA"
--    - "DeviationScore > 2.0 = HIGH, > 3.0 = CRITICAL"
--
-- ⏸️ PAUSA PARA LA DEMO (5-10 minutos):
-- El ML necesita más tiempo para procesar y comparar con el baseline.
-- Mientras esperas, ejecuta los otros tests o explica:
-- - "series_decompose_anomalies() compara con los últimos 7 días"
-- - "Detecta seasonality (patrones horarios/diarios) automáticamente"
-- - "Si la actividad actual está 1.5σ por encima del baseline = anomalía"
-- ============================================================================


-- ============================================================================
-- LIMPIEZA POST-DEMO
-- ============================================================================
-- ⚠️ EJECUTAR DESPUÉS DE LA DEMO PARA ELIMINAR TABLA TEMPORAL
-- ============================================================================

-- Eliminar tabla de prueba creada en TEST 2
DROP TABLE IF EXISTS temp_test_anomaly CASCADE;

-- Verificar que se eliminó correctamente
SELECT 
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'temp_test_anomaly')
        THEN '✅ Tabla temp_test_anomaly eliminada correctamente'
        ELSE '⚠️ La tabla aún existe'
    END AS cleanup_status;

-- 🎬 DEMO TIP: Ejecuta esto al final de la demo para dejar la base de datos limpia
-- ============================================================================

-- ============================================================================
-- VERIFICACIÓN DE RESULTADOS - CHECKLIST PARA LA DEMO
-- ============================================================================
-- ⏱️ ESPERA 1-2 MINUTOS DESPUÉS DE CADA TEST PARA VER RESULTADOS
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- 1. VERIFICACIÓN EN DASHBOARD DE FABRIC
-- ════════════════════════════════════════════════════════════════════════════

-- 📊 TILE "Anomalías Detectadas" (Panel Principal):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ ✅ TEST 1 - Anomalía "Potential Data Exfiltration"                    │
-- │    - SelectCount: ~20                                                   │
-- │    - TablesAccessed: pg_tables, pg_class, customer, salesorderheader... │
-- │    - SampleQueries: 3 primeras queries ejecutadas                       │
-- │    - User/Database/SourceHost: TU información (NO "UNKNOWN")            │
-- │                                                                         │
-- │ ✅ TEST 2 - Anomalía "Mass Destructive Operations"                     │
-- │    - OperationCount: 6                                                  │
-- │    - Operations: UPDATE, DELETE                                         │
-- │    - TablesAffected: temp_test_anomaly                                  │
-- │    - SampleMessages: Queries UPDATE/DELETE ejecutadas                   │
-- │    - User/Database/SourceHost: TU información                           │
-- │                                                                         │
-- │ ✅ TEST 3 - Anomalía "Critical Error Spike"                            │
-- │    - ErrorCount: ~20-23                                                 │
-- │    - ErrorTypes: Other Error (o Permission Error)                       │
-- │    - ErrorCodes: 42P01 (undefined_table), 42703 (undefined_column)      │
-- │    - SampleErrors: Mensajes de queries fallidas                         │
-- │    - User/Database/SourceHost: TU información                           │
-- │                                                                         │
-- │ ✅ TEST 4 - Anomalía "Privilege Escalation" 🔴 AVANZADA                │
-- │    - AnomalyType: Privilege Escalation                                  │
-- │    - PrivilegeOpsCount: 6+                                              │
-- │    - Operations: CREATE ROLE, GRANT, REVOKE                             │
-- │    - User/Database/SourceHost: TU información                           │
-- │                                                                         │
-- │ ✅ TEST 5 - Anomalía "Cross-Schema Reconnaissance" 🔴 AVANZADA         │
-- │    - AnomalyType: Cross-Schema Reconnaissance                           │
-- │    - SchemasAccessed: 5+ (sales, production, person, hr, purchasing)    │
-- │    - User/Database/SourceHost: TU información                           │
-- │                                                                         │
-- │ ✅ TEST 6 - Anomalía "Deep Schema Enumeration" 🔴 AVANZADA             │
-- │    - AnomalyType: Deep Schema Enumeration                               │
-- │    - SystemTableQueries: 15+                                            │
-- │    - TablesScanned: pg_tables, pg_class, pg_attribute, pg_proc...       │
-- │    - User/Database/SourceHost: TU información                           │
-- │                                                                         │
-- │ ✅ TEST 7 - Anomalía "ML Baseline Deviation" 🔴 AVANZADA               │
-- │    - AnomalyType: ML Baseline Deviation                                 │
-- │    - DeviationScore: >1.5 (>2.0 = HIGH, >3.0 = CRITICAL)               │
-- │    - AnomalyDirection: 📈 Above Normal                                  │
-- │    - ⚠️ Requiere: 7 días de datos históricos + ejecutar a hora inusual │
-- └────────────────────────────────────────────────────────────────────────┘

-- 📊 OTROS TILES DEL DASHBOARD (Verificación Adicional):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ ✅ TILE "TOP Usuarios por Actividad"                                   │
-- │    - Debe mostrar TU usuario con alta actividad                         │
-- │    - TotalActivity: ~40+ (20 SELECTs + 6 UPDATEs/DELETEs + 20 errores) │
-- │    - AuditLogs: ~26, Errors: ~20                                        │
-- │                                                                         │
-- │ ✅ TILE "TOP Hosts/IPs por Conexiones"                                 │
-- │    - Debe mostrar TU IP pública                                         │
-- │    - TotalConnections: 1+                                               │
-- │    - Errors: ~20 (si ejecutaste TEST 3)                                 │
-- │    - ErrorRate: calculado (Errors / TotalConnections)                   │
-- │                                                                         │
-- │ ✅ TILE "Fallos de Autenticación" (Solo si ejecutaste TEST AUTH)       │
-- │    - User: testuser (o el usuario que usaste)                           │
-- │    - ClientHost: tu_ip_publica                                          │
-- │    - FailedAttempts: ~20                                                │
-- │    - ThreatLevel: 🔴 CRITICAL                                           │
-- │    - Databases: adventureworks                                          │
-- └────────────────────────────────────────────────────────────────────────┘


-- ════════════════════════════════════════════════════════════════════════════
-- 2. VERIFICACIÓN DE QUERIES DE DIAGNÓSTICO (OPCIONAL - TROUBLESHOOTING)
-- ════════════════════════════════════════════════════════════════════════════

-- 🔍 Verificar que pgaudit está funcionando (DEBE retornar rows):
SELECT * FROM bronze_pssql_alllogs_nometrics 
WHERE EventProcessedUtcTime >= ago(5m)
  AND message contains "AUDIT:"
  AND category == "PostgreSQLLogs"
| take 10;

-- 🔍 Verificar que User/Database/Host se están capturando (NO debe ser "UNKNOWN"):
SELECT 
    User = extract(@"user=([^\s,]+)", 1, message),
    Database = extract(@"database=([^\s,]+)", 1, message),
    ClientHost = extract(@"host=([^\s]+)", 1, message),
    message
FROM bronze_pssql_alllogs_nometrics
WHERE EventProcessedUtcTime >= ago(5m)
  AND (message contains "connection authorized" or message contains "connection received")
| where isnotempty(User)
| take 10;

-- 🔍 Verificar que las anomalías se generaron (DEBE retornar 3 rows):
union
    (bronze_pssql_alllogs_nometrics | where AnomalyType == "Potential Data Exfiltration" | take 1),
    (bronze_pssql_alllogs_nometrics | where AnomalyType == "Mass Destructive Operations" | take 1),
    (bronze_pssql_alllogs_nometrics | where AnomalyType == "Critical Error Spike" | take 1)
| project AnomalyType, TimeGenerated, SelectCount, OperationCount, ErrorCount;


-- ════════════════════════════════════════════════════════════════════════════
-- 3. VERIFICACIÓN DE ALERTAS EN DATA ACTIVATOR (SI CONFIGURADAS)
-- ════════════════════════════════════════════════════════════════════════════

-- Si configuraste alertas en Data Activator (Reflex), verifica:
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ ✅ Alerta 1 - "Alert_DataExfiltration"                                  │
-- │    - Estado: Triggered (disparada)                                      │
-- │    - Trigger: SelectCount > 15                                          │
-- │    - Acciones: Email/Teams enviado (verificar inbox/canal)              │
-- │                                                                         │
-- │ ✅ Alerta 2 - "Alert_MassDestructiveOps"                                │
-- │    - Estado: Triggered                                                  │
-- │    - Trigger: OperationCount > 5                                        │
-- │    - Acciones: Email/Teams enviado                                      │
-- │                                                                         │
-- │ ✅ Alerta 3 - "Alert_ErrorSpike"                                        │
-- │    - Estado: Triggered                                                  │
-- │    - Trigger: ErrorCount > 15                                           │
-- │    - Acciones: Email/Teams enviado + Posible ticket en ServiceNow       │
-- └────────────────────────────────────────────────────────────────────────┘


-- ════════════════════════════════════════════════════════════════════════════
-- 4. TROUBLESHOOTING - SI LAS ANOMALÍAS NO APARECEN
-- ════════════════════════════════════════════════════════════════════════════

-- 🚨 PROBLEMA: User/Database/Host = "UNKNOWN" en las anomalías
-- 🔧 SOLUCIÓN: Verificar extensión pgaudit instalada

-- En PostgreSQL (ejecutar desde psql/Azure Data Studio):
SELECT * FROM pg_extension WHERE extname = 'pgaudit';
-- Si NO retorna nada, ejecuta: CREATE EXTENSION pgaudit;

-- Verificar configuración pgaudit:
SHOW pgaudit.log;
-- Debe retornar: 'ALL' o al menos 'READ, WRITE, DDL'
-- Si está vacío, configurar en Azure Portal:
-- Ir a Server Parameters → pgaudit.log → Valor: 'ALL' → Save


-- 🚨 PROBLEMA: Las anomalías no aparecen en el dashboard
-- 🔧 SOLUCIÓN: Verificar pipeline de ingesta

-- 1. Verificar Diagnostic Settings habilitado:
--    Azure Portal → PostgreSQL Flexible Server → Diagnostic Settings
--    → Asegurar que "PostgreSQLLogs" está checked y enviando a Event Hub

-- 2. Verificar Event Stream funcionando:
--    Fabric → Workspace → Event Streams → Ver si hay datos fluyendo

-- 3. Verificar tabla recibiendo datos:
--    Ejecutar en KQL Database:
bronze_pssql_alllogs_nometrics
| where EventProcessedUtcTime >= ago(5m)
| count;
--    Si count = 0, el problema está en la ingesta (Event Hub/Stream Analytics)
--    Si count > 0, el problema está en las queries (revisar thresholds)


-- 🚨 PROBLEMA: Anomalías aparecen pero sin detalles (User/Database/Host vacíos)
-- 🔧 SOLUCIÓN: Revisar correlación sessionInfo

-- Ejecutar query de diagnóstico en KQL Database:
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

sessionInfo
| count;
-- Si count = 0, NO hay CONNECTION logs en la tabla (verificar Diagnostic Settings)
-- Si count > 0, la correlación debería funcionar (verificar que processId coincide)


-- ════════════════════════════════════════════════════════════════════════════
-- 5. PUNTOS CLAVE PARA EXPLICAR AL CLIENTE (SCRIPT DE DEMO)
-- ════════════════════════════════════════════════════════════════════════════

-- 🎯 MENSAJE 1: "Detección en Tiempo Real"
-- - "Los logs de PostgreSQL llegan a Fabric en 30-90 segundos"
-- - "No hay necesidad de consultar directamente PostgreSQL"
-- - "Todo se procesa en Fabric con KQL (lenguaje Azure Data Explorer)"

-- 🎯 MENSAJE 2: "Correlación User/Database/Host"
-- - "PostgreSQL AUDIT logs NO incluyen usuario por defecto"
-- - "Correlacionamos con CONNECTION logs usando processId"
-- - "Esto permite identificar QUIÉN hizo QUÉ desde DÓNDE"

-- 🎯 MENSAJE 3: "Thresholds Ajustables"
-- - "Anomalía 1: >15 SELECTs en 5 min (ajustable según tu baseline)"
-- - "Anomalía 2: >5 operaciones destructivas en 2 min (ventanas bin(2m))"
-- - "Anomalía 3: >15 errores por minuto (muy conservador)"
-- - "Puedes modificar los thresholds en kql-queries-PRODUCTION.kql"

-- 🎯 MENSAJE 4: "Alertas Automáticas"
-- - "Data Activator monitorea las anomalías cada 1-2 minutos"
-- - "Si se superan los thresholds, dispara alertas instantáneas"
-- - "Envía emails/Teams con toda la información contextual"
-- - "Puede integrar con ServiceNow/Jira para crear tickets automáticamente"

-- 🎯 MENSAJE 5: "Sin Agentes, Sin Impacto"
-- - "No requiere instalar nada en PostgreSQL"
-- - "Solo requiere pgaudit (extensión nativa de PostgreSQL)"
-- - "Impacto en performance: <1% (logging asíncrono)"
-- - "Escalable a cientos de servidores PostgreSQL"


-- ════════════════════════════════════════════════════════════════════════════
-- 6. CHECKLIST FINAL ANTES DE LA DEMO CON CLIENTE
-- ════════════════════════════════════════════════════════════════════════════

-- ☐ 1. Verificar pgaudit instalado y configurado (pgaudit.log = 'ALL')
-- ☐ 2. Verificar Diagnostic Settings enviando logs a Event Hub
-- ☐ 3. Verificar Event Stream ingiriendo datos a KQL Database
-- ☐ 4. Verificar tabla bronze_pssql_alllogs_nometrics tiene datos recientes (<5 min)
-- ☐ 5. Verificar dashboard creado con queries de kql-queries-PRODUCTION.kql
-- ☐ 6. (Opcional) Verificar alertas configuradas en Data Activator
-- ☐ 7. Ejecutar TEST 1 y verificar que aparece en dashboard (~2 min)
-- ☐ 8. Ejecutar TEST 2 y verificar que aparece en dashboard (~2 min)
-- ☐ 9. Ejecutar TEST 3 y verificar que aparece en dashboard (~2 min)
-- ☐ 10. Ejecutar TEST 4 (Privilege Escalation) y verificar (~2 min)
-- ☐ 11. Ejecutar TEST 5 (Cross-Schema Recon) y verificar (~2 min)
-- ☐ 12. Ejecutar TEST 6 (Deep Schema Enum) y verificar (~2 min)
-- ☐ 13. Ejecutar TEST 7 (ML Baseline) y verificar (~5-10 min)
-- ☐ 14. (Opcional) Ejecutar TEST AUTH con script bash/powershell/python
-- ☐ 15. Verificar que User/Database/Host NO son "UNKNOWN" (correlación OK)
-- ☐ 16. Limpiar tabla temp_test_anomaly al final de la demo

-- ✅ SI TODOS LOS CHECKS PASAN, ESTÁS LISTO PARA LA DEMO!
-- ============================================================================


-- ============================================================================
-- NOTAS ADICIONALES - INFORMACIÓN TÉCNICA
-- ============================================================================

-- 📌 THRESHOLDS ACTUALES (Configurados en kql-queries-PRODUCTION.kql):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ ANOMALÍA 1 - Data Exfiltration:                                        │
-- │   - Threshold: SelectCount > 15 (en 5 minutos)                         │
-- │   - Ventana: ago(5m)                                                   │
-- │   - Filtro: backend_type == "client backend" (solo usuarios reales)    │
-- │   - Query: Líneas 26-70 de kql-queries-PRODUCTION.kql                  │
-- │                                                                         │
-- │ ANOMALÍA 2 - Mass Destructive Operations:                              │
-- │   - Threshold: OperationCount > 5 (en ventanas de 2 minutos)           │
-- │   - Ventana: ago(10m) con bin(EventProcessedUtcTime, 2m)               │
-- │   - Filtro: backend_type == "client backend" (aplicado POST-threshold) │
-- │   - Query: Líneas 76-122 de kql-queries-PRODUCTION.kql                 │
-- │                                                                         │
-- │ ANOMALÍA 3 - Critical Error Spike:                                     │
-- │   - Threshold: ErrorCount > 15 (por minuto)                            │
-- │   - Ventana: ago(5m) con bin(EventProcessedUtcTime, 1m)                │
-- │   - Filtro: errorLevel in ("ERROR", "FATAL", "PANIC")                  │
-- │   - Query: Líneas 128-184 de kql-queries-PRODUCTION.kql                │
-- │                                                                         │
-- │ TILE - Authentication Failures:                                        │
-- │   - Threshold: FailedAttempts > 3 (por usuario/host en 24h)            │
-- │   - Ventana: ago(24h)                                                  │
-- │   - ThreatLevel: >3 = HIGH, >10 = CRITICAL                             │
-- │   - Query: Líneas 424-445 de kql-queries-PRODUCTION.kql                │
-- └────────────────────────────────────────────────────────────────────────┘

-- 🔧 CÓMO AJUSTAR THRESHOLDS (Post-demo con el cliente):
-- 1. Abre el archivo: queries/kql-queries-PRODUCTION.kql
-- 2. Busca la línea con "| where SelectCount > 15" (para Anomalía 1)
-- 3. Cambia el valor 15 por el threshold que desees (ej: 20, 30, etc.)
-- 4. Repite para las otras anomalías (OperationCount > 5, ErrorCount > 15)
-- 5. Actualiza el dashboard en Fabric con la query modificada
-- 6. (Opcional) Actualiza las alertas en Data Activator con el nuevo threshold


-- 📊 REQUISITOS DE DATOS (Para que las anomalías funcionen):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ ✅ Extensión pgaudit instalada en PostgreSQL:                          │
-- │    CREATE EXTENSION IF NOT EXISTS pgaudit;                             │
-- │                                                                         │
-- │ ✅ Configuración pgaudit en PostgreSQL (Azure Portal):                 │
-- │    Server Parameters → pgaudit.log → Valor: 'ALL'                      │
-- │    Server Parameters → shared_preload_libraries → Valor: 'pgaudit'     │
-- │    Server Parameters → azure.extensions → Valor: 'PGAUDIT' (allowlist) │
-- │                                                                         │
-- │ ✅ Diagnostic Settings habilitado (Azure Portal):                      │
-- │    PostgreSQL Flexible Server → Diagnostic Settings                    │
-- │    → Logs: PostgreSQLLogs (checked)                                    │
-- │    → Destination: Event Hub (configurar nombre)                        │
-- │                                                                         │
-- │ ✅ Event Stream configurado en Fabric:                                 │
-- │    Source: Event Hub (con los logs de PostgreSQL)                      │
-- │    Destination: KQL Database → Tabla: bronze_pssql_alllogs_nometrics   │
-- │                                                                         │
-- │ ✅ Tabla KQL Database con datos recientes:                             │
-- │    Verificar: bronze_pssql_alllogs_nometrics                           │
-- │    | where EventProcessedUtcTime >= ago(5m) | count;                   │
-- │    Debe retornar count > 0 (si = 0, verificar Event Stream)            │
-- └────────────────────────────────────────────────────────────────────────┘


-- 🎯 VENTAJAS DE ESTA SOLUCIÓN (Puntos de venta para el cliente):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ 1. SIN AGENTES: No requiere instalar software adicional en servidores  │
-- │    - Solo usa extensión nativa de PostgreSQL (pgaudit)                  │
-- │    - No consume CPU/memoria del servidor de base de datos              │
-- │                                                                         │
-- │ 2. TIEMPO REAL: Detección en 30-90 segundos                            │
-- │    - Logs fluyen automáticamente a Fabric vía Event Hub                │
-- │    - Procesamiento continuo con Stream Analytics                       │
-- │    - Alertas instantáneas con Data Activator                           │
-- │                                                                         │
-- │ 3. ESCALABLE: Funciona con cientos de servidores PostgreSQL            │
-- │    - Todos los servidores envían logs al mismo Event Hub               │
-- │    - KQL Database maneja millones de eventos por día                   │
-- │    - Queries optimizadas para grandes volúmenes de datos               │
-- │                                                                         │
-- │ 4. SIN CÓDIGO: Configuración point-and-click                           │
-- │    - Diagnostic Settings: 3 clicks en Azure Portal                     │
-- │    - Event Stream: Configuración visual en Fabric                      │
-- │    - Dashboard: Copy/paste queries KQL                                 │
-- │    - Alertas: Configuración visual en Data Activator                   │
-- │                                                                         │
-- │ 5. INTEGRABLE: Conexión con herramientas existentes                    │
-- │    - Emails automáticos (Exchange, Gmail, etc.)                        │
-- │    - Microsoft Teams notifications                                     │
-- │    - ServiceNow/Jira ticketing (vía Power Automate)                    │
-- │    - SIEM integration (Sentinel, Splunk, etc.)                         │
-- │                                                                         │
-- │ 6. COSTO-EFECTIVO: Parte de tu licencia Microsoft Fabric               │
-- │    - No requiere licencias adicionales de SIEM/monitoring              │
-- │    - Pricing basado en consumo (pay-as-you-go)                         │
-- │    - Rentable incluso para pequeñas implementaciones                   │
-- └────────────────────────────────────────────────────────────────────────┘


-- 🔐 CASOS DE USO REALES (Ejemplos para mostrar al cliente):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ CASO 1: Insider Threat Detection                                       │
-- │ - Empleado malicioso ejecuta 50 SELECTs para robar datos de clientes  │
-- │ - Anomalía 1 detecta actividad en 2 minutos                            │
-- │ - Alerta enviada a Security Team vía Teams                             │
-- │ - Se bloquea cuenta del empleado antes de exfiltrar datos              │
-- │                                                                         │
-- │ CASO 2: Ransomware Attack Prevention                                   │
-- │ - Ransomware intenta ejecutar DELETE masivo en tablas críticas         │
-- │ - Anomalía 2 detecta 10 DELETEs en 1 minuto                            │
-- │ - Alerta crítica enviada a DBA Team                                    │
-- │ - DBA hace rollback desde backup antes de pérdida total                │
-- │                                                                         │
-- │ CASO 3: SQL Injection Detection                                        │
-- │ - Atacante externo intenta SQL injection en aplicación web             │
-- │ - Genera 30 errores de sintaxis en 30 segundos                         │
-- │ - Anomalía 3 detecta error spike                                       │
-- │ - IP del atacante bloqueada en firewall automáticamente                │
-- │                                                                         │
-- │ CASO 4: Brute Force Attack Detection                                   │
-- │ - Botnet intenta 100 contraseñas en 5 minutos                          │
-- │ - TILE "Auth Failures" detecta 100 fallos desde misma IP               │
-- │ - IP agregada a blacklist de NSG automáticamente                       │
-- │ - Cuenta de usuario bloqueada preventivamente                          │
-- │                                                                         │
-- │ CASO 5: Misconfiguration Detection                                     │
-- │ - Aplicación con connection string incorrecta genera 500 errores/min   │
-- │ - Anomalía 3 detecta error spike                                       │
-- │ - Alerta enviada a Dev Team con detalles del error                     │
-- │ - Dev Team corrige configuración en 5 minutos (vs horas de downtime)   │
-- └────────────────────────────────────────────────────────────────────────┘


-- 📚 RECURSOS ADICIONALES (Para entregar al cliente post-demo):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ 📄 Documentación del Proyecto:                                         │
-- │    - README.md: Visión general del proyecto                            │
-- │    - docs/QUICKSTART.md: Guía de inicio rápido (5 min setup)           │
-- │    - docs/DEPLOYMENT-CHECKLIST.md: Lista de verificación completa      │
-- │    - docs/DASHBOARD-SETUP-GUIDE.md: Configurar dashboard paso a paso   │
-- │    - docs/REFLEX-ALERTS-CONFIG.md: Configurar alertas en Data Activator│
-- │    - docs/ALERTAS-QUERIES-ESPECIFICAS.md: Queries completas para alerts│
-- │                                                                         │
-- │ 📊 Queries KQL:                                                        │
-- │    - queries/kql-queries-PRODUCTION.kql: Queries de dashboard (main)   │
-- │    - queries/kql-queries-ENHANCED.kql: Queries avanzadas (opcional)    │
-- │    - queries/DEBUG-AUDIT-FORMAT.kql: Debugging pgaudit config          │
-- │    - queries/DIAGNOSTIC-AUDIT-CONFIG.kql: Validar configuración        │
-- │                                                                         │
-- │ 🧪 Scripts de Testing:                                                 │
-- │    - TEST-ANOMALY-TRIGGERS.sql: Este archivo (generar anomalías)       │
-- │    - queries/TEST-USER-DATABASE-IP.kql: Validar correlación            │
-- │                                                                         │
-- │ 🔗 Links Útiles:                                                       │
-- │    - pgaudit docs: https://github.com/pgaudit/pgaudit                  │
-- │    - Azure PostgreSQL: https://learn.microsoft.com/azure/postgresql    │
-- │    - Microsoft Fabric: https://learn.microsoft.com/fabric              │
-- │    - KQL reference: https://learn.microsoft.com/azure/data-explorer/kql│
-- └────────────────────────────────────────────────────────────────────────┘


-- 🎓 PRÓXIMOS PASOS POST-DEMO (Recomendaciones para el cliente):
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ 1. IMPLEMENTACIÓN INICIAL (Semana 1):                                  │
-- │    ☐ Habilitar pgaudit en servidor de prueba/staging                   │
-- │    ☐ Configurar Diagnostic Settings → Event Hub                        │
-- │    ☐ Crear Event Stream en Fabric                                      │
-- │    ☐ Validar ingesta de datos (tabla bronze_pssql_alllogs_nometrics)   │
-- │                                                                         │
-- │ 2. CONFIGURACIÓN DE DASHBOARD (Semana 1-2):                            │
-- │    ☐ Crear dashboard con queries de kql-queries-PRODUCTION.kql         │
-- │    ☐ Ejecutar tests de anomalías para validar funcionamiento           │
-- │    ☐ Ajustar thresholds según baseline de tu entorno                   │
-- │    ☐ Compartir dashboard con equipos de seguridad/DBA/DevOps           │
-- │                                                                         │
-- │ 3. CONFIGURACIÓN DE ALERTAS (Semana 2-3):                              │
-- │    ☐ Configurar alertas en Data Activator para las 3 anomalías         │
-- │    ☐ Definir destinatarios: Security, DBA, DevOps teams                │
-- │    ☐ Configurar canales de Teams para notificaciones                   │
-- │    ☐ (Opcional) Integrar con ServiceNow/Jira para ticketing            │
-- │                                                                         │
-- │ 4. REFINAMIENTO (Semana 3-4):                                          │
-- │    ☐ Analizar falsos positivos y ajustar thresholds                    │
-- │    ☐ Crear tabla UserContext/HostContext para enriquecer alertas       │
-- │    ☐ Configurar whitelist de IPs/usuarios conocidos                    │
-- │    ☐ Documentar runbooks de respuesta a incidentes                     │
-- │                                                                         │
-- │ 5. ROLLOUT A PRODUCCIÓN (Semana 4+):                                   │
-- │    ☐ Habilitar pgaudit en servidores de producción (uno a la vez)      │
-- │    ☐ Monitorear impacto en performance (<1% esperado)                  │
-- │    ☐ Validar que todas las anomalías se detectan correctamente         │
-- │    ☐ Entrenar equipos en uso del dashboard y respuesta a alertas       │
-- │                                                                         │
-- │ 6. MANTENIMIENTO CONTINUO (Mensual):                                   │
-- │    ☐ Revisar anomalías detectadas y validar si fueron verdaderos       │
-- │    ☐ Ajustar thresholds basados en patrones reales de uso              │
-- │    ☐ Agregar nuevas anomalías según necesidades del negocio            │
-- │    ☐ Revisar logs de alertas y optimizar canales de notificación       │
-- └────────────────────────────────────────────────────────────────────────┘

-- ============================================================================
-- FIN DEL SCRIPT DE PRUEBA
-- ============================================================================
