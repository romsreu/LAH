"""
influx_writer.py — LAHI 4.0 / edge

Traduce el JSON del Arduino al esquema de InfluxDB y lo publica.

El JSON llega plano (un solo nivel, ~35 campos). Solo se publican las
MEDICIONES de los sensores, agrupadas en measurements temáticos: temperatura,
humedad, quimica y luz.

El resto del JSON (setpoints, intervalos, estados de actuadores, fallo_pid) es
configuración y estado interno del Arduino, no algo medido: no se sube.


TIPOS: POR QUÉ SE FUERZAN EXPLÍCITAMENTE
────────────────────────────────────────
ArduinoJson serializa los float que caen en un número redondo SIN decimal:
24.0 se manda como `24`. Python lo lee como int, y el cliente de InfluxDB lo
escribe como `24i` (entero) en vez de `24.0` (float).

InfluxDB fija el tipo de cada campo en la primera escritura y rechaza con
HTTP 400 "field type conflict" cualquier escritura posterior con otro tipo.
Resultado: el bridge funciona hasta que un sensor devuelve un número redondo,
y ahí empieza a fallar de forma intermitente.

La solución es no depender de lo que mande el firmware: todo campo se escribe
como float, incluida la cuenta cruda del LDR.


ESCRITURA ATÓMICA POR LECTURA
─────────────────────────────
Todos los points de una lectura van en UNA llamada. Si se escribieran de a uno
y fallara a mitad de camino, los primeros measurements quedarían subidos y la
lectura entera se encolaría igual en el buffer: al reenviarla se duplicarían
esos puntos.
"""

import json
import logging
import math

from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
from influxdb_client.rest import ApiException

import config

log = logging.getLogger("hydrolab.influx")


def es_rechazo_permanente(exc):
    """
    True si InfluxDB rechazó el dato y reintentar no va a servir de nada.

    Distinguir esto es lo que evita que la cola se tapone. Dos familias:

      PERMANENTE (400, 422) — el dato no es aceptable y nunca lo va a ser:
      timestamp fuera de la retención del bucket, conflicto de tipo de campo,
      line protocol inválido. Se descarta y se sigue con el resto de la cola.

      TRANSITORIO (timeouts, 5xx, 429, errores de red) — el dato está bien,
      falló el camino. Se corta el barrido y se reintenta en el próximo ciclo.

    401/403 (token inválido o sin permisos) se tratan como transitorios a
    propósito: son un error de configuración, y descartar datos por eso sería
    perder lecturas buenas por algo que se arregla editando el .env.
    """
    return isinstance(exc, ApiException) and exc.status in (400, 422)


# ── Coerción de tipos ────────────────────────────────────────────────────────
def _f(valor):
    """
    A float. Devuelve None si el valor no es utilizable.

    Un sensor desconectado puede mandar null (ArduinoJson serializa NaN así) o
    un infinito. Ninguno de los dos se puede representar en line protocol: si
    se cuelan, InfluxDB rechaza la lectura entera con 400.
    """
    if valor is None:
        return None
    try:
        v = float(valor)
    except (TypeError, ValueError):
        return None
    if math.isnan(v) or math.isinf(v):
        return None
    return v


# DallasTemperature devuelve DEVICE_DISCONNECTED_C (-127 °C) cuando el DS18B20
# no responde. No es una temperatura: se trata igual que un null.
DS18B20_DESCONECTADO = -127.0


def _f_ds18b20(valor):
    """Como _f(), pero descarta la marca de sensor desconectado del DS18B20."""
    v = _f(valor)
    if v is None or v <= DS18B20_DESCONECTADO:
        return None
    return v


def parsear(raw):
    """
    Convierte la línea JSON del Arduino en {measurement: {campo: valor}}.

    Levanta json.JSONDecodeError si la línea vino cortada o con ruido,
    y KeyError si falta un campo que el firmware debería mandar.

    Los campos individuales que vengan inutilizables (null, NaN) quedan en None
    y los filtra escribir(); no invalidan el resto de la lectura.
    """
    d = json.loads(raw)

    return {
        # ── Todo float ───────────────────────────────────────────────────────
        "temperatura": {
            "interior":     _f(d["temperatura_interior"]),
            "exterior":     _f(d["temperatura_exterior"]),
            "sol_superior": _f_ds18b20(d["temperatura_solucion_estante_superior"]),
            "sol_inferior": _f_ds18b20(d["temperatura_solucion_estante_inferior"]),
        },
        "humedad": {
            "interior": _f(d["humedad_interior"]),
            "exterior": _f(d["humedad_exterior"]),
        },
        "quimica": {
            "ph":                   _f(d["ph"]),
            "electroconductividad": _f(d["electroconductividad"]),
        },
        "luz": {
            # Cuenta cruda del ADC (analogRead), 0-1023.
            "intensidad": _f(d["intensidad_luz"]),
        },
    }


class InfluxWriter:
    """Cliente de InfluxDB Cloud. Escribe una lectura completa por llamada."""

    def __init__(self):
        self._client = InfluxDBClient(
            url=config.INFLUX_URL,
            token=config.INFLUX_TOKEN,
            org=config.INFLUX_ORG,
            proxy=config.INFLUX_PROXY,   # None = conexión directa
            timeout=30_000,              # ms
        )
        self._write_api = self._client.write_api(write_options=SYNCHRONOUS)

        if config.INFLUX_PROXY:
            log.info(f"Usando proxy saliente: {config.INFLUX_PROXY}")

    @staticmethod
    def _armar_points(datos, ts=None):
        """
        Construye los points descartando campos inutilizables.

        Un measurement que se queda sin ningún campo válido se omite entero:
        un point sin fields no es line protocol válido y hace que InfluxDB
        rechace el lote completo con 400.
        """
        points = []
        descartados = []

        for measurement, campos in datos.items():
            validos = {k: v for k, v in campos.items() if v is not None}
            descartados += [f"{measurement}.{k}" for k, v in campos.items() if v is None]

            if not validos:
                continue

            point = Point(measurement)
            for clave, valor in validos.items():
                point = point.field(clave, valor)
            if ts is not None:
                point = point.time(int(ts * 1e9))   # InfluxDB espera nanosegundos
            points.append(point)

        if descartados:
            log.warning(f"Campos sin valor, se omiten: {', '.join(descartados)}")

        return points

    def escribir(self, datos, ts=None):
        """
        Publica una lectura. `ts` en epoch segundos; si se omite, usa la hora del server.

        Levanta la excepción del cliente si falla, para que el llamador
        pueda derivar la lectura al buffer.
        """
        points = self._armar_points(datos, ts)

        if not points:
            log.error("La lectura no tiene ningún campo válido. No se envía nada.")
            return

        # Una sola llamada: o entra todo, o no entra nada.
        self._write_api.write(
            bucket=config.INFLUX_BUCKET,
            org=config.INFLUX_ORG,
            record=points,
        )

    def cerrar(self):
        try:
            self._client.close()
        except Exception:
            pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.cerrar()
        return False
