-- ============================================================================
-- TEST 2: ANOMALY 2 - Massive Destructive Operations
-- ============================================================================
-- 📊 Requirement: >5 destructive operations within 2 minute windows
-- 🎯 Strategy: CREATE + INSERT + UPDATEs + DELETEs to generate destructive activity
-- ⏱️ Execution time: ~30 seconds
-- 📈 Expected dashboard result (1-2 min after):
--    - AnomalyType: Mass Destructive Operations
--    - OperationCount: 10+
--    - Operations: UPDATE, DELETE
-- ============================================================================

-- 🔧 PREPARATION: Create test table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.temp_anomaly_test (
    id SERIAL PRIMARY KEY,
    test_value VARCHAR(255),
    last_modified TIMESTAMP DEFAULT NOW()
);

-- Insert data if table is empty
INSERT INTO public.temp_anomaly_test (test_value) 
SELECT 'initial_value_' || generate_series(1, 10)
WHERE NOT EXISTS (SELECT 1 FROM public.temp_anomaly_test LIMIT 1);

-- ⚠️ DESTRUCTIVE PHASE: 10 UPDATE operations in rapid succession
UPDATE public.temp_anomaly_test SET test_value = 'batch1_update1', last_modified = NOW() WHERE id = 1;

UPDATE public.temp_anomaly_test SET test_value = 'batch1_update2', last_modified = NOW() WHERE id = 2;

UPDATE public.temp_anomaly_test SET test_value = 'batch1_update3', last_modified = NOW() WHERE id = 3;

UPDATE public.temp_anomaly_test SET test_value = 'batch1_update4', last_modified = NOW() WHERE id = 4;

UPDATE public.temp_anomaly_test SET test_value = 'batch1_update5', last_modified = NOW() WHERE id = 5;

UPDATE public.temp_anomaly_test SET test_value = 'batch1_update6', last_modified = NOW() WHERE id = 6;

UPDATE public.temp_anomaly_test SET test_value = 'batch1_update7', last_modified = NOW() WHERE id = 7;

UPDATE public.temp_anomaly_test SET test_value = 'batch1_update8', last_modified = NOW() WHERE id = 8;

UPDATE public.temp_anomaly_test SET test_value = 'batch2_update1', last_modified = NOW() WHERE id = 1;

UPDATE public.temp_anomaly_test SET test_value = 'batch2_update2', last_modified = NOW() WHERE id = 2;

-- ✅ TOTAL: 10 UPDATE operations executed
