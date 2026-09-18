"""
main.py — LAHI 4.0 / edge

Entrypoint del bridge Arduino → InfluxDB Cloud.

Ciclo, cada INTERVALO_SEGUNDOS:
  1. Pide la lectura al Arduino ('P') y recibe una línea JSON.
  2. La parsea. Si viene corrupta, la descarta y loguea.
  3. Vacía lo que haya quedado pendiente en el buffer local.
  4. Publica la lectura nueva en InfluxDB Cloud.
  5. Si algo del paso 3 o 4 falla (sin internet), encola la lectura en el buffer.

Se corre como servicio systemd. Ver systemd/hydrolab-edge.service.
"""

import json
import logging
import time

import serial

import config
import buffer
from arduino import Arduino
from influx_writer import InfluxWriter, parsear

log = logging.getLogger("hydrolab")


def configurar_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(config.LOG_FILE),
            logging.StreamHandler(),
        ],
    )


def vaciar_pendientes(writer):
    """
    Reenvía los pendientes del buffer, del más viejo al más nuevo.

    Si uno falla corta el barrido y deja el resto para el próximo ciclo: así no
    se pierde el orden ni se reintenta en loop dentro de un mismo ciclo.
    Los que vienen corruptos se descartan, porque reintentarlos no los va a arreglar.
    """
    filas = buffer.pendientes()
    if not filas:
        return

    log.info(f"{len(filas)} lecturas pendientes en el buffer. Reenviando...")
    subidos = 0

    for fila_id, raw, ts in filas:
        try:
            datos = parsear(raw)
        except (json.JSONDecodeError, KeyError) as e:
            log.error(f"Pendiente {fila_id} corrupto, se descarta: {e}")
            buffer.borrar(fila_id)
            continue

        try:
            writer.escribir(datos, ts)          # con el timestamp original
            buffer.borrar(fila_id)
            subidos += 1
        except Exception as e:
            log.error(f"No se pudo reenviar el pendiente {fila_id}: {e}")
            break

    if subidos:
        log.info(f"Se reenviaron {subidos} lecturas del buffer.")


def ciclo(ard, writer):
    """Una iteración completa. Devuelve cuando terminó (no duerme)."""
    try:
        raw = ard.pedir_datos()
    except serial.SerialException:
        log.warning("Se perdió la conexión serial. Reconectando...")
        ard.reconectar()
        return

    if raw is None:
        log.warning("El Arduino no respondió.")
        return

    ts = time.time()

    try:
        datos = parsear(raw)
    except (json.JSONDecodeError, KeyError) as e:
        log.error(f"JSON inválido o campo faltante: {e}")
        log.error(f"Raw recibido: {raw}")
        return

    try:
        vaciar_pendientes(writer)
        writer.escribir(datos, ts)
        log.info("Lectura enviada a InfluxDB.")
    except Exception as e:
        log.warning(f"No se pudo enviar a InfluxDB: {e}")
        buffer.guardar(raw, ts)


def main():
    configurar_logging()
    buffer.init()

    pend = buffer.cantidad()
    if pend:
        log.info(f"Arrancando con {pend} lecturas pendientes del buffer.")

    log.info(f"Pidiendo datos cada {config.INTERVALO_SEGUNDOS}s.")

    with InfluxWriter() as writer, Arduino() as ard:
        try:
            while True:
                ciclo(ard, writer)
                time.sleep(config.INTERVALO_SEGUNDOS)
        except KeyboardInterrupt:
            log.info("Detenido por el usuario.")


if __name__ == "__main__":
    main()
