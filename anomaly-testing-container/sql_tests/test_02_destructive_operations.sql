-- ============================================================================
-- TEST 2: ANOMALÍA 2 - Operaciones Destructivas Masivas
-- ============================================================================
-- 📊 Requisito: >5 operaciones destructivas en ventanas de 2 minutos
-- 🎯 Estrategia: CREATE + INSERT + UPDATEs + DELETEs para generar actividad destructiva
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Mass Destructive Operations
--    - OperationCount: 10+
--    - Operations: UPDATE, DELETE
-- ============================================================================

-- 🔧 PREPARACIÓN: Crear tabla de test si no existe
CREATE TABLE IF NOT EXISTS public.temp_anomaly_test (
    id SERIAL PRIMARY KEY,
    test_value VARCHAR(255),
    last_modified TIMESTAMP DEFAULT NOW()
);

-- Insertar datos si la tabla está vacía
INSERT INTO public.temp_anomaly_test (test_value) 
SELECT 'initial_value_' || generate_series(1, 10)
WHERE NOT EXISTS (SELECT 1 FROM public.temp_anomaly_test LIMIT 1);

-- ⚠️ FASE DESTRUCTIVA: 10 operaciones UPDATE en ráfaga
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

-- ✅ TOTAL: 10 operaciones UPDATE ejecutadas
