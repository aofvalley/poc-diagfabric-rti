-- ============================================================================
-- TRÁFICO NORMAL DE BASE DE DATOS - Simulación de Actividad Baseline
-- ============================================================================
-- Propósito: Generar queries normales que NO disparen anomalías
-- Uso: Ejecutadas en loop como tráfico de fondo durante la demo
-- ============================================================================

-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORÍA 1: SELECTS NORMALES (Actividad de lectura típica)
-- ════════════════════════════════════════════════════════════════════════════
-- Threshold Fabric: >15 SELECTs en 5 min dispara anomalía
-- Nuestro objetivo: 3-5 SELECTs por minuto (seguro)

-- Query 1: Lookup de cliente individual
SELECT * FROM sales.customer WHERE customerid = 29825 LIMIT 1;

-- Query 2: Consulta de productos por categoría
SELECT p.productid, p.name, p.listprice 
FROM production.product p 
WHERE p.productsubcategoryid = 1 
LIMIT 10;

-- Query 3: Pedidos recientes de un cliente
SELECT o.salesorderid, o.orderdate, o.totaldue
FROM sales.salesorderheader o
WHERE o.customerid = 29485
ORDER BY o.orderdate DESC
LIMIT 5;

-- Query 4: Información de empleado
SELECT e.businessentityid, p.firstname, p.lastname, e.jobtitle
FROM humanresources.employee e
JOIN person.person p ON e.businessentityid = p.businessentityid
LIMIT 1;

-- Query 5: Productos más vendidos (query analítica simple)
SELECT p.name, SUM(sod.orderqty) as total_quantity
FROM sales.salesorderdetail sod
JOIN production.product p ON sod.productid = p.productid
GROUP BY p.name
ORDER BY total_quantity DESC
LIMIT 5;


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORÍA 2: OPERACIONES TRANSACCIONALES NORMALES
-- ════════════════════════════════════════════════════════════════════════════
-- Threshold Fabric: >5 UPDATEs/DELETEs en 2 min dispara anomalía
-- Nuestro objetivo: 1-2 operaciones por 2 min (seguro)

-- Query 6: INSERT de auditoría (simula logging de aplicación)
-- Nota: Requiere tabla de auditoría, se crea si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'app_audit_log') THEN
        CREATE TABLE app_audit_log (
            id SERIAL PRIMARY KEY,
            action VARCHAR(50),
            username VARCHAR(100),
            timestamp TIMESTAMP DEFAULT NOW()
        );
    END IF;
END $$;

INSERT INTO app_audit_log (action, username) 
VALUES ('user_login', current_user);

-- Query 7: UPDATE de última actividad (simula mantenimiento de sesión)
UPDATE app_audit_log 
SET timestamp = NOW() 
WHERE username = current_user 
  AND id = (SELECT MAX(id) FROM app_audit_log WHERE username = current_user);


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORÍA 3: QUERIES ANALÍTICAS (Reportes y dashboards)
-- ════════════════════════════════════════════════════════════════════════════

-- Query 8: Resumen de ventas por mes
SELECT 
    DATE_TRUNC('month', orderdate) as month,
    COUNT(*) as total_orders,
    SUM(totaldue) as total_revenue
FROM sales.salesorderheader
WHERE orderdate >= NOW() - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', orderdate)
ORDER BY month DESC
LIMIT 12;

-- Query 9: Top 10 clientes por volumen de compra
SELECT 
    c.customerid,
    COUNT(o.salesorderid) as total_orders,
    SUM(o.totaldue) as lifetime_value
FROM sales.customer c
JOIN sales.salesorderheader o ON c.customerid = o.customerid
GROUP BY c.customerid
ORDER BY lifetime_value DESC
LIMIT 10;

-- Query 10: Inventario bajo alertas
SELECT 
    p.name,
    pi.quantity,
    pi.locationid
FROM production.productinventory pi
JOIN production.product p ON pi.productid = p.productid
WHERE pi.quantity < 100
ORDER BY pi.quantity ASC
LIMIT 10;


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORÍA 4: ERRORES NORMALES (Ocasionales, NO disparan anomalía)
-- ════════════════════════════════════════════════════════════════════════════
-- Threshold Fabric: >15 errores por minuto dispara anomalía
-- Nuestro objetivo: 1-2 errores cada 5 minutos (seguro)

-- Error 1: Constraint violation (simula intento de insertar duplicado)
-- Este error es esperado y normal en aplicaciones
DO $$
BEGIN
    -- Intentar insertar con ID que podría existir
    INSERT INTO app_audit_log (id, action, username) 
    VALUES (1, 'test', 'system');
EXCEPTION
    WHEN unique_violation THEN
        -- Error capturado y manejado normalmente
        NULL;
END $$;

-- Error 2: Query con typo ocasional (simula error de usuario/aplicación)
-- Esto genera un error pero es normal en producción
DO $$
BEGIN
    EXECUTE 'SELECT * FROM sales.customer WHERE nonexistent_column = 1';
EXCEPTION
    WHEN undefined_column THEN
        -- Error capturado y manejado
        NULL;
END $$;


-- ════════════════════════════════════════════════════════════════════════════
-- CATEGORÍA 5: MANTENIMIENTO Y METADATA
-- ════════════════════════════════════════════════════════════════════════════

-- Query 11: Check de salud de conexión
SELECT current_database(), current_user, NOW() as current_time;

-- Query 12: Estadísticas de tabla (simula monitoreo)
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'sales'
LIMIT 5;

-- Query 13: Sesiones activas (monitoring típico)
SELECT COUNT(*) as active_connections
FROM pg_stat_activity
WHERE state = 'active';


-- ════════════════════════════════════════════════════════════════════════════
-- RESUMEN DE QUERIES NORMALES
-- ════════════════════════════════════════════════════════════════════════════
-- Total: ~13 queries diferentes
-- Categorías:
--   - SELECTs normales: 5 queries
--   - Transaccionales: 2 queries (INSERT, UPDATE)
--   - Analíticas: 3 queries (reportes)
--   - Errores normales: 2 errores ocasionales
--   - Mantenimiento: 3 queries
--
-- Ejecución recomendada en loop:
--   - Ejecutar 3-5 queries aleatorias cada minuto
--   - Esto genera tráfico realista sin disparar anomalías
--   - Establece baseline para ML (Anomalía 7)
-- ════════════════════════════════════════════════════════════════════════════
