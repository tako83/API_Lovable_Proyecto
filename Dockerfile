# Dockerfile para la API de Lovable

# Usa una imagen base de Python que incluya las dependencias necesarias para cx_Oracle.
# Oracle Instant Client es necesario para cx_Oracle.
# La imagen 'oraclelinux8-slim' con Python 3.9 y Instant Client es una buena opción.
# Puedes encontrar imágenes oficiales o crear la tuya si necesitas una versión específica.
# Para este ejemplo, usaremos una imagen base que ya incluye Python y las librerías de desarrollo.
# Si encuentras problemas, podríamos necesitar una imagen base más específica o instalar Instant Client manualmente.
FROM python:3.9-slim-buster

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Instala las dependencias del sistema necesarias para cx_Oracle
# (libaio1 es crucial para la conexión con Oracle)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libaio1 \
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
# Este comando es el mismo que tenías en tu Procfile
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:5000"]
