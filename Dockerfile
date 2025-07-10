# Dockerfile para la API de Lovable con Oracle Instant Client (Ajuste de Ruta)

# Usa una imagen base de Python
FROM python:3.9-slim-buster

# Define la versión del Oracle Instant Client y la URL de descarga
# Usaremos la versión "Basic Light" que es más pequeña y a veces más fácil de instalar.
# Asegúrate de que la URL sea correcta y la versión exista en Oracle.
ENV ORACLE_CLIENT_VERSION=19.19.0.0.0
ENV ORACLE_CLIENT_PACKAGE=instantclient-basiclite-linux.x64-${ORACLE_CLIENT_VERSION}.zip
ENV ORACLE_CLIENT_URL=https://download.oracle.com/otn_software/linux/instantclient/1919000/${ORACLE_CLIENT_PACKAGE}

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Instala las dependencias del sistema necesarias para Oracle Instant Client y cx_Oracle
# (libaio1 y unzip son cruciales)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libaio1 \
    unzip \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Descarga, descomprime e instala Oracle Instant Client
# Lo instalaremos directamente en /usr/local/lib para que sea más fácil de encontrar
RUN wget -O /tmp/${ORACLE_CLIENT_PACKAGE} ${ORACLE_CLIENT_URL} && \
    unzip /tmp/${ORACLE_CLIENT_PACKAGE} -d /usr/local/lib && \
    rm /tmp/${ORACLE_CLIENT_PACKAGE} && \
    ln -s /usr/local/lib/instantclient_${ORACLE_CLIENT_VERSION} /usr/local/lib/instantclient_19_19

# Exporta la variable de entorno LD_LIBRARY_PATH para que cx_Oracle encuentre las librerías
# Apunta directamente a la carpeta donde se descomprimió el cliente
ENV LD_LIBRARY_PATH=/usr/local/lib/instantclient_19_19:$LD_LIBRARY_PATH

# Copia el archivo de requisitos e instala las dependencias de Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia el resto de tu aplicación al directorio de trabajo
COPY . .

# Expone el puerto en el que la aplicación Flask escuchará
EXPOSE 5000

# Define el comando para iniciar la aplicación usando Gunicorn
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:5000"]
