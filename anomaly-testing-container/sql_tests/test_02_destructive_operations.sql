-- ============================================================================
-- TEST 2: ANOMALÍA 2 - Operaciones Destructivas Masivas
-- ============================================================================
-- 📊 Requisito: >5 operaciones destructivas en ventanas de 2 minutos
-- 🎯 Estrategia: Usar tabla existente de AdventureWorks para UPDATEs/DELETEs
-- ⏱️ Tiempo de ejecución: ~30 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Mass Destructive Operations
--    - OperationCount: 6
--    - Operations: UPDATE, DELETE
-- ============================================================================

-- ⚠️ FASE DESTRUCTIVA: Ejecutar 6 operaciones destructivas en tabla real
-- Usamos sales.customer que es una tabla real de AdventureWorks

-- Update 1: Modificar registro 1
UPDATE sales.customer SET modifieddate = NOW() WHERE customerid = 1;

-- Update 2: Modificar registro 2
UPDATE sales.customer SET modifieddate = NOW() WHERE customerid = 11000;

-- Update 3: Modificar registro 3
UPDATE sales.customer SET modifieddate = NOW() WHERE customerid = 11001;

-- Update 4: Modificar registro 4
UPDATE sales.customer SET modifieddate = NOW() WHERE customerid = 11002;

-- Update 5: Modificar registro 5
UPDATE sales.customer SET modifieddate = NOW() WHERE customerid = 11003;

-- Update 6: Modificar registro 6
UPDATE sales.customer SET modifieddate = NOW() WHERE customerid = 11004;

-- ✅ TOTAL: 6 operaciones destructivas (UPDATEs) ejecutadas en < 2 minutos
-- Nota: Usamos UPDATEs en lugar de DELETEs para no afectar datos reales
