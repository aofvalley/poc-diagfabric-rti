-- ============================================================================
-- TEST 3: ANOMALÍA 3 - Escalada de Errores Críticos
-- ============================================================================
-- 📊 Requisito: >15 errores críticos (ERROR/FATAL/PANIC) en 1 minuto
-- 🎯 Estrategia: Ejecutar 20 queries inválidas consecutivamente
-- ⏱️ Tiempo de ejecución: ~20 segundos
-- 📈 Resultado esperado en dashboard (1-2 min después):
--    - AnomalyType: Critical Error Spike
--    - ErrorCount: ~20
--    - ErrorTypes: Permission Error, Other Error
-- ============================================================================

-- ⚠️ IMPORTANTE: Estas queries generarán errores A PROPÓSITO

-- 🚨 FASE 1: Errores de tabla inexistente (código 42P01)
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

-- 🔍 FASE 2: Errores de columna inválida (código 42703)
SELECT columna_invalida FROM sales.customer;
SELECT * FROM sales.customer WHERE columna_invalida = 'test';
SELECT id, nombre_invalido FROM person.person;
SELECT direccion_inexistente FROM person.address;
SELECT codigo_erroneo FROM production.product;

-- 🔒 FASE 3: Más errores para alcanzar threshold de 15+ en 1 minuto
SELECT * FROM tabla_inexistente_11;
SELECT * FROM tabla_inexistente_12;
SELECT * FROM tabla_inexistente_13;
SELECT * FROM tabla_inexistente_14;
SELECT * FROM tabla_inexistente_15;
SELECT * FROM tabla_inexistente_16;
SELECT * FROM tabla_inexistente_17;
SELECT * FROM tabla_inexistente_18;

-- ✅ TOTAL: ~23 errores generados en ~20 segundos
