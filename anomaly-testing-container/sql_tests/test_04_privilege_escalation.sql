-- ============================================================================
-- TEST 4: ANOMALY 4 - Privilege Escalation
-- ============================================================================
-- 📊 Requirement: Detect >3 privilege operations in 5 minutes
-- 🎯 Strategy: Create roles first, then execute GRANTs in rapid succession
-- ⏱️ Execution time: ~30 seconds
-- 📈 Expected dashboard result (1-2 min after):
--    - AnomalyType: Privilege Escalation
--    - PrivilegeOpsCount: 10+
--    - Operations: GRANT, REVOKE, CREATE ROLE
-- ============================================================================

-- 🏗️ PREPARATION: Clean up previous roles if they exist
DROP ROLE IF EXISTS anomaly_test_analyst;
DROP ROLE IF EXISTS anomaly_test_developer;
DROP ROLE IF EXISTS anomaly_test_admin;
DROP ROLE IF EXISTS anomaly_test_readonly;

-- 🏗️ Create new roles (4 CREATE ROLE operations)
CREATE ROLE anomaly_test_analyst;
CREATE ROLE anomaly_test_developer;
CREATE ROLE anomaly_test_admin;
CREATE ROLE anomaly_test_readonly;

-- ⚠️ SUSPICIOUS PHASE: Execute multiple GRANTs WITHIN 5 MINUTES
-- Grant 1: Read permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anomaly_test_analyst;

-- Grant 2: Write permissions
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO anomaly_test_developer;

-- Grant 3: Full permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anomaly_test_admin;

-- Grant 4: Role inheritance
GRANT anomaly_test_analyst TO anomaly_test_developer;

-- Grant 5: More inheritance
GRANT anomaly_test_developer TO anomaly_test_admin;

-- Grant 6: Schema permissions
GRANT USAGE ON SCHEMA public TO anomaly_test_readonly;

-- Grant 7: Specific SELECT permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anomaly_test_readonly;

-- Revoke 1: Revoke permissions
REVOKE ALL ON SCHEMA public FROM anomaly_test_analyst;

-- Revoke 2: Another revoke
REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM anomaly_test_developer;

-- ✅ TOTAL: 13 privilege operations (4 CREATE + 7 GRANT + 2 REVOKE)

-- 🧹 FINAL CLEANUP: Delete test roles
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
