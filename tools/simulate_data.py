#!/usr/bin/env python3
"""Backfill de datos simulados para el bucket InfluxDB del LAH.

Genera una semana de historial plausible (ciclo diurno + ruido) para las
variables que consume el dashboard (dashboard.js), y lo escribe al bucket
real vía la API HTTP de InfluxDB v2 (no requiere el paquete influxdb-client).

El token NUNCA se hardcodea acá: se lee de la variable de entorno
INFLUX_WRITE_TOKEN. Necesita permiso de ESCRITURA sobre el bucket
"hydrolab" (el token de dashboard.js es de solo lectura y no sirve).

Uso:
  export INFLUX_WRITE_TOKEN="..."
  python3 utils/simulate_data.py             # backfill de 7 días
  python3 utils/simulate_data.py --days 3    # backfill de 3 días
  python3 utils/simulate_data.py --dry-run   # solo mostrar, no escribir (no requiere token)
"""

import argparse
import math
import os
import random
import sys
import time

import requests

# ── Config InfluxDB (misma instancia que webpage/page/dashboard.js) ────────
INFLUX_URL = "https://us-east-1-1.aws.cloud2.influxdata.com"
INFLUX_ORG = "romsreu"
INFLUX_BUCKET = "hydrolab"

STEP_MINUTES = 5
BATCH_LINES = 5000

# measurement -> { field: sim_config }
SIM_CONFIG = {
    "temperatura": {
        "exterior":     dict(base=22,   amp=4,    phase=-1.6, noise=0.3,  min=12,  max=34),
        "interior":     dict(base=23,   amp=1.5,  phase=-1.6, noise=0.15, min=19,  max=27),
        "sol_superior": dict(base=20,   amp=1,    phase=-1.2, noise=0.1,  min=18,  max=22),
        "sol_inferior": dict(base=19.5, amp=1,    phase=-1.2, noise=0.1,  min=18,  max=22),
    },
    "humedad": {
        "exterior": dict(base=55, amp=-18, phase=-1.6, noise=2, min=30, max=92),
        "interior": dict(base=65, amp=-6,  phase=-1.6, noise=1, min=55, max=82),
    },
    "quimica": {
        "electroconductividad": dict(base=2.0, amp=0.12, phase=0.4, noise=0.03, min=1.5, max=2.5),
        "ph":                   dict(base=6.0, amp=0.2,  phase=1.1, noise=0.04, min=5.5, max=6.5),
    },
}


# Componente lento tipo "clima" (proceso de Ornstein-Uhlenbeck): hace que
# cada día tenga una línea de base distinta en vez de repetir el mismo seno
# exacto. target_std es el desvío en régimen permanente del componente lento,
# relativo a la amplitud diurna de cada variable; drift_step se deriva para
# lograr ese desvío dado DRIFT_DECAY (ver varianza estacionaria de un AR(1)).
DRIFT_DECAY = 0.999


def generate_series(cfg: dict, rng: random.Random, timestamps: list) -> list:
    target_std = abs(cfg["amp"]) * 0.6
    drift_step = target_std * math.sqrt(1 - DRIFT_DECAY ** 2)
    drift = rng.gauss(0, target_std)
    values = []
    for t in timestamps:
        hour_of_day = (t / 3600.0) % 24
        diurnal = math.sin((hour_of_day / 24) * 2 * math.pi + cfg["phase"]) * cfg["amp"]
        drift = drift * DRIFT_DECAY + rng.gauss(0, drift_step)
        point_noise = rng.uniform(-cfg["noise"], cfg["noise"])
        v = cfg["base"] + diurnal + drift + point_noise
        values.append(max(cfg["min"], min(cfg["max"], v)))
    return values


def build_lines(days: int, seed: int = 42, start: int = None, end: int = None):
    end = end if end is not None else int(time.time())
    start = start if start is not None else end - days * 24 * 3600
    step = STEP_MINUTES * 60
    timestamps = list(range(start, end + 1, step))
    rng = random.Random(seed)

    lines = []
    for measurement, fields in SIM_CONFIG.items():
        series = {field: generate_series(cfg, rng, timestamps) for field, cfg in fields.items()}
        for i, t in enumerate(timestamps):
            parts = [f"{field}={values[i]:.3f}" for field, values in series.items()]
            lines.append(f"{measurement} {','.join(parts)} {t}")
    return lines


def clear_range(days: int, token: str):
    url = f"{INFLUX_URL}/api/v2/delete?org={INFLUX_ORG}&bucket={INFLUX_BUCKET}"
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    start = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - days * 24 * 3600))
    headers = {"Authorization": f"Token {token}", "Content-Type": "application/json"}
    for measurement in SIM_CONFIG:
        body = {"start": start, "stop": now, "predicate": f'_measurement="{measurement}"'}
        resp = requests.post(url, headers=headers, json=body)
        if resp.status_code >= 300:
            print(f"ERROR borrando '{measurement}': {resp.status_code} {resp.text}", file=sys.stderr)
            sys.exit(1)
        print(f"Borrado histórico previo de '{measurement}' ({start} → {now})")


def write_lines(lines, token):
    url = f"{INFLUX_URL}/api/v2/write?org={INFLUX_ORG}&bucket={INFLUX_BUCKET}&precision=s"
    headers = {
        "Authorization": f"Token {token}",
        "Content-Type": "text/plain; charset=utf-8",
    }
    for i in range(0, len(lines), BATCH_LINES):
        batch = lines[i:i + BATCH_LINES]
        resp = requests.post(url, headers=headers, data="\n".join(batch))
        if resp.status_code >= 300:
            print(f"ERROR escribiendo lote {i // BATCH_LINES + 1}: {resp.status_code} {resp.text}", file=sys.stderr)
            sys.exit(1)
        print(f"Lote {i // BATCH_LINES + 1}: {len(batch)} puntos escritos OK")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--days", type=int, default=7, help="Días de historial a generar (default: 7)")
    parser.add_argument("--seed", type=int, default=42, help="Semilla del generador (default: 42)")
    parser.add_argument("--clear", action="store_true", help="Antes de escribir, borra el historial previo de estas mismas mediciones en el rango de días indicado (bucket v2 clásico; no soportado en serverless v3)")
    parser.add_argument("--start-epoch", type=int, default=None, help="Timestamp Unix (s) de inicio, para sobrescribir exactamente una corrida anterior en vez de tomar 'ahora - días'")
    parser.add_argument("--end-epoch", type=int, default=None, help="Timestamp Unix (s) de fin, ídem --start-epoch")
    parser.add_argument("--dry-run", action="store_true", help="No escribir, solo mostrar una muestra (no requiere token)")
    args = parser.parse_args()

    lines = build_lines(args.days, args.seed, args.start_epoch, args.end_epoch)
    print(f"Generando {args.days} día(s) de historial simulado ({len(lines)} puntos totales)…")

    if args.dry_run:
        print(f"[dry-run] {len(lines)} líneas generadas, ejemplo:")
        for sample in lines[:5]:
            print("  " + sample)
        return

    token = os.environ.get("INFLUX_WRITE_TOKEN")
    if not token:
        print(
            "ERROR: falta la variable de entorno INFLUX_WRITE_TOKEN "
            "(token de InfluxDB con permiso de escritura sobre el bucket "
            f"'{INFLUX_BUCKET}'). Ejecutá: export INFLUX_WRITE_TOKEN=\"...\"",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.clear:
        clear_range(args.days, token)

    write_lines(lines, token)
    print("Listo. El dashboard debería mostrar el historial simulado en los próximos segundos.")


if __name__ == "__main__":
    main()
