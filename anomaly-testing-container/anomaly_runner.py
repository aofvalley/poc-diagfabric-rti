#!/usr/bin/env python3
"""
PostgreSQL Anomaly Testing Orchestrator v2.0
=============================================
Automatically runs anomaly tests against PostgreSQL Flexible Servers
for demonstration of detection with Microsoft Fabric.

NEW FUNCTIONALITY v2.0:
- Continuous normal background traffic (simulates baseline)
- Anomalies introduced gradually
- Threading for concurrent execution
- Configurable traffic intensity

Author: Alfonso D.
Date: 2026-01-24
Version: 2.0
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

# Load variables from .env
load_dotenv()

# Initialize colorama for Windows compatibility
init(autoreset=True)

# ============================================================================
# Configuration
# ============================================================================

class Config:
    """Test orchestrator configuration"""
    
    def __init__(self):
        self.servers = os.getenv('POSTGRES_SERVERS', '').split(',')
        self.servers = [s.strip() for s in self.servers if s.strip()]
        self.user = os.getenv('POSTGRES_USER', '')
        self.password = os.getenv('POSTGRES_PASSWORD', '')
        self.database = os.getenv('POSTGRES_DATABASE', 'adventureworks')
        self.port = int(os.getenv('POSTGRES_PORT', '5432'))
        
        # Anomaly test configuration
        self.delay_between_tests = int(os.getenv('DELAY_BETWEEN_TESTS', '120'))
        self.enable_brute_force = os.getenv('ENABLE_BRUTE_FORCE', 'false').lower() == 'true'
        self.brute_force_attempts = int(os.getenv('BRUTE_FORCE_ATTEMPTS', '20'))
        
        # NEW: Background traffic configuration
        self.enable_background_traffic = os.getenv('ENABLE_BACKGROUND_TRAFFIC', 'true').lower() == 'true'
        self.background_traffic_intensity = os.getenv('BACKGROUND_TRAFFIC_INTENSITY', 'medium').lower()
        self.baseline_duration = int(os.getenv('BASELINE_DURATION', '180'))  # 3 min baseline
        self.anomaly_spacing = int(os.getenv('ANOMALY_SPACING', '300'))  # 5 min between anomalies
        self.total_duration_minutes = int(os.getenv('TOTAL_DURATION_MINUTES', '20'))  # total demo duration
        
        self.sql_tests_dir = os.path.join(os.path.dirname(__file__), 'sql_tests')
        
        # Traffic intensity configuration
        self.traffic_intensity_config = {
            'low': {'selects_per_min': 3, 'updates_per_min': 0.5, 'errors_per_5min': 1},
            'medium': {'selects_per_min': 6, 'updates_per_min': 1.5, 'errors_per_5min': 2},
            'high': {'selects_per_min': 12, 'updates_per_min': 3, 'errors_per_5min': 3}
        }
        
    def validate(self) -> Tuple[bool, str]:
        """Validates the configuration"""
        if not self.servers:
            return False, "❌ No PostgreSQL servers specified (POSTGRES_SERVERS)"
        if not self.user:
            return False, "❌ No user specified (POSTGRES_USER)"
        if not self.password:
            return False, "❌ No password specified (POSTGRES_PASSWORD)"
        if not os.path.exists(self.sql_tests_dir):
            return False, f"❌ Test directory not found: {self.sql_tests_dir}"
        if self.background_traffic_intensity not in self.traffic_intensity_config:
            return False, f"❌ Invalid intensity: {self.background_traffic_intensity} (use: low, medium, high)"
        return True, "✅ Configuration valid"


# ============================================================================
# Utility Functions
# ============================================================================

def print_banner():
    """Prints startup banner"""
    print(f"\n{Fore.CYAN}{'='*80}")
    print(f"{Fore.CYAN}  PostgreSQL Anomaly Testing Orchestrator v2.0")
    print(f"{Fore.CYAN}  Con Simulación de Tráfico Normal - Para demos de Microsoft Fabric")
    print(f"{Fore.CYAN}{'='*80}{Style.RESET_ALL}\n")


def print_section(title: str):
    """Prints section title"""
    print(f"\n{Fore.YELLOW}{'─'*80}")
    print(f"{Fore.YELLOW}  {title}")
    print(f"{Fore.YELLOW}{'─'*80}{Style.RESET_ALL}\n")


def get_connection(config: Config, server: str):
    """Creates a PostgreSQL connection"""
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
        print(f"{Fore.RED}❌ Connection error to {server}: {e}{Style.RESET_ALL}")
        return None


def execute_sql_queries(conn, queries: List[str], allow_errors: bool = False) -> Tuple[int, int]:
    """
    Executes a list of SQL queries
    
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
    Executes a complete SQL file
    """
    with open(sql_file, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    # Split queries by semicolon
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
                # Ignore errors that are expected in some tests
                if "does not exist" in error_msg or "already exists" in error_msg:
                    print(f"{Fore.YELLOW}⚠️ Warning: {e}{Style.RESET_ALL}")
                    conn.rollback()
                    # Continue executing
                else:
                    print(f"{Fore.RED}❌ Error executing query: {e}{Style.RESET_ALL}")
                    conn.rollback()
                    cursor.close()
                    return False, queries_executed, queries_failed
    
    cursor.close()
    return True, queries_executed, queries_failed


# ============================================================================
# NEW: Background Traffic Generator
# ============================================================================

class BackgroundTrafficGenerator:
    """Generates normal database traffic in background"""
    
    def __init__(self, config: Config, server: str):
        self.config = config
        self.server = server
        self.is_running = False
        self.thread = None
        self.queries_executed = 0
        self.errors_generated = 0
        
        # Load normal queries
        self.normal_queries = self._load_normal_queries()
        
    def _load_normal_queries(self) -> dict:
        """Loads normal queries from SQL file"""
        normal_traffic_file = os.path.join(self.config.sql_tests_dir, 'background_normal_traffic.sql')
        
        if not os.path.exists(normal_traffic_file):
            return {'selects': [], 'transactional': [], 'analytical': [], 'errors': []}
        
        with open(normal_traffic_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Separate by categories (simplified)
        queries = {
            'selects': [],
            'transactional': [],
            'analytical': [],
            'errors': []
        }
        
        # Individual queries (split by ; and filter comments)
        all_queries = [q.strip() for q in content.split(';') if q.strip() and not q.strip().startswith('--')]
        
        # Classify queries (simplified - assume file order)
        if len(all_queries) >= 13:
            queries['selects'] = all_queries[0:5]  # Query 1-5: Normal SELECTs
            queries['transactional'] = all_queries[5:7]  # Query 6-7: INSERT, UPDATE
            queries['analytical'] = all_queries[7:10]  # Query 8-10: Analytics
            queries['errors'] = all_queries[10:13]  # Query 11-13: Normal errors
        
        return queries
    
    def _run_traffic_loop(self):
        """Main traffic background loop"""
        intensity = self.config.traffic_intensity_config[self.config.background_traffic_intensity]
        
        while self.is_running:
            conn = get_connection(self.config, self.server)
            if not conn:
                time.sleep(30)
                continue
            
            try:
                # Execute normal SELECTs
                num_selects = int(intensity['selects_per_min'] + random.uniform(-1, 1))
                num_selects = max(1, num_selects)
                
                selected_queries = random.sample(
                    self.normal_queries['selects'], 
                    min(num_selects, len(self.normal_queries['selects']))
                )
                
                executed, failed = execute_sql_queries(conn, selected_queries, allow_errors=True)
                self.queries_executed += executed
                
                # Occasionally execute transactional
                if random.random() < (intensity['updates_per_min'] / 60):
                    if self.normal_queries['transactional']:
                        trans_query = random.choice(self.normal_queries['transactional'])
                        execute_sql_queries(conn, [trans_query], allow_errors=True)
                        self.queries_executed += 1
                
                # Occasionally execute analytics
                if random.random() < 0.1:  # 10% chance
                    if self.normal_queries['analytical']:
                        anal_query = random.choice(self.normal_queries['analytical'])
                        execute_sql_queries(conn, [anal_query], allow_errors=True)
                        self.queries_executed += 1
                
                # Occasionally generate normal errors
                if random.random() < (intensity['errors_per_5min'] / 300):
                    if self.normal_queries['errors']:
                        error_query = random.choice(self.normal_queries['errors'])
                        execute_sql_queries(conn, [error_query], allow_errors=True)
                        self.errors_generated += 1
                
            except Exception:
                pass
            finally:
                conn.close()
            
            # Wait random time (~10-15 seconds between executions)
            time.sleep(random.uniform(10, 15))
    
    def start(self):
        """Starts the background traffic generator"""
        if self.is_running:
            return
        
        self.is_running = True
        self.thread = threading.Thread(target=self._run_traffic_loop, daemon=True)
        self.thread.start()
        
        print(f"{Fore.GREEN}🚀 Background traffic started{Style.RESET_ALL}")
        print(f"   Intensity: {Fore.CYAN}{self.config.background_traffic_intensity}{Style.RESET_ALL}")
        intensity = self.config.traffic_intensity_config[self.config.background_traffic_intensity]
        print(f"   Configuration: {Fore.CYAN}~{int(intensity['selects_per_min'])} SELECTs/min, "
              f"~{int(intensity['updates_per_min'])} UPDATEs/min{Style.RESET_ALL}")
    
    def stop(self):
        """Stops the background traffic"""
        if not self.is_running:
            return
        
        self.is_running = False
        if self.thread:
            self.thread.join(timeout=5)
        
        print(f"\n{Fore.CYAN}\ud83d\udec1 Background traffic stopped{Style.RESET_ALL}")
        print(f"   Total queries executed: {Fore.CYAN}{self.queries_executed}{Style.RESET_ALL}")
        print(f"   Normal errors generated: {Fore.YELLOW}{self.errors_generated}{Style.RESET_ALL}")


# ============================================================================
# Test Execution Functions
# ============================================================================

def run_test(config: Config, server: str, test_file: str, test_number: int, test_name: str) -> bool:
    """Executes an individual test"""
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
            print(f"{Fore.GREEN}   ✅ Anomaly executed{Style.RESET_ALL}")
            print(f"      Queries executed: {Fore.CYAN}{executed}{Style.RESET_ALL}")
            if failed > 0:
                print(f"      Errors generated: {Fore.YELLOW}{failed}{Style.RESET_ALL}")
        else:
            print(f"{Fore.RED}   ❌ Test failed{Style.RESET_ALL}")
            return False
            
    except Exception as e:
        print(f"{Fore.RED}   ❌ Unexpected error: {e}{Style.RESET_ALL}")
        return False
    finally:
        conn.close()
    
    return True


def run_cleanup(config: Config, server: str):
    """Executes post-demo cleanup"""
    print(f"\n{Fore.CYAN}🧹 Ejecutando limpieza post-demo...{Style.RESET_ALL}")
    
    cleanup_file = os.path.join(config.sql_tests_dir, 'test_cleanup.sql')
    if not os.path.exists(cleanup_file):
        print(f"{Fore.YELLOW}   ⚠️ Cleanup file not found{Style.RESET_ALL}")
        return
    
    conn = get_connection(config, server)
    if not conn:
        return
    
    try:
        success, executed, failed = execute_sql_file(conn, cleanup_file)
        if success:
            print(f"{Fore.GREEN}   ✅ Cleanup completed{Style.RESET_ALL}")
        else:
            print(f"{Fore.YELLOW}   ⚠️ Cleanup partially failed{Style.RESET_ALL}")
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
    
    # Show configuration
    print_section("Configuration")
    print(f"   Servers: {Fore.CYAN}{', '.join(config.servers)}{Style.RESET_ALL}")
    print(f"   User: {Fore.CYAN}{config.user}{Style.RESET_ALL}")
    print(f"   Database: {Fore.CYAN}{config.database}{Style.RESET_ALL}")
    print(f"   Background traffic: {Fore.CYAN}{'Enabled' if config.enable_background_traffic else 'Disabled'}{Style.RESET_ALL}")
    if config.enable_background_traffic:
        print(f"   Traffic intensity: {Fore.CYAN}{config.background_traffic_intensity}{Style.RESET_ALL}")
        print(f"   Initial baseline: {Fore.CYAN}{config.baseline_duration}s{Style.RESET_ALL}")
        print(f"   Space between anomalies: {Fore.CYAN}{config.anomaly_spacing}s{Style.RESET_ALL}")
        print(f"   Target total duration: {Fore.CYAN}{config.total_duration_minutes} min{Style.RESET_ALL}")
    
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
        
        # Ejecutar anomalías gradualmente por rondas hasta completar duración
        start_time = time.time()
        end_time = start_time + (config.total_duration_minutes * 60)
        round_num = 1

        while time.time() < end_time:
            print_section(f"Ronda {round_num} de anomalías")

            for idx, test_file in enumerate(test_files, 1):
                if time.time() >= end_time:
                    break

                basename = os.path.basename(test_file)
                test_key = basename.split('_')[0] + '_' + basename.split('_')[1]
                test_name = test_names.get(test_key, basename)

                # Ejecutar anomalía
                success = run_test(config, server, test_file, idx, test_name)

                if not success:
                    print(f"\n{Fore.YELLOW}⚠️ Continuando...{Style.RESET_ALL}")

                # Volver a normalidad (excepto último test de la ronda)
                if idx < len(test_files) and time.time() < end_time:
                    print(f"\n{Fore.GREEN}✅ Volviendo a actividad normal...{Style.RESET_ALL}")
                    print(f"{Fore.CYAN}⏸️  Esperando {config.anomaly_spacing}s hasta próxima anomalía{Style.RESET_ALL}")
                    print(f"{Fore.CYAN}   💡 Observa en Fabric cómo la anomalía desaparece y vuelve a normal{Style.RESET_ALL}")
                    time.sleep(config.anomaly_spacing)

            round_num += 1
        
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
