-- ============================================================================
-- TEST 4: ANOMALÍA 4 - Escalada de Privilegios (Privilege Escalation)
-- ============================================================================
-- 📊 Requisito: Detectar >3 operaciones de privilegios en 5 minutos
-- 🎯 Estrategia: Crear roles primero, luego ejecutar GRANTs en ráfaga
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Privilege Escalation
--    - PrivilegeOpsCount: 10+
--    - Operations: GRANT, REVOKE, CREATE ROLE
-- ============================================================================

-- 🏗️ PREPARACIÓN: Limpiar roles previos si existen
DROP ROLE IF EXISTS anomaly_test_analyst;
DROP ROLE IF EXISTS anomaly_test_developer;
DROP ROLE IF EXISTS anomaly_test_admin;
DROP ROLE IF EXISTS anomaly_test_readonly;

-- 🏗️ Crear roles nuevos (4 operaciones CREATE ROLE)
CREATE ROLE anomaly_test_analyst;
CREATE ROLE anomaly_test_developer;
CREATE ROLE anomaly_test_admin;
CREATE ROLE anomaly_test_readonly;

-- ⚠️ FASE SOSPECHOSA: Ejecutar múltiples GRANTs EN MENOS DE 5 MINUTOS
-- Grant 1: Permisos de lectura
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anomaly_test_analyst;

-- Grant 2: Permisos de escritura
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO anomaly_test_developer;

-- Grant 3: Permisos completos
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anomaly_test_admin;

-- Grant 4: Herencia de roles
GRANT anomaly_test_analyst TO anomaly_test_developer;

-- Grant 5: Más herencia
GRANT anomaly_test_developer TO anomaly_test_admin;

-- Grant 6: Permisos de schema
GRANT USAGE ON SCHEMA public TO anomaly_test_readonly;

-- Grant 7: Permisos SELECT específicos
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anomaly_test_readonly;

-- Revoke 1: Revocar permisos
REVOKE ALL ON SCHEMA public FROM anomaly_test_analyst;

-- Revoke 2: Otro revoke
REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM anomaly_test_developer;

-- ✅ TOTAL: 13 operaciones de privilegios (4 CREATE + 7 GRANT + 2 REVOKE)

-- 🧹 LIMPIEZA FINAL: Eliminar roles de prueba
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anomaly_test_analyst;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anomaly_test_developer;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anomaly_test_admin;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anomaly_test_readonly;
REVOKE anomaly_test_analyst FROM anomaly_test_developer;
REVOKE anomaly_test_developer FROM anomaly_test_admin;

DROP ROLE IF EXISTS anomaly_test_analyst;
DROP ROLE IF EXISTS anomaly_test_developer;
DROP ROLE IF EXISTS anomaly_test_admin;
DROP ROLE IF EXISTS anomaly_test_readonly;
