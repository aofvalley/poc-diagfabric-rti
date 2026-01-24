-- ============================================================================
-- TEST 4: ANOMALÍA 4 - Escalada de Privilegios (Privilege Escalation)
-- ============================================================================
-- 📊 Requisito: Detectar >3 operaciones de privilegios en 5 minutos
-- 🎯 Estrategia: Ejecutar secuencia de GRANTs sospechosa
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Privilege Escalation
--    - PrivilegeOpsCount: 6+
--    - Operations: GRANT, REVOKE, CREATE ROLE
-- ============================================================================

-- 🏗️ PREPARACIÓN: Limpiar roles previos si existen (revocando privilegios primero)
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales FROM test_analyst_v3;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales FROM test_developer_v3;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales FROM test_admin_v3;

DROP ROLE IF EXISTS test_analyst_v3;

DROP ROLE IF EXISTS test_developer_v3;

DROP ROLE IF EXISTS test_admin_v3;

-- Crear roles nuevos
CREATE ROLE test_analyst_v3;

CREATE ROLE test_developer_v3;

CREATE ROLE test_admin_v3;

-- ⚠️ FASE SOSPECHOSA: Ejecutar 6 operaciones de privilegios EN MENOS DE 5 MINUTOS
GRANT SELECT ON ALL TABLES IN SCHEMA sales TO test_analyst_v3;

GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA sales TO test_developer_v3;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales TO test_admin_v3;

GRANT test_analyst_v3 TO test_developer_v3;

GRANT test_developer_v3 TO test_admin_v3;

REVOKE ALL ON SCHEMA public FROM test_analyst_v3;

-- ✅ TOTAL: 6 operaciones de privilegios en ráfaga

-- 🧹 LIMPIEZA: Revocar privilegios y eliminar roles
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales FROM test_analyst_v3;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales FROM test_developer_v3;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales FROM test_admin_v3;

REVOKE test_analyst_v3 FROM test_developer_v3;

REVOKE test_developer_v3 FROM test_admin_v3;

DROP ROLE IF EXISTS test_analyst_v3;

DROP ROLE IF EXISTS test_developer_v3;

DROP ROLE IF EXISTS test_admin_v3;
