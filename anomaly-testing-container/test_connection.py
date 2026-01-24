#!/usr/bin/env python3
"""Test rápido de conexión a PostgreSQL"""
import os
import sys
import psycopg2

def test_connection():
    server = os.getenv('POSTGRES_SERVERS', '').split(',')[0].strip()
    user = os.getenv('POSTGRES_USER', '')
    password = os.getenv('POSTGRES_PASSWORD', '')
    database = os.getenv('POSTGRES_DATABASE', 'adventureworks')
    port = int(os.getenv('POSTGRES_PORT', '5432'))
    
    print(f"🔍 Probando conexión...")
    print(f"   Server: {server}")
    print(f"   User: {user}")
    print(f"   Database: {database}")
    
    try:
        conn = psycopg2.connect(
            host=server,
            port=port,
            database=database,
            user=user,
            password=password,
            connect_timeout=10,
            sslmode='require'
        )
        
        # Test query
        cursor = conn.cursor()
        cursor.execute("SELECT current_database(), current_user, version();")
        db, usr, ver = cursor.fetchone()
        
        print(f"\n✅ Conexión exitosa!")
        print(f"   Database: {db}")
        print(f"   User: {usr}")
        print(f"   Version: {ver[:50]}...")
        
        # Check adventureworks tables
        cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema');")
        tables = cursor.fetchone()[0]
        print(f"   Tablas de usuario: {tables}")
        
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"\n❌ Error de conexión: {e}")
        return False

if __name__ == "__main__":
    success = test_connection()
    sys.exit(0 if success else 1)
