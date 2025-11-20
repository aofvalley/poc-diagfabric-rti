-- ============================================================================
-- SCRIPT DE PRUEBA: Generar Anomalías para Dashboard PostgreSQL
-- ============================================================================
-- Propósito: Ejecutar queries que activen las 3 anomalías del dashboard
-- Base de datos: adventureworks (con pgaudit habilitado)
-- Ejecutar con: psql o Azure Data Studio
-- Versión: 2.0 (Validada 20/11/2025 - Alineada con queries PRODUCTION)
-- ============================================================================
--
-- 📋 PREREQUISITOS ANTES DE LA DEMO:
-- 1. ✅ Extensión pgaudit instalada: SELECT * FROM pg_extension WHERE extname = 'pgaudit';
-- 2. ✅ pgaudit configurado: SHOW pgaudit.log; (debe ser 'ALL' o incluir 'READ, WRITE')
-- 3. ✅ Diagnostic Settings habilitado en Azure Portal (PostgreSQLLogs enabled)
-- 4. ✅ Event Stream funcionando en Fabric (verificar ingesta)
-- 5. ✅ Tabla bronze_pssql_alllogs_nometrics recibiendo datos
-- 6. ✅ Dashboard creado con queries de kql-queries-PRODUCTION.kql
-- 7. ✅ Alertas configuradas en Data Activator (opcional para demo)
--
-- 🎯 FLUJO DE LA DEMO:
-- 1. Ejecutar TEST 1 (Data Exfiltration) → Esperar 1-2 min → Mostrar dashboard
-- 2. Ejecutar TEST 2 (Destructive Ops) → Esperar 1-2 min → Mostrar dashboard
-- 3. Ejecutar TEST 3 (Error Spike) → Esperar 1-2 min → Mostrar dashboard
-- 4. (Opcional) Ejecutar TEST 4 (Auth Failures) con script externo
-- 5. Mostrar alertas disparadas en Data Activator (si configuradas)
--
-- ⏱️ TIEMPO TOTAL DE DEMO: ~10-15 minutos (3-4 min por test + explicación)
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
-- Luego, abre el dashboard y muestra la Anomalía 3 con:
-- - ErrorCount >= 20
-- - ErrorTypes = "Other Error" (o "Permission Error" si probaste permisos)
-- - ErrorCodes = "42P01, 42703" (undefined_table, undefined_column)
-- - SampleErrors con mensajes de las queries fallidas
-- - User/Database/SourceHost identificados
-- ============================================================================


-- ============================================================================
-- TEST 4: TILE - Fallos de Autenticación (Authentication Failures)
-- ============================================================================
-- 📊 Requisito: Detectar intentos de brute force (>3 fallos por usuario/host)
--             (Query: kql-queries-PRODUCTION.kql líneas 424-445)
-- 🎯 Estrategia: Intentar conectarse con contraseña incorrecta 10-20 veces
-- ⏱️ Tiempo de ejecución: ~1-2 minutos
-- 📈 Resultado esperado en dashboard:
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
-- │ ✅ TILE "Fallos de Autenticación" (Solo si ejecutaste TEST 4)          │
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
-- ☐ 10. (Opcional) Ejecutar TEST 4 con script bash/powershell/python
-- ☐ 11. Verificar que User/Database/Host NO son "UNKNOWN" (correlación OK)
-- ☐ 12. Limpiar tabla temp_test_anomaly al final de la demo

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
