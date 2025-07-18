# app.py - Código Principal de la API para Lovable
# Este archivo contiene la lógica principal de la API Flask.

from flask import Flask, request, jsonify
import oracledb # ¡CAMBIO CRÍTICO AQUÍ! Ahora importamos 'oracledb'
import os
from datetime import datetime

app = Flask(__name__)

# --- Configuración de la Base de Datos ---
# Las credenciales se cargan de variables de entorno o usan valores por defecto.
DB_USER = os.environ.get('DB_USER', 'madiaz')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'madiaz01')
DB_HOST = os.environ.get('DB_HOST', '10.212.135.10')
DB_PORT = os.environ.get('DB_PORT', '1521')
DB_SERVICE_NAME = os.environ.get('DB_SERVICE_NAME', 'ATRIOD')

# Cadena de conexión Oracle para python-oracledb
# Formato: host:port/service_name
# oracledb.connect usa los parámetros por separado, no una cadena completa
# La cadena de conexión para el Thin Client es "host:port/service_name"
ORACLE_DSN = f"{DB_HOST}:{DB_PORT}/{DB_SERVICE_NAME}"

# Función para establecer la conexión a la base de datos
def get_db_connection():
    """Establece y devuelve una conexión a la base de datos Oracle usando python-oracledb."""
    try:
        # Conexión en modo Thin Client (no requiere Instant Client)
        connection = oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=ORACLE_DSN)
        return connection
    except oracledb.Error as e: # ¡CAMBIO CRÍTICO AQUÍ! Ahora capturamos errores de 'oracledb'
        error_obj, = e.args
        print(f"Error al conectar a la base de datos: {error_obj.message}")
        return None

# --- Endpoint para Consultar Facturas Pendientes ---
# Método: GET
# URL: /api/facturas
# Parámetros (Query Parameters):
#   - tipo_id: Tipo de identificación del cliente (ej. 'V', 'J', 'G')
#   - num_id: Número de identificación del cliente (ej. '12345678')
@app.route('/api/facturas', methods=['GET'])
def get_facturas():
    """
    Consulta y devuelve las facturas pendientes de un cliente.
    Requiere 'tipo_id' y 'num_id' como parámetros de consulta.
    """
    tipo_id = request.args.get('tipo_id')
    num_id = request.args.get('num_id')

    # Validación de parámetros
    if not tipo_id or not num_id:
        return jsonify({"error": "Los parámetros 'tipo_id' y 'num_id' son obligatorios."}), 400

    connection = get_db_connection()
    if not connection:
        return jsonify({"error": "No se pudo conectar a la base de datos."}), 500

    cursor = connection.cursor()
    facturas = []

    try:
        # Adaptación de la consulta SQL de APEX.
        sql_query = """
        SELECT
            FC.IDEFACT AS NUMERO_FACTURA,
            FC.MTOFACTLOCAL AS MONTO_FACTURA_LOCAL,
            P.NUMPOL AS NUMERO_POLIZA,
            R.NUMREC AS NUMERO_RECIBO,
            R.CODFRACCIONAMIENTO AS FRACCIONAMIENTO,
            FC.FECVENCFACT AS FECHA_VENCIMIENTO,
            FC.MTOFACTMONEDA AS MONTO_FACTURA_MONEDA,
            NDF.INDSEL AS INDICADOR_SELECCION,
            FC.TIPOID AS TIPO_IDENTIFICACION,
            FC.NUMID AS NUMERO_IDENTIFICACION
        FROM
            ACSEL.FACTURA_CIA FC
        INNER JOIN
            ACSEL.NOT_DEPOSITO_FACT NDF ON FC.IDEFACT = NDF.IDEFACT
        INNER JOIN
            ACSEL.ACREENCIA_CIA A ON FC.IDEFACT = A.IDEFACT
        INNER JOIN
            ACSEL.RECIBO R ON A.NUMACRE = R.NUMACRE
        INNER JOIN
            ATRIOWEB.POLIZA P ON R.IDEPOL = P.IDEPOL
        LEFT JOIN
            ACSEL.BLVAL L ON P.CODPROD = L.CODLVAL AND L.TIPOLVAL = 'FTOPAGO' AND L.ACTIVO = 'S'
        WHERE
            FC.TIPOID = :tipo_id AND FC.NUMID = :num_id
        GROUP BY
            FC.IDEFACT, FC.MTOFACTLOCAL, P.NUMPOL, R.NUMREC, R.CODFRACCIONAMIENTO,
            FC.FECVENCFACT, FC.MTOFACTMONEDA, NDF.INDSEL, FC.TIPOID, FC.NUMID
        ORDER BY
            FC.IDEFACT
        """
        cursor.execute(sql_query, tipo_id=tipo_id, num_id=num_id)

        columns = [col[0] for col in cursor.description]

        for row in cursor:
            factura = dict(zip(columns, row))
            facturas.append(factura)

        return jsonify(facturas), 200

    except oracledb.Error as e: # ¡CAMBIO CRÍTICO AQUÍ!
        error_obj, = e.args
        print(f"Error al ejecutar la consulta de facturas: {error_obj.message}")
        return jsonify({"error": f"Error en la base de datos al consultar facturas: {error_obj.message}"}), 500
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

# --- Endpoint para Registrar Notificaciones de Pago ---
# Método: POST
# URL: /api/notificar_pago
# Cuerpo de la solicitud (JSON):
#   - referencia_cliente: Identificador de la transacción/cliente (VARCHAR2(100))
#   - monto: Monto del pago (NUMBER(18,2))
#   - moneda: Código de la moneda (VARCHAR2(3))
#   - estado: Estado de la transacción (VARCHAR2(20))
#   - fecha_transaccion: Fecha y hora de la transacción (TIMESTAMP(6))
#   - firma_recibida: Firma de seguridad recibida (VARCHAR2(500))
#   - datos_completos: (Opcional) JSON o CLOB con todos los datos de la notificación
@app.route('/api/notificar_pago', methods=['POST'])
def notificar_pago():
    """
    Registra una notificación de pago en la tabla BANESCO_TRANSACCIONES.
    Requiere datos en formato JSON en el cuerpo de la solicitud.
    """
    data = request.get_json()

    required_fields = ["referencia_cliente", "monto", "moneda", "estado", "fecha_transaccion", "firma_recibida"]
    if not all(field in data for field in required_fields):
        return jsonify({"error": f"Faltan campos obligatorios. Se requieren: {', '.join(required_fields)}"}), 400

    connection = get_db_connection()
    if not connection:
        return jsonify({"error": "No se pudo conectar a la base de datos."}), 500

    cursor = connection.cursor()

    try:
        fecha_transaccion_dt = datetime.fromisoformat(data['fecha_transaccion'])

        sql_insert = """
        INSERT INTO ACSEL.BANESCO_TRANSACCIONES (
            ID, REFERENCIA_CLIENTE, MONTO, MONEDA, ESTADO, FECHA_TRANSACCION,
            FIRMA_RECIBIDA, FIRMA_VALIDA, DATOS_COMPLETOS, FECHA_PROCESAMIENTO,
            IP_ORIGEN, PROCESADO, MENSAJE_ERROR
        ) VALUES (
            NULL, :referencia_cliente, :monto, :moneda, :estado, :fecha_transaccion,
            :firma_recibida, :firma_valida, :datos_completos, SYSTIMESTAMP,
            :ip_origen, :procesado, :mensaje_error
        )
        """
        params = {
            "referencia_cliente": data['referencia_cliente'],
            "monto": data['monto'],
            "moneda": data['moneda'],
            "estado": data['estado'],
            "fecha_transaccion": fecha_transaccion_dt,
            "firma_recibida": data['firma_recibida'],
            "firma_valida": data.get('firma_valida', 'N'),
            "datos_completos": data.get('datos_completos', None),
            "ip_origen": request.remote_addr,
            "procesado": data.get('procesado', 'N'),
            "mensaje_error": data.get('mensaje_error', None)
        }

        cursor.execute(sql_insert, params)
        connection.commit()

        return jsonify({"message": "Notificación de pago registrada exitosamente.", "id_transaccion": cursor.lastrowid}), 201

    except oracledb.Error as e: # ¡CAMBIO CRÍTICO AQUÍ!
        error_obj, = e.args
        connection.rollback()
        print(f"Error al registrar la notificación de pago: {error_obj.message}")
        return jsonify({"error": f"Error en la base de datos al registrar pago: {error_obj.message}"}), 500
    except Exception as e:
        print(f"Error inesperado: {str(e)}")
        return jsonify({"error": f"Error inesperado al procesar la solicitud: {str(e)}"}), 500
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

# --- Ejecución de la Aplicación ---
if __name__ == '__main__':
    print("La aplicación Flask está lista para ser desplegada.")
    print("Para ejecutar en desarrollo, descomenta la línea app.run(debug=True, ...)")
    print("Para producción, usa Gunicorn o Apache mod_wsgi.")
