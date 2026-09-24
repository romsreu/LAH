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
# Ambientes: "LAH-real" guarda lo que mide el sistema real; "LAH-sim" los datos
# simulados de tools/simulate_data.py. El bridge escribe siempre en el real.
INFLUX_BUCKET = os.environ.get("INFLUX_BUCKET", "LAH-real")

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

# Log rotativo: al llegar a LOG_MAX_BYTES se renombra a hydrolab.log.1 (y así
# hasta LOG_BACKUPS); el más viejo se borra. Default: 5 archivos de 1 MB.
LOG_MAX_BYTES = int(os.environ.get("LOG_MAX_BYTES", 1_000_000))
LOG_BACKUPS   = int(os.environ.get("LOG_BACKUPS", 4))

# ── Buffer local ─────────────────────────────────────────────────────────────
# Una lectura encolada se guarda como máximo BUFFER_MAX_DIAS; pasado ese plazo
# se descarta. Coincide con la retención del bucket (30 días): InfluxDB rechaza
# con HTTP 400 todo timestamp más viejo, así que guardarla más no sirve de nada.
# El plazo también acota el tamaño del buffer en un corte largo (~8600 filas a
# 300 s por lectura), sin necesidad de un techo de filas aparte.
BUFFER_MAX_DIAS = int(os.environ.get("BUFFER_MAX_DIAS", 30))
BUFFER_MAX_SEG  = BUFFER_MAX_DIAS * 24 * 3600
