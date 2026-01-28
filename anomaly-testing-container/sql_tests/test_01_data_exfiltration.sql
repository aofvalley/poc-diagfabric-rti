-- ============================================================================
-- TEST 1: ANOMALIA 1 - Extraccion Masiva de Datos (Data Exfiltration)
-- ============================================================================
-- Requisito: >15 SELECTs en 5 minutos
-- Estrategia: Ejecutar 20 SELECTs consecutivos para activar la alerta
-- Tiempo de ejecucion: ~30 segundos
-- Resultado esperado en dashboard (1-2 min despues):
--    - AnomalyType: Potential Data Exfiltration
--    - SelectCount: ~20
--    - TablesAccessed: Lista de tablas accedidas
-- ============================================================================

-- FASE 1: Reconocimiento de tablas del sistema (patron tipico de ataque)
SELECT * FROM pg_catalog.pg_tables WHERE schemaname = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_class WHERE relkind = 'r' LIMIT 1;
SELECT * FROM information_schema.tables WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM information_schema.columns WHERE table_schema = 'public' LIMIT 1;
SELECT * FROM pg_catalog.pg_namespace LIMIT 1;
SELECT * FROM pg_catalog.pg_attribute LIMIT 1;

-- FASE 2: Extraccion de datos de negocio (simular exfiltracion real)
SELECT * FROM sales.customer LIMIT 100;
SELECT * FROM sales.salesorderheader LIMIT 100;
SELECT * FROM sales.salesorderdetail LIMIT 100;
SELECT * FROM person.person LIMIT 100;
SELECT * FROM person.address LIMIT 100;
SELECT * FROM production.product LIMIT 100;
SELECT * FROM humanresources.employee LIMIT 100;
SELECT * FROM purchasing.vendor LIMIT 100;

-- FASE 3: Queries de conteo (completar threshold de 15+)
SELECT COUNT(*) FROM sales.customer;
SELECT COUNT(*) FROM sales.salesorderheader;
SELECT COUNT(*) FROM production.product;
SELECT COUNT(*) FROM person.person;
SELECT COUNT(*) FROM person.address;
SELECT COUNT(*) FROM humanresources.employee;

-- TOTAL: 20 SELECTs ejecutados en ~30 segundos
