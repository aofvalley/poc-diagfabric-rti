-- ============================================================================
-- TEST 5: ANOMALY 5 - Cross-Schema Reconnaissance (Lateral Movement)
-- ============================================================================
-- 📊 Requirement: Detect same user accessing >4 schemas in 10 minutes
-- 🎯 Strategy: Execute queries accessing multiple schemas
-- ⏱️ Execution time: ~30 seconds
-- 📈 Expected dashboard result (1-2 min after):
--    - AnomalyType: Cross-Schema Reconnaissance
--    - SchemasAccessed: 5+
--    - SchemaList: sales, production, person, humanresources, purchasing
-- ============================================================================

-- 🔍 Queries accessing multiple schemas in rapid succession
SELECT datname, encoding FROM pg_database WHERE datistemplate = false;
SELECT nspname FROM pg_namespace WHERE nspname NOT LIKE 'pg_%';

-- Access to different business schemas
SELECT * FROM sales.customer LIMIT 1;
SELECT * FROM production.product LIMIT 1;
SELECT * FROM person.person LIMIT 1;
SELECT * FROM humanresources.employee LIMIT 1;
SELECT * FROM purchasing.vendor LIMIT 1;

-- Queries for multi-schema structure reconnaissance
SELECT table_schema, COUNT(*) as table_count 
FROM information_schema.tables 
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
GROUP BY table_schema;

-- ✅ TOTAL: 8 cross-schema reconnaissance queries
