-- ============================================================================
-- TEST 5: ANOMALÍA 5 - Reconocimiento Cross-Schema (Lateral Movement)
-- ============================================================================
-- 📊 Requisito: Detectar mismo usuario accediendo >4 schemas en 10 minutos
-- 🎯 Estrategia: Ejecutar queries que acceden a múltiples schemas
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Cross-Schema Reconnaissance
--    - SchemasAccessed: 5+
--    - SchemaList: sales, production, person, humanresources, purchasing
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
