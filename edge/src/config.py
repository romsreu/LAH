"""
config.py — LAHI 4.0 / edge

Centraliza la configuración. Todo sale de variables de entorno.
En la Pi las provee systemd vía EnvironmentFile (ver systemd/hydrolab-edge.service).
Para correr a mano: copiá config/.env.example a config/.env y completalo.

Ningún secreto se versiona: .env está en .gitignore, .env.example no lleva valores reales.
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]

# Carga opcional de .env para desarrollo local.
# Bajo systemd no hace falta: las variables ya vienen del EnvironmentFile.
try:
    from dotenv import load_dotenv
    load_dotenv(BASE_DIR / "config" / ".env")
except ImportError:
    pass


def _requerido(nombre):
    valor = os.environ.get(nombre)
    if not valor:
        raise RuntimeError(
            f"Falta la variable de entorno {nombre}. "
            f"Revisá config/.env o el EnvironmentFile del servicio."
        )
    return valor


# ── InfluxDB Cloud ───────────────────────────────────────────────────────────
INFLUX_URL    = os.environ.get("INFLUX_URL", "https://us-east-1-1.aws.cloud2.influxdata.com")
INFLUX_TOKEN  = _requerido("INFLUX_TOKEN")
INFLUX_ORG    = os.environ.get("INFLUX_ORG", "romsreu")
INFLUX_BUCKET = os.environ.get("INFLUX_BUCKET", "hydrolab")

# Proxy saliente. Necesario en la red de la facultad, que bloquea el 443 directo.
# Vacío = conexión directa.
INFLUX_PROXY  = os.environ.get("INFLUX_PROXY") or None

# ── Puerto serie ─────────────────────────────────────────────────────────────
# Vacío = autodetectar. Poné /dev/ttyACM0 para forzar uno fijo.
SERIAL_PORT   = os.environ.get("SERIAL_PORT") or None
SERIAL_BAUD   = int(os.environ.get("SERIAL_BAUD", 9600))   # debe coincidir con Serial.begin() del Arduino

# ── Ciclo y archivos ─────────────────────────────────────────────────────────
INTERVALO_SEGUNDOS = int(os.environ.get("INTERVALO_SEGUNDOS", 300))

DB_LOCAL = os.environ.get("DB_LOCAL", str(BASE_DIR / "buffer.db"))
LOG_FILE = os.environ.get("LOG_FILE", str(BASE_DIR / "hydrolab.log"))

# ── Compatibilidad con el firmware ───────────────────────────────────────────
# json_serial.cpp manda hoy "led_estante_iniferior_estado" (con el typo).
# Si lo corregís en el firmware, cambiá esta variable a "led_estante_inferior_estado".
# Si no coinciden, el parseo tira KeyError y NO se sube ningún dato.
CAMPO_LED_INFERIOR = os.environ.get("CAMPO_LED_INFERIOR", "led_estante_iniferior_estado")
