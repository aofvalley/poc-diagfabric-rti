-- ============================================================================
-- TEST 6: ANOMALÍA 6 - Enumeración Profunda de Schema (Deep Scan)
-- ============================================================================
-- 📊 Requisito: Detectar >10 queries a tablas de sistema en 5 minutos
-- 🎯 Estrategia: Ejecutar reconocimiento exhaustivo del schema
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Deep Schema Enumeration
--    - SystemTableQueries: 20+
--    - TablesScanned: pg_tables, pg_class, pg_attribute, pg_proc...
-- ⚠️ IMPORTANTE: Requiere pgaudit habilitado con log_catalog='on'
-- ============================================================================

-- 🔧 Verificación rápida de pgaudit (descomenta para debug)
-- SELECT setting FROM pg_settings WHERE name = 'pgaudit.log_catalog';

-- 🔍 FASE 1: Mapeo de estructura de tablas (5 queries)
SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname NOT LIKE 'pg_%' LIMIT 5;

SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE table_schema NOT LIKE 'pg_%' LIMIT 5;

SELECT relname, relkind FROM pg_class WHERE relkind = 'r' LIMIT 5;

SELECT nspname FROM pg_namespace WHERE nspname NOT LIKE 'pg_%' LIMIT 10;

SELECT tablename FROM pg_tables WHERE schemaname = 'public' LIMIT 10;

-- 🔍 FASE 2: Mapeo de columnas (5 queries)
SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema = 'public' LIMIT 10;

SELECT attname, atttypid FROM pg_attribute WHERE attnum > 0 LIMIT 10;

SELECT column_name, udt_name FROM information_schema.columns LIMIT 10;

SELECT attname, attnotnull FROM pg_attribute WHERE attrelid IN (SELECT oid FROM pg_class WHERE relkind = 'r') LIMIT 5;

SELECT table_name, column_name FROM information_schema.columns WHERE table_schema NOT IN ('pg_catalog', 'information_schema') LIMIT 10;

-- 🔍 FASE 3: Mapeo de funciones y procedimientos (4 queries)
SELECT proname, pronargs FROM pg_proc WHERE pronamespace != 11 LIMIT 5;

SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_schema NOT IN ('pg_catalog', 'information_schema') LIMIT 5;

SELECT proname, provolatile FROM pg_proc LIMIT 10;

SELECT specific_name, routine_type FROM information_schema.routines LIMIT 5;

-- 🔍 FASE 4: Mapeo de constraints y relaciones (4 queries)
SELECT conname, contype FROM pg_constraint LIMIT 5;

SELECT constraint_name, table_name, constraint_type FROM information_schema.table_constraints WHERE table_schema = 'public' LIMIT 5;

SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'public' LIMIT 5;

SELECT constraint_name, constraint_type FROM information_schema.table_constraints LIMIT 10;

-- 🔍 FASE 5: Información de usuarios y permisos (4 queries)
SELECT rolname, rolsuper FROM pg_roles LIMIT 5;

SELECT grantee, privilege_type, table_name FROM information_schema.table_privileges WHERE table_schema = 'public' LIMIT 5;

SELECT usename, usecreatedb FROM pg_user LIMIT 5;

SELECT rolname, rolcanlogin FROM pg_roles WHERE rolcanlogin = true LIMIT 5;

-- 🔍 FASE 6: Información adicional de sistema (3 queries)
SELECT datname, datistemplate FROM pg_database LIMIT 5;

SELECT spcname FROM pg_tablespace LIMIT 5;

SELECT extname, extversion FROM pg_extension LIMIT 5;

-- ✅ TOTAL: 25 queries a tablas de sistema en secuencia
