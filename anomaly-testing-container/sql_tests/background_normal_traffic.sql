-- ============================================================================
-- NORMAL DATABASE TRAFFIC - Baseline Activity Simulation
-- ============================================================================
-- Purpose: Generate normal queries that do NOT trigger anomalies
-- Usage: Executed in loop as background traffic during demo
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORY 1: NORMAL SELECTS (Typical read activity)
-- ════════════════════════════════════════════════════════════════════════════
-- Fabric Threshold: >15 SELECTs in 5 min triggers anomaly
-- Our goal: 3-5 SELECTs per minute (safe)

-- Query 1: Individual customer lookup
SELECT * FROM sales.customer WHERE customerid = 29825 LIMIT 1;

-- Query 2: Products by category
SELECT p.productid, p.name, p.listprice 
FROM production.product p 
WHERE p.productsubcategoryid = 1 
LIMIT 10;

-- Query 3: Recent customer orders
SELECT o.salesorderid, o.orderdate, o.totaldue
FROM sales.salesorderheader o
WHERE o.customerid = 29485
ORDER BY o.orderdate DESC
LIMIT 5;

-- Query 4: Employee information
SELECT e.businessentityid, p.firstname, p.lastname, e.jobtitle
FROM humanresources.employee e
JOIN person.person p ON e.businessentityid = p.businessentityid
LIMIT 1;

-- Query 5: Top selling products (simple analytic query)
SELECT p.name, SUM(sod.orderqty) as total_quantity
FROM sales.salesorderdetail sod
JOIN production.product p ON sod.productid = p.productid
GROUP BY p.name
ORDER BY total_quantity DESC
LIMIT 5;


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORY 2: NORMAL TRANSACTIONAL OPERATIONS
-- ════════════════════════════════════════════════════════════════════════════
-- Fabric Threshold: >5 UPDATEs/DELETEs in 2 min triggers anomaly
-- Our goal: 1-2 operations per 2 min (safe)

-- Query 6: Audit logging (simulates application logging)
-- Note: Requires audit table, created if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'app_audit_log') THEN
        CREATE TABLE app_audit_log (
            id SERIAL PRIMARY KEY,
            action VARCHAR(50),
            username VARCHAR(100),
            timestamp TIMESTAMP DEFAULT NOW()
        );
    END IF;
END $$;

INSERT INTO app_audit_log (action, username) 
VALUES ('user_login', current_user);

-- Query 7: Update last activity (simulates session maintenance)
UPDATE app_audit_log 
SET timestamp = NOW() 
WHERE username = current_user 
  AND id = (SELECT MAX(id) FROM app_audit_log WHERE username = current_user);


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORY 3: ANALYTIC QUERIES (Reports and dashboards)
-- ════════════════════════════════════════════════════════════════════════════

-- Query 8: Sales summary by month
SELECT 
    DATE_TRUNC('month', orderdate) as month,
    COUNT(*) as total_orders,
    SUM(totaldue) as total_revenue
FROM sales.salesorderheader
WHERE orderdate >= NOW() - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', orderdate)
ORDER BY month DESC
LIMIT 12;

-- Query 9: Top 10 customers by purchase volume
SELECT 
    c.customerid,
    COUNT(o.salesorderid) as total_orders,
    SUM(o.totaldue) as lifetime_value
FROM sales.customer c
JOIN sales.salesorderheader o ON c.customerid = o.customerid
GROUP BY c.customerid
ORDER BY lifetime_value DESC
LIMIT 10;

-- Query 10: Low inventory alerts
SELECT 
    p.name,
    pi.quantity,
    pi.locationid
FROM production.productinventory pi
JOIN production.product p ON pi.productid = p.productid
WHERE pi.quantity < 100
ORDER BY pi.quantity ASC
LIMIT 10;


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORY 4: NORMAL ERRORS (Occasional, do NOT trigger anomaly)
-- ════════════════════════════════════════════════════════════════════════════
-- Fabric Threshold: >15 errors per minute triggers anomaly
-- Our goal: 1-2 errors every 5 minutes (safe)

-- Error 1: Constraint violation (simulates duplicate insert attempt)
-- This error is expected and normal in applications
DO $$
BEGIN
    -- Attempt to insert with ID that might exist
    INSERT INTO app_audit_log (id, action, username) 
    VALUES (1, 'test', 'system');
EXCEPTION
    WHEN unique_violation THEN
        -- Error caught and handled normally
        NULL;
END $$;

-- Error 2: Query with occasional typo (simulates user/application error)
-- This generates an error but is normal in production
DO $$
BEGIN
    EXECUTE 'SELECT * FROM sales.customer WHERE nonexistent_column = 1';
EXCEPTION
    WHEN undefined_column THEN
        -- Error caught and handled
        NULL;
END $$;


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORY 5: MAINTENANCE AND METADATA
-- ════════════════════════════════════════════════════════════════════════════

-- Query 11: Connection health check
SELECT current_database(), current_user, NOW() as current_time;

-- Query 12: Table statistics (simulates monitoring)
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'sales'
LIMIT 5;

-- Query 13: Active sessions (typical monitoring)
SELECT COUNT(*) as active_connections
FROM pg_stat_activity
WHERE state = 'active';


-- ════════════════════════════════════════════════════════════════════════════
-- SUMMARY OF NORMAL QUERIES
-- ════════════════════════════════════════════════════════════════════════════
-- Total: ~13 different queries
-- Categories:
--   - Normal SELECTs: 5 queries
--   - Transactional: 2 queries (INSERT, UPDATE)
--   - Analytics: 3 queries (reports)
--   - Normal errors: 2 errors occasionally
--   - Maintenance: 3 queries
--
-- Recommended execution in loop:
--   - Execute 3-5 random queries every minute
--   - This generates realistic traffic without triggering anomalies
--   - Establishes baseline for ML (Anomaly 7)
-- ════════════════════════════════════════════════════════════════════════════
