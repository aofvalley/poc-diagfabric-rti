-- ============================================================================
-- TEST 1: ANOMALY 1 - Massive Data Extraction (Data Exfiltration)
-- ============================================================================
-- Requirement: >15 SELECTs in 5 minutes
-- Strategy: Execute 20 consecutive SELECTs to trigger alert
-- Execution time: ~30 seconds
-- Expected dashboard result (1-2 min after):
--    - AnomalyType: Potential Data Exfiltration
--    - SelectCount: ~20
--    - TablesAccessed: List of accessed tables
-- ============================================================================

-- PHASE 1: System table recognition (typical attack pattern)
SELECT * FROM pg_catalog.pg_tables WHERE schemaname = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_class WHERE relkind = 'r' LIMIT 1;
SELECT * FROM information_schema.tables WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM information_schema.columns WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_namespace LIMIT 1;
SELECT * FROM pg_catalog.pg_attribute LIMIT 1;

-- PHASE 2: Business data extraction (simulate actual exfiltration)
SELECT * FROM sales.customer LIMIT 100;
SELECT * FROM sales.salesorderheader LIMIT 100;
SELECT * FROM sales.salesorderdetail LIMIT 100;
SELECT * FROM person.person LIMIT 100;
SELECT * FROM person.address LIMIT 100;
SELECT * FROM production.product LIMIT 100;
SELECT * FROM humanresources.employee LIMIT 100;
SELECT * FROM purchasing.vendor LIMIT 100;

-- PHASE 3: Count queries (complete threshold of 15+)
SELECT COUNT(*) FROM sales.customer;
SELECT COUNT(*) FROM sales.salesorderheader;
SELECT COUNT(*) FROM production.product;
SELECT COUNT(*) FROM person.person;
SELECT COUNT(*) FROM person.address;
SELECT COUNT(*) FROM humanresources.employee;

-- TOTAL: 20 SELECTs executed in ~30 seconds
