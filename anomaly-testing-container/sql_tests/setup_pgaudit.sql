-- ============================================================================
-- SETUP: Verificación y Habilitación de pgAudit
-- ============================================================================
-- 🎯 Propósito: Asegurar que pgaudit esté habilitado correctamente
-- 📋 Ejecutar ANTES de las pruebas de anomalías
-- ============================================================================

-- Paso 1: Verificar si pgaudit está instalado en la base de datos
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ pgaudit está instalado'
        ELSE '❌ pgaudit NO está instalado'
    END as status
FROM pg_extension 
WHERE extname = 'pgaudit';

-- Paso 2: Instalar pgaudit si no está (requiere permisos de superusuario)
-- Descomenta la siguiente línea si necesitas instalarlo:
-- CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Paso 3: Verificar configuración actual de pgaudit
SHOW pgaudit.log;
SHOW pgaudit.log_catalog;
SHOW pgaudit.log_parameter;
SHOW pgaudit.log_statement_once;

-- Paso 4: Configurar pgaudit a nivel de base de datos (si no está configurado)
-- Estas configuraciones se aplican a la base de datos actual
-- Nota: Requiere privilegios de superusuario o ser owner de la base de datos

-- Habilitar logging de todas las operaciones
ALTER DATABASE adventureworks SET pgaudit.log = 'READ, WRITE, DDL, MISC';

-- Habilitar logging de consultas a catálogos del sistema
ALTER DATABASE adventureworks SET pgaudit.log_catalog = 'on';

-- Incluir parámetros en los logs
ALTER DATABASE adventureworks SET pgaudit.log_parameter = 'on';

-- Paso 5: Para aplicar los cambios, reconectar o ejecutar:
-- pg_reload_conf() -- solo si tienes permisos

-- Paso 6: Verificar que los cambios se aplicaron
SELECT 
    name,
    setting,
    source
FROM pg_settings
WHERE name LIKE 'pgaudit%';

-- Paso 7: Verificar configuración actual del logging de PostgreSQL
SHOW log_statement;
SHOW log_min_duration_statement;

-- Paso 8: Opcional - Configurar logging más detallado a nivel de base de datos
ALTER DATABASE adventureworks SET log_statement = 'all';
-- ALTER DATABASE adventureworks SET log_min_duration_statement = 0; -- Descomenta si quieres loguear todas las queries

-- ============================================================================
-- ℹ️ NOTAS IMPORTANTES:
-- ============================================================================
-- 1. Después de ejecutar este script, RECONECTA a la base de datos
-- 2. Las configuraciones ALTER DATABASE solo aplican a nuevas conexiones
-- 3. Si usas Azure PostgreSQL Flexible Server, pgaudit debería estar 
--    preinstalado, pero necesitas habilitarlo en Server Parameters
-- 4. Para verificar que funciona, ejecuta una query y revisa los logs
-- ============================================================================

-- Verificación final: Ejecutar una query de prueba
SELECT 'Test pgaudit logging' as test;
SELECT tablename FROM pg_tables WHERE schemaname = 'public' LIMIT 1;
