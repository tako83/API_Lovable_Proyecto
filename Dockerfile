# Dockerfile para la API de Lovable con Instalación Robusta y Verificada de Oracle Instant Client

# Usa una imagen base de Python
FROM python:3.9-slim-buster

# Define la versión del Oracle Instant Client y la URL de descarga
# Usaremos la versión "Basic Lite" que es más pequeña.
# **¡IMPORTANTE!** Verifica que esta URL de descarga directa siga funcionando.
# Si Oracle cambia la URL o requiere autenticación, este paso fallará.
ENV ORACLE_CLIENT_VERSION=19.19.0.0.0
ENV ORACLE_CLIENT_PACKAGE=instantclient-basiclite-linux.x64-${ORACLE_CLIENT_VERSION}.zip
ENV ORACLE_CLIENT_URL=https://download.oracle.com/otn_software/linux/instantclient/1919000/${ORACLE_CLIENT_PACKAGE}

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Instala las dependencias del sistema necesarias para Oracle Instant Client y cx_Oracle
# Incluye wget, curl, ca-certificates, locales, tzdata, libaio1, libnsl2, libstdc++6, build-essential
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    locales \
    tzdata \
    libaio1 \
    libnsl2 \
    libstdc++6 \
    build-essential \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Configura la localización para evitar warnings (a veces necesario para apt-get)
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Crea el directorio para Oracle Instant Client
RUN mkdir -p /opt/oracle/instantclient

# Descarga, descomprime e instala Oracle Instant Client
# Usamos curl -L para seguir redirecciones si la URL lo requiere
RUN curl -L -o /tmp/${ORACLE_CLIENT_PACKAGE} ${ORACLE_CLIENT_URL} && \
    unzip /tmp/${ORACLE_CLIENT_PACKAGE} -d /opt/oracle/instantclient && \
    rm /tmp/${ORACLE_CLIENT_PACKAGE}

# Mueve los contenidos de la carpeta versionada directamente a /opt/oracle/instantclient
# Esto es para asegurar que las librerías estén en la ruta principal esperada
RUN mv /opt/oracle/instantclient/instantclient_${ORACLE_CLIENT_VERSION}/* /opt/oracle/instantclient/ && \
    rmdir /opt/oracle/instantclient/instantclient_${ORACLE_CLIENT_VERSION}

# Crea enlaces simbólicos a las librerías principales en /usr/lib
# Esto es CRÍTICO para que el sistema las encuentre, ya que /usr/lib es una ruta estándar de búsqueda.
RUN ln -s /opt/oracle/instantclient/libclntsh.so /usr/lib/libclntsh.so && \
    ln -s /opt/oracle/instantclient/libocci.so /usr/lib/libocci.so && \
    ln -s /opt/oracle/instantclient/libnnz19.so /usr/lib/libnnz19.so

# Configura las librerías dinámicas para que el sistema las encuentre
# Crea un archivo de configuración para ldconfig y lo ejecuta
RUN echo /opt/oracle/instantclient > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig

# Exporta la variable de entorno LD_LIBRARY_PATH para que cx_Oracle encuentre las librerías
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient:$LD_LIBRARY_PATH

# Copia el archivo de requisitos e instala las dependencias de Python
# Importante: cx_Oracle se instalará DESPUÉS de que las librerías del cliente estén en su lugar
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia el resto de tu aplicación al directorio de trabajo
COPY . .

# Expone el puerto en el que la aplicación Flask escuchará
EXPOSE 5000

# Define el comando para iniciar la aplicación usando Gunicorn
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:5000"]
