#!/usr/bin/env python3
"""
PostgreSQL Anomaly Testing Orchestrator v2.0
==============================================
Ejecuta automáticamente tests de anomalías contra PostgreSQL Flexible Servers
para demostración de detección con Microsoft Fabric.

NUEVA FUNCIONALIDAD v2.0:
- Tráfico de fondo normal continuo (simula baseline)
- Anomalías introducidas gradualmente
- Threading para ejecución concurrente
- Intensidad de tráfico configurable

Autor: Alfonso D.
Fecha: 2026-01-24
Versión: 2.0
"""

import os
import sys
import time
import glob
import random
import threading
from datetime import datetime
from typing import List, Tuple, Optional
import psycopg2
from psycopg2 import OperationalError, ProgrammingError
from colorama import Fore, Style, init
from dotenv import load_dotenv

# Cargar variables desde .env
load_dotenv()

# Inicializar colorama para Windows compatibility
init(autoreset=True)

# ============================================================================
# Configuración
# ============================================================================

class Config:
    """Configuración del orquestador de tests"""
    
    def __init__(self):
        self.servers = os.getenv('POSTGRES_SERVERS', '').split(',')
        self.servers = [s.strip() for s in self.servers if s.strip()]
        self.user = os.getenv('POSTGRES_USER', '')
        self.password = os.getenv('POSTGRES_PASSWORD', '')
        self.database = os.getenv('POSTGRES_DATABASE', 'adventureworks')
        self.port = int(os.getenv('POSTGRES_PORT', '5432'))
        
        # Configuración de tests de anomalías
        self.delay_between_tests = int(os.getenv('DELAY_BETWEEN_TESTS', '120'))
        self.enable_brute_force = os.getenv('ENABLE_BRUTE_FORCE', 'false').lower() == 'true'
        self.brute_force_attempts = int(os.getenv('BRUTE_FORCE_ATTEMPTS', '20'))
        
        # >>> NUEVO: Configuración de tráfico de fondo
        self.enable_background_traffic = os.getenv('ENABLE_BACKGROUND_TRAFFIC', 'true').lower() == 'true'
        self.background_traffic_intensity = os.getenv('BACKGROUND_TRAFFIC_INTENSITY', 'medium').lower()
        self.baseline_duration = int(os.getenv('BASELINE_DURATION', '180'))  # 3 min baseline
        self.anomaly_spacing = int(os.getenv('ANOMALY_SPACING', '300'))  # 5 min entre anomalías
        
        self.sql_tests_dir = os.path.join(os.path.dirname(__file__), 'sql_tests')
        
        # Configuración de intensidad de tráfico
        self.traffic_intensity_config = {
            'low': {'selects_per_min': 3, 'updates_per_min': 0.5, 'errors_per_5min': 1},
            'medium': {'selects_per_min': 6, 'updates_per_min': 1.5, 'errors_per_5min': 2},
            'high': {'selects_per_min': 12, 'updates_per_min': 3, 'errors_per_5min': 3}
        }
        
    def validate(self) -> Tuple[bool, str]:
        """Valida la configuración"""
        if not self.servers:
            return False, "❌ No se especificaron servidores PostgreSQL (POSTGRES_SERVERS)"
        if not self.user:
            return False, "❌ No se especificó usuario (POSTGRES_USER)"
        if not self.password:
            return False, "❌ No se especificó contraseña (POSTGRES_PASSWORD)"
        if not os.path.exists(self.sql_tests_dir):
            return False, f"❌ No se encontró directorio de tests: {self.sql_tests_dir}"
        if self.background_traffic_intensity not in self.traffic_intensity_config:
            return False, f"❌ Intensidad inválida: {self.background_traffic_intensity} (usa: low, medium, high)"
        return True, "✅ Configuración válida"


# ============================================================================
# Funciones de Utilidad
# ============================================================================

def print_banner():
    """Imprime banner de inicio"""
    print(f"\n{Fore.CYAN}{'='*80}")
    print(f"{Fore.CYAN}  PostgreSQL Anomaly Testing Orchestrator v2.0")
    print(f"{Fore.CYAN}  Con Simulación de Tráfico Normal - Para demos de Microsoft Fabric")
    print(f"{Fore.CYAN}{'='*80}{Style.RESET_ALL}\n")


def print_section(title: str):
    """Imprime título de sección"""
    print(f"\n{Fore.YELLOW}{'─'*80}")
    print(f"{Fore.YELLOW}  {title}")
    print(f"{Fore.YELLOW}{'─'*80}{Style.RESET_ALL}\n")


def get_connection(config: Config, server: str):
    """Crea una conexión a PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=server,
            port=config.port,
            database=config.database,
            user=config.user,
            password=config.password,
            connect_timeout=10,
            sslmode='require'
        )
        return conn
    except OperationalError as e:
        print(f"{Fore.RED}❌ Error de conexión a {server}: {e}{Style.RESET_ALL}")
        return None


def execute_sql_queries(conn, queries: List[str], allow_errors: bool = False) -> Tuple[int, int]:
    """
    Ejecuta una lista de queries SQL
    
    Returns:
        Tuple[queries_executed, queries_failed]
    """
    queries_executed = 0
    queries_failed = 0
    cursor = conn.cursor()
    
    for query in queries:
        if not query or query.strip().startswith('--'):
            continue
            
        try:
            cursor.execute(query)
            conn.commit()
            queries_executed += 1
        except (ProgrammingError, OperationalError):
            queries_failed += 1
            conn.rollback()
            if not allow_errors:
                pass  # Silently continue for background traffic
    
    cursor.close()
    return queries_executed, queries_failed


def execute_sql_file(conn, sql_file: str, allow_errors: bool = False) -> Tuple[bool, int, int]:
    """
    Ejecuta un archivo SQL completo
    """
    with open(sql_file, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    # Separar queries por punto y coma
    queries = [q.strip() for q in sql_content.split(';') if q.strip() and not q.strip().startswith('--')]
    
    queries_executed = 0
    queries_failed = 0
    cursor = conn.cursor()
    
    for query in queries:
        if not query or query.startswith('--'):
            continue
            
        try:
            cursor.execute(query)
            conn.commit()
            queries_executed += 1
        except (ProgrammingError, OperationalError) as e:
            queries_failed += 1
            if allow_errors:
                print(f"{Fore.YELLOW}.{Style.RESET_ALL}", end='', flush=True)
                conn.rollback()
            else:
                error_msg = str(e).lower()
                # Ignorar errores que son esperados en algunos tests
                if "does not exist" in error_msg or "already exists" in error_msg:
                    print(f"{Fore.YELLOW}⚠️ Warning: {e}{Style.RESET_ALL}")
                    conn.rollback()
                    # Continuar ejecutando
                else:
                    print(f"{Fore.RED}❌ Error ejecutando query: {e}{Style.RESET_ALL}")
                    conn.rollback()
                    cursor.close()
                    return False, queries_executed, queries_failed
    
    cursor.close()
    return True, queries_executed, queries_failed


# ============================================================================
# >>> NUEVO: Generador de Tráfico de Fondo
# ============================================================================

class BackgroundTrafficGenerator:
    """Genera tráfico normal de base de datos en background"""
    
    def __init__(self, config: Config, server: str):
        self.config = config
        self.server = server
        self.is_running = False
        self.thread = None
        self.queries_executed = 0
        self.errors_generated = 0
        
        # Cargar queries normales
        self.normal_queries = self._load_normal_queries()
        
    def _load_normal_queries(self) -> dict:
        """Carga queries normales del archivo SQL"""
        normal_traffic_file = os.path.join(self.config.sql_tests_dir, 'background_normal_traffic.sql')
        
        if not os.path.exists(normal_traffic_file):
            return {'selects': [], 'transactional': [], 'analytical': [], 'errors': []}
        
        with open(normal_traffic_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Separar por categorías (simplificado)
        queries = {
            'selects': [],
            'transactional': [],
            'analytical': [],
            'errors': []
        }
        
        # Queries individuales (separadas por ; y filtrar comentarios)
        all_queries = [q.strip() for q in content.split(';') if q.strip() and not q.strip().startswith('--')]
        
        # Clasificar queries (simplificado - asumimos orden del archivo)
        if len(all_queries) >= 13:
            queries['selects'] = all_queries[0:5]  # Query 1-5: SELECTs normales
            queries['transactional'] = all_queries[5:7]  # Query 6-7: INSERT, UPDATE
            queries['analytical'] = all_queries[7:10]  # Query 8-10: Analíticas
            queries['errors'] = all_queries[10:13]  # Query 11-13: Errores normales
        
        return queries
    
    def _run_traffic_loop(self):
        """Loop principal de tráfico de fondo"""
        intensity = self.config.traffic_intensity_config[self.config.background_traffic_intensity]
        
        while self.is_running:
            conn = get_connection(self.config, self.server)
            if not conn:
                time.sleep(30)
                continue
            
            try:
                # Ejecutar SELECTs normales
                num_selects = int(intensity['selects_per_min'] + random.uniform(-1, 1))
                num_selects = max(1, num_selects)
                
                selected_queries = random.sample(
                    self.normal_queries['selects'], 
                    min(num_selects, len(self.normal_queries['selects']))
                )
                
                executed, failed = execute_sql_queries(conn, selected_queries, allow_errors=True)
                self.queries_executed += executed
                
                # Ocasionalmente ejecutar transaccionales
                if random.random() < (intensity['updates_per_min'] / 60):
                    if self.normal_queries['transactional']:
                        trans_query = random.choice(self.normal_queries['transactional'])
                        execute_sql_queries(conn, [trans_query], allow_errors=True)
                        self.queries_executed += 1
                
                # Ocasionalmente ejecutar analíticas
                if random.random() < 0.1:  # 10% chance
                    if self.normal_queries['analytical']:
                        anal_query = random.choice(self.normal_queries['analytical'])
                        execute_sql_queries(conn, [anal_query], allow_errors=True)
                        self.queries_executed += 1
                
                # Ocasionalmente generar errores normales
                if random.random() < (intensity['errors_per_5min'] / 300):
                    if self.normal_queries['errors']:
                        error_query = random.choice(self.normal_queries['errors'])
                        execute_sql_queries(conn, [error_query], allow_errors=True)
                        self.errors_generated += 1
                
            except Exception:
                pass
            finally:
                conn.close()
            
            # Esperar tiempo aleatorio (~10-15 segundos entre ejecuciones)
            time.sleep(random.uniform(10, 15))
    
    def start(self):
        """Inicia el generador de tráfico de fondo"""
        if self.is_running:
            return
        
        self.is_running = True
        self.thread = threading.Thread(target=self._run_traffic_loop, daemon=True)
        self.thread.start()
        
        print(f"{Fore.GREEN}🚀 Tráfico de fondo iniciado{Style.RESET_ALL}")
        print(f"   Intensidad: {Fore.CYAN}{self.config.background_traffic_intensity}{Style.RESET_ALL}")
        intensity = self.config.traffic_intensity_config[self.config.background_traffic_intensity]
        print(f"   Configuración: {Fore.CYAN}~{int(intensity['selects_per_min'])} SELECTs/min, "
              f"~{int(intensity['updates_per_min'])} UPDATEs/min{Style.RESET_ALL}")
    
    def stop(self):
        """Detiene el tráfico de fondo"""
        if not self.is_running:
            return
        
        self.is_running = False
        if self.thread:
            self.thread.join(timeout=5)
        
        print(f"\n{Fore.CYAN}🛑 Tráfico de fondo detenido{Style.RESET_ALL}")
        print(f"   Total queries ejecutadas: {Fore.CYAN}{self.queries_executed}{Style.RESET_ALL}")
        print(f"   Errores normales generados: {Fore.YELLOW}{self.errors_generated}{Style.RESET_ALL}")


# ============================================================================
# Funciones de Ejecución de Tests
# ============================================================================

def run_test(config: Config, server: str, test_file: str, test_number: int, test_name: str) -> bool:
    """Ejecuta un test individual"""
    print(f"\n{Fore.RED}{'🔴'*3} ANOMALÍA INTRODUCIDA {'🔴'*3}{Style.RESET_ALL}")
    print(f"{Fore.GREEN}▶ TEST {test_number}: {test_name}{Style.RESET_ALL}")
    print(f"   Servidor: {Fore.CYAN}{server}{Style.RESET_ALL}")
    print(f"   Archivo: {Fore.CYAN}{os.path.basename(test_file)}{Style.RESET_ALL}")
    print(f"   Hora: {Fore.CYAN}{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{Style.RESET_ALL}")
    
    conn = get_connection(config, server)
    if not conn:
        return False
    
    try:
        allow_errors = "error_spike" in test_file
        success, executed, failed = execute_sql_file(conn, test_file, allow_errors)
        
        if allow_errors:
            print()
        
        if success or allow_errors:
            print(f"{Fore.GREEN}   ✅ Anomalía ejecutada{Style.RESET_ALL}")
            print(f"      Queries ejecutadas: {Fore.CYAN}{executed}{Style.RESET_ALL}")
            if failed > 0:
                print(f"      Errores generados: {Fore.YELLOW}{failed}{Style.RESET_ALL}")
        else:
            print(f"{Fore.RED}   ❌ Test fallido{Style.RESET_ALL}")
            return False
            
    except Exception as e:
        print(f"{Fore.RED}   ❌ Error inesperado: {e}{Style.RESET_ALL}")
        return False
    finally:
        conn.close()
    
    return True


def run_cleanup(config: Config, server: str):
    """Ejecuta limpieza post-demo"""
    print(f"\n{Fore.CYAN}🧹 Ejecutando limpieza post-demo...{Style.RESET_ALL}")
    
    cleanup_file = os.path.join(config.sql_tests_dir, 'test_cleanup.sql')
    if not os.path.exists(cleanup_file):
        print(f"{Fore.YELLOW}   ⚠️ No se encontró archivo de limpieza{Style.RESET_ALL}")
        return
    
    conn = get_connection(config, server)
    if not conn:
        return
    
    try:
        success, executed, failed = execute_sql_file(conn, cleanup_file)
        if success:
            print(f"{Fore.GREEN}   ✅ Limpieza completada{Style.RESET_ALL}")
        else:
            print(f"{Fore.YELLOW}   ⚠️ Limpieza parcialmente fallida{Style.RESET_ALL}")
    finally:
        conn.close()


# ============================================================================
# Main
# ============================================================================

def main():
    print_banner()
    
    # Cargar y validar configuración
    config = Config()
    is_valid, msg = config.validate()
    
    if not is_valid:
        print(f"{Fore.RED}{msg}{Style.RESET_ALL}")
        sys.exit(1)
    
    print(f"{Fore.GREEN}{msg}{Style.RESET_ALL}\n")
    
    # Mostrar configuración
    print_section("Configuración")
    print(f"   Servidores: {Fore.CYAN}{', '.join(config.servers)}{Style.RESET_ALL}")
    print(f"   Usuario: {Fore.CYAN}{config.user}{Style.RESET_ALL}")
    print(f"   Base de datos: {Fore.CYAN}{config.database}{Style.RESET_ALL}")
    print(f"   Tráfico de fondo: {Fore.CYAN}{'Habilitado' if config.enable_background_traffic else 'Deshabilitado'}{Style.RESET_ALL}")
    if config.enable_background_traffic:
        print(f"   Intensidad de tráfico: {Fore.CYAN}{config.background_traffic_intensity}{Style.RESET_ALL}")
        print(f"   Baseline inicial: {Fore.CYAN}{config.baseline_duration}s{Style.RESET_ALL}")
        print(f"   Espacio entre anomalías: {Fore.CYAN}{config.anomaly_spacing}s{Style.RESET_ALL}")
    
    # Obtener lista de tests SQL (ordenados)
    test_files = sorted(glob.glob(os.path.join(config.sql_tests_dir, 'test_[0-9]*.sql')))
    
    if not test_files:
        print(f"\n{Fore.RED}❌ No se encontraron archivos de test{Style.RESET_ALL}")
        sys.exit(1)
    
    print(f"\n   Anomalías programadas: {Fore.CYAN}{len(test_files)}{Style.RESET_ALL}")
    
    # Nombres descriptivos de los tests
    test_names = {
        "test_01": "Data Exfiltration",
        "test_02": "Mass Destructive Operations",
        "test_03": "Critical Error Spike",
        "test_04": "Privilege Escalation",
        "test_05": "Cross-Schema Reconnaissance",
        "test_06": "Deep Schema Enumeration",
        "test_07": "ML Baseline Deviation"
    }
    
    # Ejecutar demo en cada servidor
    for server in config.servers:
        print_section(f"Demo en servidor: {server}")
        
        # Probar conexión inicial
        conn = get_connection(config, server)
        if not conn:
            print(f"{Fore.RED}❌ No se pudo conectar al servidor. Saltando...{Style.RESET_ALL}")
            continue
        conn.close()
        print(f"{Fore.GREEN}✅ Conexión exitosa{Style.RESET_ALL}")
        
        # >>> INICIAR TRÁFICO DE FONDO
        traffic_gen = None
        if config.enable_background_traffic:
            traffic_gen = BackgroundTrafficGenerator(config, server)
            traffic_gen.start()
            
            # Establecer baseline
            print(f"\n{Fore.CYAN}⏱️  Estableciendo baseline de actividad normal...{Style.RESET_ALL}")
            print(f"{Fore.CYAN}   Duración: {config.baseline_duration}s (~{config.baseline_duration//60} minutos){Style.RESET_ALL}")
            print(f"{Fore.CYAN}   💡 Abre el dashboard de Fabric y observa el tráfico normal{Style.RESET_ALL}")
            time.sleep(config.baseline_duration)
        
        # Ejecutar anomalías gradualmente
        for idx, test_file in enumerate(test_files, 1):
            basename = os.path.basename(test_file)
            test_key = basename.split('_')[0] + '_' + basename.split('_')[1]
            test_name = test_names.get(test_key, basename)
            
            # Ejecutar anomalía
            success = run_test(config, server, test_file, idx, test_name)
            
            if not success:
                print(f"\n{Fore.YELLOW}⚠️ Continuando...{Style.RESET_ALL}")
            
            # Volver a normalidad (excepto último test)
            if idx < len(test_files):
                print(f"\n{Fore.GREEN}✅ Volviendo a actividad normal...{Style.RESET_ALL}")
                print(f"{Fore.CYAN}⏸️  Esperando {config.anomaly_spacing}s hasta próxima anomalía{Style.RESET_ALL}")
                print(f"{Fore.CYAN}   💡 Observa en Fabric cómo la anomalía desaparece y vuelve a normal{Style.RESET_ALL}")
                time.sleep(config.anomaly_spacing)
        
        # >>> DETENER TRÁFICO DE FONDO
        if traffic_gen:
            traffic_gen.stop()
        
        # Limpieza
        run_cleanup(config, server)
    
    # Resumen final
    print_section("Demo Completada")
    print(f"{Fore.GREEN}✅ Todas las anomalías han sido ejecutadas{Style.RESET_ALL}\n")
    print(f"{Fore.CYAN}📊 Resumen de la demo:{Style.RESET_ALL}")
    print(f"   - Tráfico normal estableció baseline")
    print(f"   - 7 anomalías introducidas gradualmente")
    print(f"   - Dashboard mostró contraste entre normal vs anómalo")
    print(f"\n{Fore.YELLOW}⏱️  Los logs tardan 1-2 minutos en aparecer en Fabric{Style.RESET_ALL}\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{Fore.YELLOW}⚠️  Demo interrumpida por el usuario{Style.RESET_ALL}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Fore.RED}❌ Error fatal: {e}{Style.RESET_ALL}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
