# Dockerfile Simplificado para la API de Lovable con python-oracledb

# Usa una imagen base de Python
FROM python:3.9-slim-buster

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Instala las dependencias del sistema necesarias (si las hay)
# Para python-oracledb en modo Thin Client, no necesitamos librerías de Oracle Instant Client.
# build-essential es útil si alguna otra dependencia de Python necesita compilarse.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copia el archivo de requisitos e instala las dependencias de Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia el resto de tu aplicación al directorio de trabajo
COPY . .

# Expone el puerto en el que la aplicación Flask escuchará
EXPOSE 5000

# Define el comando para iniciar la aplicación usando Gunicorn
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:5000"]
