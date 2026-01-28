-- ============================================================================
-- TEST 7: ANOMALIA 7 - Desviacion de Baseline ML (ML Baseline Deviation)
-- ============================================================================
-- Requisito: Generar actividad que desvie del baseline ML
-- Estrategia: Ejecutar MUCHAS queries para crear spike de actividad
-- Tiempo de ejecucion: ~2 minutos
-- Resultado esperado en dashboard (5-10 min despues):
--    - AnomalyType: ML Baseline Deviation
--    - DeviationScore: >1.5 (>2.0 = HIGH, >3.0 = CRITICAL)
--    - AnomalyDirection: Above Normal
-- ============================================================================

SELECT current_timestamp as access_time, 'ML SPIKE TEST - START' as test_type;

-- RAFAGA 1: Accesos masivos a tablas de negocio (20 queries)
SELECT * FROM sales.customer LIMIT 1;
SELECT * FROM sales.salesorderheader LIMIT 1;
SELECT * FROM sales.salesorderdetail LIMIT 1;
SELECT * FROM sales.store LIMIT 1;
SELECT * FROM sales.salesperson LIMIT 1;
SELECT * FROM person.person LIMIT 1;
SELECT * FROM person.address LIMIT 1;
SELECT * FROM person.emailaddress LIMIT 1;
SELECT * FROM person.phonenumbertype LIMIT 1;
SELECT * FROM person.businessentity LIMIT 1;
SELECT * FROM production.product LIMIT 1;
SELECT * FROM production.productcategory LIMIT 1;
SELECT * FROM production.productsubcategory LIMIT 1;
SELECT * FROM production.productmodel LIMIT 1;
SELECT * FROM production.productinventory LIMIT 1;
SELECT * FROM humanresources.employee LIMIT 1;
SELECT * FROM humanresources.department LIMIT 1;
SELECT * FROM humanresources.shift LIMIT 1;
SELECT * FROM purchasing.vendor LIMIT 1;
SELECT * FROM purchasing.purchaseorderheader LIMIT 1;

-- RAFAGA 2: Queries de conteo (10 queries mas)
SELECT COUNT(*) FROM sales.customer;
SELECT COUNT(*) FROM sales.salesorderheader;
SELECT COUNT(*) FROM person.person;
SELECT COUNT(*) FROM production.product;
SELECT COUNT(*) FROM humanresources.employee;
SELECT COUNT(*) FROM purchasing.vendor;
SELECT COUNT(*) FROM sales.salesorderdetail;
SELECT COUNT(*) FROM person.address;
SELECT COUNT(*) FROM production.productinventory;
SELECT COUNT(*) FROM humanresources.department;

-- RAFAGA 3: Queries con agregaciones (10 queries mas)
SELECT MAX(totaldue) FROM sales.salesorderheader;
SELECT MIN(totaldue) FROM sales.salesorderheader;
SELECT AVG(listprice) FROM production.product;
SELECT SUM(orderqty) FROM sales.salesorderdetail;
SELECT COUNT(DISTINCT customerid) FROM sales.customer;
SELECT MAX(modifieddate) FROM person.person;
SELECT MIN(hiredate) FROM humanresources.employee;
SELECT AVG(standardcost) FROM production.product;
SELECT SUM(quantity) FROM production.productinventory;
SELECT COUNT(DISTINCT departmentid) FROM humanresources.department;

-- RAFAGA 4: Queries con JOINs (10 queries mas - mas carga)
SELECT c.customerid, p.firstname FROM sales.customer c 
    JOIN person.person p ON c.personid = p.businessentityid LIMIT 5;
SELECT o.salesorderid, c.customerid FROM sales.salesorderheader o 
    JOIN sales.customer c ON o.customerid = c.customerid LIMIT 5;
SELECT e.businessentityid, d.name FROM humanresources.employee e 
    JOIN humanresources.employeedepartmenthistory edh ON e.businessentityid = edh.businessentityid
    JOIN humanresources.department d ON edh.departmentid = d.departmentid LIMIT 5;
SELECT p.productid, pc.name FROM production.product p 
    JOIN production.productsubcategory ps ON p.productsubcategoryid = ps.productsubcategoryid
    JOIN production.productcategory pc ON ps.productcategoryid = pc.productcategoryid LIMIT 5;
SELECT v.businessentityid, pod.productid FROM purchasing.vendor v 
    JOIN purchasing.purchaseorderheader poh ON v.businessentityid = poh.vendorid
    JOIN purchasing.purchaseorderdetail pod ON poh.purchaseorderid = pod.purchaseorderid LIMIT 5;
SELECT a.addressid, sp.name FROM person.address a 
    JOIN person.stateprovince sp ON a.stateprovinceid = sp.stateprovinceid LIMIT 5;
SELECT p.businessentityid, e.emailaddressid FROM person.person p 
    JOIN person.emailaddress e ON p.businessentityid = e.businessentityid LIMIT 5;
SELECT soh.salesorderid, sod.productid, p.name FROM sales.salesorderheader soh
    JOIN sales.salesorderdetail sod ON soh.salesorderid = sod.salesorderid
    JOIN production.product p ON sod.productid = p.productid LIMIT 5;
SELECT c.customerid, a.city FROM sales.customer c 
    JOIN person.businessentityaddress bea ON c.personid = bea.businessentityid
    JOIN person.address a ON bea.addressid = a.addressid LIMIT 5;
SELECT e.businessentityid, p.firstname, p.lastname FROM humanresources.employee e
    JOIN person.person p ON e.businessentityid = p.businessentityid LIMIT 5;

SELECT current_timestamp as access_time, 'ML SPIKE TEST - END' as test_type;

-- TOTAL: 52 queries ejecutadas en rafaga (~1-2 minutos)
