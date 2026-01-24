FROM python:3.11-slim

# Metadata
LABEL maintainer="Alfonso D."
LABEL description="PostgreSQL Anomaly Testing Container for Microsoft Fabric Demos"
LABEL version="1.0"

# Configurar entorno
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements e instalar dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación
COPY anomaly_runner.py .
COPY sql_tests/ ./sql_tests/

# Crear usuario no-root para seguridad
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Comando por defecto
CMD ["python", "anomaly_runner.py"]
