-- ============================================================================
-- TEST 6: ANOMALÍA 6 - Enumeración Profunda de Schema (Deep Scan)
-- ============================================================================
-- 📊 Requisito: Detectar >10 queries a tablas de sistema en 5 minutos
-- 🎯 Estrategia: Ejecutar reconocimiento exhaustivo del schema
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Deep Schema Enumeration
--    - SystemTableQueries: 15+
--    - TablesScanned: pg_tables, pg_class, pg_attribute, pg_proc...
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
