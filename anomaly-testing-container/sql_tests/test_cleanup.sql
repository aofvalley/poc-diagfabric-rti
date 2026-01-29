-- ============================================================================
-- POST-DEMO CLEANUP
-- ============================================================================
-- ⚠️ EXECUTE AFTER DEMO TO DELETE TEMPORARY TABLE
-- ============================================================================

-- Delete test table created in TEST 2
DROP TABLE IF EXISTS temp_test_anomaly CASCADE;

-- Verify it was deleted correctly
SELECT 
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'temp_test_anomaly')
        THEN '✅ Table temp_test_anomaly deleted successfully'
        ELSE '⚠️ Table still exists'
    END AS cleanup_status;
