#!/usr/bin/env python3
"""
Script de Setup para pgAudit
===============================
Verifica y habilita pgaudit en PostgreSQL Flexible Servers.

Uso:
    python setup_pgaudit.py

Autor: Alfonso D.
Fecha: 2026-01-29
"""

import os
import sys
import psycopg2
from colorama import Fore, Style, init
from dotenv import load_dotenv

# Cargar variables desde .env
load_dotenv()

# Inicializar colorama
init(autoreset=True)

def print_banner():
    """Imprime banner de inicio"""
    print(f"\n{Fore.CYAN}{'='*80}")
    print(f"{Fore.CYAN}  pgAudit Setup - PostgreSQL Auditing Configuration")
    print(f"{Fore.CYAN}{'='*80}{Style.RESET_ALL}\n")


def get_connection(server: str):
    """Crea una conexión a PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=server,
            port=int(os.getenv('POSTGRES_PORT', '5432')),
            database=os.getenv('POSTGRES_DATABASE', 'adventureworks'),
            user=os.getenv('POSTGRES_USER', ''),
            password=os.getenv('POSTGRES_PASSWORD', ''),
            connect_timeout=10,
            sslmode='require'
        )
        return conn
    except psycopg2.OperationalError as e:
        print(f"{Fore.RED}❌ Error de conexión: {e}{Style.RESET_ALL}")
        return None


def check_pgaudit_installed(cursor):
    """Verifica si pgaudit está instalado"""
    cursor.execute("""
        SELECT COUNT(*) as count 
        FROM pg_extension 
        WHERE extname = 'pgaudit'
    """)
    result = cursor.fetchone()
    return result[0] > 0


def get_pgaudit_settings(cursor):
    """Obtiene la configuración actual de pgaudit"""
    settings = {}
    try:
        cursor.execute("SHOW pgaudit.log")
        settings['pgaudit.log'] = cursor.fetchone()[0]
    except:
        settings['pgaudit.log'] = 'NOT SET'
    
    try:
        cursor.execute("SHOW pgaudit.log_catalog")
        settings['pgaudit.log_catalog'] = cursor.fetchone()[0]
    except:
        settings['pgaudit.log_catalog'] = 'NOT SET'
    
    try:
        cursor.execute("SHOW pgaudit.log_parameter")
        settings['pgaudit.log_parameter'] = cursor.fetchone()[0]
    except:
        settings['pgaudit.log_parameter'] = 'NOT SET'
    
    return settings


def configure_pgaudit(conn, database_name: str):
    """Configura pgaudit a nivel de base de datos"""
    cursor = conn.cursor()
    
    try:
        # Configurar pgaudit para loguear READ (SELECT), WRITE (INSERT/UPDATE/DELETE)
        print(f"\n{Fore.YELLOW}⚙️  Configurando pgaudit a nivel de base de datos...{Style.RESET_ALL}")
        
        cursor.execute(f"ALTER DATABASE {database_name} SET pgaudit.log = 'READ, WRITE, DDL, MISC'")
        print(f"{Fore.GREEN}   ✅ pgaudit.log = 'READ, WRITE, DDL, MISC'{Style.RESET_ALL}")
        
        cursor.execute(f"ALTER DATABASE {database_name} SET pgaudit.log_catalog = 'on'")
        print(f"{Fore.GREEN}   ✅ pgaudit.log_catalog = 'on'{Style.RESET_ALL}")
        
        cursor.execute(f"ALTER DATABASE {database_name} SET pgaudit.log_parameter = 'on'")
        print(f"{Fore.GREEN}   ✅ pgaudit.log_parameter = 'on'{Style.RESET_ALL}")
        
        conn.commit()
        
        print(f"\n{Fore.GREEN}✅ Configuración de pgaudit aplicada correctamente{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}⚠️  IMPORTANTE: Necesitas RECONECTAR a la base de datos para que los cambios surtan efecto{Style.RESET_ALL}")
        
        return True
        
    except Exception as e:
        print(f"{Fore.RED}❌ Error configurando pgaudit: {e}{Style.RESET_ALL}")
        conn.rollback()
        return False
    finally:
        cursor.close()


def verify_configuration(cursor):
    """Verifica la configuración después de reconectar"""
    print(f"\n{Fore.CYAN}🔍 Verificando configuración actual...{Style.RESET_ALL}")
    
    cursor.execute("""
        SELECT name, setting, source
        FROM pg_settings
        WHERE name LIKE 'pgaudit%'
        ORDER BY name
    """)
    
    results = cursor.fetchall()
    
    if results:
        print(f"\n{Fore.CYAN}Configuración de pgaudit:{Style.RESET_ALL}")
        for name, setting, source in results:
            color = Fore.GREEN if source in ('database', 'configuration file') else Fore.YELLOW
            print(f"   {color}{name}: {setting} (source: {source}){Style.RESET_ALL}")
    else:
        print(f"{Fore.RED}⚠️  No se encontró configuración de pgaudit{Style.RESET_ALL}")


def main():
    print_banner()
    
    # Leer configuración
    servers = os.getenv('POSTGRES_SERVERS', '').split(',')
    servers = [s.strip() for s in servers if s.strip()]
    database = os.getenv('POSTGRES_DATABASE', 'adventureworks')
    
    if not servers:
        print(f"{Fore.RED}❌ No se especificaron servidores (POSTGRES_SERVERS en .env){Style.RESET_ALL}")
        sys.exit(1)
    
    print(f"Servidores a configurar: {Fore.CYAN}{', '.join(servers)}{Style.RESET_ALL}")
    print(f"Base de datos: {Fore.CYAN}{database}{Style.RESET_ALL}\n")
    
    for server in servers:
        print(f"\n{Fore.YELLOW}{'─'*80}")
        print(f"{Fore.YELLOW}  Configurando servidor: {server}")
        print(f"{Fore.YELLOW}{'─'*80}{Style.RESET_ALL}\n")
        
        # Conectar
        conn = get_connection(server)
        if not conn:
            print(f"{Fore.RED}❌ No se pudo conectar al servidor. Saltando...{Style.RESET_ALL}")
            continue
        
        try:
            cursor = conn.cursor()
            
            # Verificar si pgaudit está instalado
            print(f"{Fore.CYAN}🔍 Verificando instalación de pgaudit...{Style.RESET_ALL}")
            if check_pgaudit_installed(cursor):
                print(f"{Fore.GREEN}✅ pgaudit está instalado{Style.RESET_ALL}")
            else:
                print(f"{Fore.RED}❌ pgaudit NO está instalado{Style.RESET_ALL}")
                print(f"{Fore.YELLOW}   💡 Instálalo en Azure Portal: Server Parameters → shared_preload_libraries = 'pgaudit'{Style.RESET_ALL}")
                cursor.close()
                conn.close()
                continue
            
            # Mostrar configuración actual
            settings = get_pgaudit_settings(cursor)
            print(f"\n{Fore.CYAN}Configuración actual:{Style.RESET_ALL}")
            for key, value in settings.items():
                print(f"   {key}: {Fore.YELLOW}{value}{Style.RESET_ALL}")
            
            # Configurar pgaudit
            success = configure_pgaudit(conn, database)
            
            if success:
                # Cerrar y reconectar para verificar
                cursor.close()
                conn.close()
                
                print(f"\n{Fore.CYAN}🔄 Reconectando para verificar cambios...{Style.RESET_ALL}")
                conn = get_connection(server)
                if conn:
                    cursor = conn.cursor()
                    verify_configuration(cursor)
                    cursor.close()
            
        except Exception as e:
            print(f"{Fore.RED}❌ Error inesperado: {e}{Style.RESET_ALL}")
        finally:
            if conn:
                conn.close()
    
    # Resumen final
    print(f"\n{Fore.CYAN}{'='*80}")
    print(f"{Fore.CYAN}  Setup Completado")
    print(f"{Fore.CYAN}{'='*80}{Style.RESET_ALL}\n")
    print(f"{Fore.GREEN}✅ Próximos pasos:{Style.RESET_ALL}")
    print(f"   1. Verifica que la configuración se aplicó correctamente")
    print(f"   2. Ejecuta el script de anomalías: python anomaly_runner.py")
    print(f"   3. Revisa los logs en Microsoft Fabric Real-Time Intelligence")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Fore.YELLOW}⚠️  Setup interrumpido por el usuario{Style.RESET_ALL}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Fore.RED}❌ Error fatal: {e}{Style.RESET_ALL}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
