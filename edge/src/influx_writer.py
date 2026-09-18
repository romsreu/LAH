"""
influx_writer.py — LAHI 4.0 / edge

Traduce el JSON del Arduino al esquema de InfluxDB y lo publica.

El JSON llega plano (un solo nivel, ~35 campos). Acá se agrupa en measurements
temáticos —temperatura, humedad, quimica, luz, actuadores, setpoints,
intervalos, fallos— que es como los consultan los paneles de Grafana.

Todos los points de una lectura se escriben en UNA sola llamada. Si se
escribieran de a uno y fallara a mitad de camino, los primeros measurements
quedarían subidos y la lectura entera se encolaría igual en el buffer:
al reenviarla se duplicarían esos puntos.
"""

import json
import logging

from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

import config

log = logging.getLogger("hydrolab.influx")


def parsear(raw):
    """
    Convierte la línea JSON del Arduino en {measurement: {campo: valor}}.

    Levanta json.JSONDecodeError si la línea vino cortada o con ruido,
    y KeyError si falta un campo que el firmware debería mandar.
    """
    d = json.loads(raw)

    return {
        "temperatura": {
            "interior":     d["temperatura_interior"],
            "exterior":     d["temperatura_exterior"],
            "sol_superior": d["temperatura_solucion_estante_superior"],
            "sol_inferior": d["temperatura_solucion_estante_inferior"],
        },
        "humedad": {
            "interior": d["humedad_interior"],
            "exterior": d["humedad_exterior"],
        },
        "quimica": {
            "ph":                   d["ph"],
            "electroconductividad": d["electroconductividad"],
        },
        "luz": {
            "intensidad": d["intensidad_luz"],
        },
        "actuadores": {
            "led_superior":    int(d["led_estante_superior_estado"]),
            # El nombre del campo sale de config porque el firmware tiene un typo
            # histórico ("iniferior"). Ver config.CAMPO_LED_INFERIOR.
            "led_inferior":    int(d[config.CAMPO_LED_INFERIOR]),
            "bomba_principal": int(d["bomba_tanque_principal_estado"]),
            "bomba_1":         int(d["bomba_tanque_1_estado"]),
            "bomba_2":         int(d["bomba_tanque_2_estado"]),
            "bomba_3":         int(d["bomba_tanque_3_estado"]),
            "bomba_4":         int(d["bomba_tanque_4_estado"]),
            "ventilador_leds": int(d["ventilador_principal_estado"]),
            "ventilador_1":    int(d["ventilador_1_estado"]),
            "ventilador_2":    int(d["ventilador_2_estado"]),
            "ventilador_3":    int(d["ventilador_3_estado"]),
        },
        "setpoints": {
            "temperatura": d["temperatura_setpoint"],
            "ph_minimo":   d["ph_setpoint_minimo"],
            "ph_maximo":   d["ph_setpoint_maximo"],
            "ec_minimo":   d["electroconductividad_setpoint_minimo"],
            "ec_maximo":   d["electroconductividad_setpoint_maximo"],
        },
        "intervalos": {
            "bomba_on_ms":      d["bomba_tanque_principal_tiempo_encendido"],
            "bomba_off_ms":     d["bomba_tanque_principal_tiempo_apagado"],
            "led_on_ms":        d["led_tiempo_encendido"],
            "led_off_ms":       d["led_tiempo_apagado"],
            "control_ph_ms":    d["intervalo_control_ph"],
            "control_ec_ms":    d["intervalo_control_ce"],
            "control_temp_ms":  d["intervalo_control_temperatura_aire"],
            "control_wtemp_ms": d["intervalo_control_temperatura_solucion"],
            "control_luz_ms":   d["intervalo_control_luz"],
        },
        "fallos": {
            "fallo_pid": int(d["fallo_pid"]),
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

    def escribir(self, datos, ts=None):
        """
        Publica una lectura. `ts` en epoch segundos; si se omite, usa la hora del server.

        Levanta la excepción del cliente si falla, para que el llamador
        pueda derivar la lectura al buffer.
        """
        points = []
        for measurement, campos in datos.items():
            point = Point(measurement)
            for clave, valor in campos.items():
                point = point.field(clave, valor)
            if ts is not None:
                point = point.time(int(ts * 1e9))   # InfluxDB espera nanosegundos
            points.append(point)

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
