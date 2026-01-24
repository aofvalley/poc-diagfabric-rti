-- ============================================================================
-- LIMPIEZA POST-DEMO
-- ============================================================================
-- ⚠️ EJECUTAR DESPUÉS DE LA DEMO PARA ELIMINAR TABLA TEMPORAL
-- ============================================================================

-- Eliminar tabla de prueba creada en TEST 2
DROP TABLE IF EXISTS temp_test_anomaly CASCADE;

-- Verificar que se eliminó correctamente
SELECT 
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'temp_test_anomaly')
        THEN '✅ Tabla temp_test_anomaly eliminada correctamente'
        ELSE '⚠️ La tabla aún existe'
    END AS cleanup_status;
