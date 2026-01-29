-- ============================================================================
-- TEST 3: ANOMALY 3 - Critical Error Spike
-- ============================================================================
-- 📊 Requirement: >15 critical errors (ERROR/FATAL/PANIC) in 1 minute
-- 🎯 Strategy: Execute 20 invalid queries consecutively
-- ⏱️ Execution time: ~20 seconds
-- 📈 Expected dashboard result (1-2 min after):
--    - AnomalyType: Critical Error Spike
--    - ErrorCount: ~20
--    - ErrorTypes: Permission Error, Other Error
-- ============================================================================

-- ⚠️ IMPORTANT: These queries will generate errors ON PURPOSE

-- 🚨 PHASE 1: Non-existent table errors (code 42P01)
SELECT * FROM tabla_que_no_existe_1;
SELECT * FROM tabla_que_no_existe_2;
SELECT * FROM tabla_que_no_existe_3;
SELECT * FROM tabla_que_no_existe_4;
SELECT * FROM tabla_que_no_existe_5;
SELECT * FROM tabla_que_no_existe_6;
SELECT * FROM tabla_que_no_existe_7;
SELECT * FROM tabla_que_no_existe_8;
SELECT * FROM tabla_que_no_existe_9;
SELECT * FROM tabla_que_no_existe_10;

-- 🔍 PHASE 2: Invalid column errors (code 42703)
SELECT columna_invalida FROM sales.customer;
SELECT * FROM sales.customer WHERE columna_invalida = 'test';
SELECT id, nombre_invalido FROM person.person;
SELECT direccion_inexistente FROM person.address;
SELECT codigo_erroneo FROM production.product;

-- 🔒 PHASE 3: More errors to reach threshold of 15+ in 1 minute
SELECT * FROM tabla_inexistente_11;
SELECT * FROM tabla_inexistente_12;
SELECT * FROM tabla_inexistente_13;
SELECT * FROM tabla_inexistente_14;
SELECT * FROM tabla_inexistente_15;
SELECT * FROM tabla_inexistente_16;
SELECT * FROM tabla_inexistente_17;
SELECT * FROM tabla_inexistente_18;

-- ✅ TOTAL: ~23 errors generated in ~20 seconds
