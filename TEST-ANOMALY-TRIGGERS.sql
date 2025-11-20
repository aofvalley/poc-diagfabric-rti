-- ============================================================================
-- SCRIPT DE PRUEBA: Generar Anomalías para Dashboard PostgreSQL
-- ============================================================================
-- Propósito: Ejecutar queries que activen las 3 anomalías del dashboard
-- Base de datos: adventureworks (con pgaudit habilitado)
-- Ejecutar con: psql o Azure Data Studio
-- ============================================================================

-- ============================================================================
-- TEST 1: ANOMALÍA 1 - Extracción Masiva de Datos (Data Exfiltration)
-- ============================================================================
-- Requisito: >15 SELECTs en 5 minutos
-- Estrategia: Ejecutar 20 SELECTs consecutivos para activar la alerta
-- ============================================================================

-- Reconocimiento de tablas del sistema (patrón típico de ataque)
SELECT * FROM pg_catalog.pg_tables WHERE schemaname = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_class WHERE relkind = 'r' LIMIT 1;
SELECT * FROM information_schema.tables WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM information_schema.columns WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_namespace LIMIT 1;
SELECT * FROM pg_catalog.pg_attribute LIMIT 1;

-- Consultas a tablas de negocio (simular extracción de datos)
SELECT * FROM sales.customer LIMIT 100;
SELECT * FROM sales.salesorderheader LIMIT 100;
SELECT * FROM sales.salesorderdetail LIMIT 100;
SELECT * FROM person.person LIMIT 100;
SELECT * FROM person.address LIMIT 100;
SELECT * FROM production.product LIMIT 100;
SELECT * FROM humanresources.employee LIMIT 100;
SELECT * FROM purchasing.vendor LIMIT 100;

-- Queries adicionales para alcanzar el threshold de 15+
SELECT COUNT(*) FROM sales.customer;
SELECT COUNT(*) FROM sales.salesorderheader;
SELECT COUNT(*) FROM production.product;
SELECT COUNT(*) FROM person.person;

-- Mensaje esperado en dashboard:
-- AnomalyType: Potential Data Exfiltration
-- SelectCount: ~20
-- TablesAccessed: pg_tables, pg_class, information_schema.tables, customer, salesorderheader, etc.
-- SampleQueries: Primeras 3 queries ejecutadas


-- ============================================================================
-- TEST 2: ANOMALÍA 2 - Operaciones Destructivas Masivas
-- ============================================================================
-- Requisito: >5 operaciones destructivas en ventanas de 2 minutos
-- Estrategia: Crear tabla temporal y ejecutar 6 UPDATEs/DELETEs
-- ============================================================================

-- Crear tabla temporal para pruebas
DROP TABLE IF EXISTS temp_test_anomaly CASCADE;
CREATE TABLE temp_test_anomaly (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insertar datos de prueba
INSERT INTO temp_test_anomaly (name) VALUES 
    ('Test 1'), ('Test 2'), ('Test 3'), ('Test 4'), ('Test 5'),
    ('Test 6'), ('Test 7'), ('Test 8'), ('Test 9'), ('Test 10');

-- Ejecutar 6 operaciones destructivas (activará la anomalía)
UPDATE temp_test_anomaly SET name = 'Updated 1' WHERE id = 1;
UPDATE temp_test_anomaly SET name = 'Updated 2' WHERE id = 2;
UPDATE temp_test_anomaly SET name = 'Updated 3' WHERE id = 3;
DELETE FROM temp_test_anomaly WHERE id = 4;
DELETE FROM temp_test_anomaly WHERE id = 5;
UPDATE temp_test_anomaly SET name = 'Updated 6' WHERE id = 6;

-- Mensaje esperado en dashboard:
-- AnomalyType: Mass Destructive Operations
-- OperationCount: 6
-- Operations: UPDATE, DELETE
-- TablesAffected: temp_test_anomaly
-- SampleMessages: Queries UPDATE/DELETE ejecutadas


-- ============================================================================
-- TEST 3: ANOMALÍA 3 - Escalada de Errores Críticos
-- ============================================================================
-- Requisito: >15 errores por minuto
-- Estrategia: Ejecutar 20 queries inválidas consecutivamente
-- ============================================================================

-- Ejecutar queries que generen errores (tabla inexistente)
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

-- Errores de sintaxis
SELECT columna_invalida FROM sales.customer;
SELECT * FROM sales.customer WHERE columna_invalida = 'test';
SELECT id, nombre_invalido FROM person.person;

-- Errores de permisos (si aplica)
-- SET ROLE restricted_user; -- Descomentar si tienes un usuario sin permisos
-- SELECT * FROM pg_authid; -- Tabla restringida
-- SELECT * FROM pg_shadow; -- Tabla restringida

-- Más errores para alcanzar threshold de 15+
SELECT * FROM tabla_inexistente_11;
SELECT * FROM tabla_inexistente_12;
SELECT * FROM tabla_inexistente_13;
SELECT * FROM tabla_inexistente_14;
SELECT * FROM tabla_inexistente_15;
SELECT * FROM tabla_inexistente_16;
SELECT * FROM tabla_inexistente_17;

-- Mensaje esperado en dashboard:
-- AnomalyType: Critical Error Spike
-- ErrorCount: ~20
-- ErrorTypes: Permission Error, Other Error
-- ErrorCodes: 42P01 (undefined_table), 42703 (undefined_column)


-- ============================================================================
-- TEST 4: TILE 6 - Fallos de Autenticación
-- ============================================================================
-- IMPORTANTE: Este test NO se puede simular desde una conexión autenticada
-- Para generar fallos de autenticación, debes:
--
-- OPCIÓN 1 - psql con contraseña incorrecta (ejecutar en terminal):
-- psql -h advpsqlfxuk.postgres.database.azure.com -U test_user -d adventureworks -W
-- (introducir contraseña incorrecta 5 veces)
--
-- OPCIÓN 2 - Script Python con intentos fallidos:
-- import psycopg2
-- for i in range(10):
--     try:
--         psycopg2.connect(
--             host="advpsqlfxuk.postgres.database.azure.com",
--             database="adventureworks",
--             user="test_user",
--             password="wrong_password"
--         )
--     except Exception as e:
--         print(f"Intento {i+1} fallido")
--
-- Mensaje esperado en dashboard:
-- User: test_user
-- SourceHost: tu_ip
-- FailedAttempts: 10
-- ThreatLevel: 🟠 HIGH
-- ============================================================================


-- ============================================================================
-- LIMPIEZA (ejecutar después de las pruebas)
-- ============================================================================
DROP TABLE IF EXISTS temp_test_anomaly CASCADE;

-- ============================================================================
-- VERIFICACIÓN DE RESULTADOS
-- ============================================================================
-- 1. Espera 1-2 minutos para que los logs se ingieran en Fabric
-- 2. Verifica el dashboard en Fabric:
--    - Tile 1 (ANOMALÍA 1): Debe mostrar ~20 SELECTs con TablesAccessed y SampleQueries
--    - Tile 2 (ANOMALÍA 2): Debe mostrar 6 operaciones destructivas sobre temp_test_anomaly
--    - Tile 3 (ANOMALÍA 3): Debe mostrar ~20 errores con códigos 42P01, 42703
--    - Tile 4 (TOP USUARIOS): Debe mostrar tu usuario con alta actividad
--    - Tile 5 (TOP HOSTS): Debe mostrar tu IP con conexiones
--    - Tile 6 (AUTH FAILURES): Solo si ejecutaste intentos fallidos externos
--
-- 3. Verifica las queries de diagnóstico:
--    - TEST 9: Tu processId debe aparecer en "👤 USUARIO REAL" (si User = UNKNOWN, investigar)
--    - TEST 8: Cobertura de sessionInfo debe ser >50%
--    - TEST 7: Usa tu processId para ver el historial completo de la sesión
-- ============================================================================


-- ============================================================================
-- NOTAS ADICIONALES
-- ============================================================================
-- - Si las anomalías NO aparecen, verifica:
--   1. Extensión pgaudit instalada: SELECT * FROM pg_extension WHERE extname = 'pgaudit';
--   2. Configuración pgaudit: SHOW pgaudit.log; (debe ser 'ALL' o incluir 'READ, WRITE')
--   3. Diagnostic Settings habilitado en Azure Portal
--   4. Event Stream funcionando correctamente en Fabric
--   5. Tabla bronze_pssql_alllogs_nometrics recibiendo datos
--
-- - Thresholds actuales:
--   * ANOMALÍA 1: >15 SELECTs en 5 minutos (filtro: backend_type = 'client backend')
--   * ANOMALÍA 2: >5 operaciones destructivas en ventanas de 2 minutos
--   * ANOMALÍA 3: >15 errores por minuto
--   * TILE 6: >3 fallos de autenticación por usuario/host
--
-- - Para ajustar los thresholds, editar archivo: kql-queries-PRODUCTION.kql
-- ============================================================================
