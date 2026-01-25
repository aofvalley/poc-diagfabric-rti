-- ============================================================================
-- TEST 2: ANOMALÍA 2 - Operaciones Destructivas Masivas
-- ============================================================================
-- 📊 Requisito: >5 operaciones destructivas en ventanas de 2 minutos
-- 🎯 Estrategia: Solo UPDATEs - no dependemos de la tabla existir
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Mass Destructive Operations
--    - OperationCount: 10+
--    - Operations: UPDATE
-- ============================================================================

-- ⚠️ FASE DESTRUCTIVA: 10 operaciones UPDATE en ráfaga
-- Usamos la tabla que ya existe de ejecuciones anteriores
-- Si no existe, los UPDATEs simplemente no afectarán filas (pero se ejecutan)

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
