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
import logging.handlers
import time

import serial

import config
import buffer
from arduino import Arduino
from influx_writer import InfluxWriter, parsear, es_rechazo_permanente

log = logging.getLogger("hydrolab")


def configurar_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            # Rotativo: la SD nunca guarda más de LOG_MAX_BYTES × (LOG_BACKUPS + 1).
            logging.handlers.RotatingFileHandler(
                config.LOG_FILE,
                maxBytes=config.LOG_MAX_BYTES,
                backupCount=config.LOG_BACKUPS,
                encoding="utf-8",
            ),
            logging.StreamHandler(),    # journald (journalctl -u hydrolab-edge)
        ],
    )


def vaciar_pendientes(writer):
    """
    Reenvía los pendientes del buffer, del más viejo al más nuevo.

    Una lectura se descarta —no se reintenta— cuando es irrecuperable: JSON
    corrupto, o rechazo permanente de InfluxDB (timestamp fuera de retención,
    conflicto de tipos). Reintentarla taponaría la cola indefinidamente, porque
    el barrido siempre empieza por la más vieja.

    Ante un fallo transitorio (sin red, timeout, 5xx) corta el barrido y deja
    el resto para el próximo ciclo, sin perder el orden.
    """
    buffer.purgar_vencidos()      # descarte proactivo: evita pedirle a InfluxDB
                                  # lo que ya sabemos que va a rechazar

    filas = buffer.pendientes()
    if not filas:
        return

    log.info(f"{len(filas)} lecturas pendientes en el buffer. Reenviando...")
    subidos = descartados = 0

    for fila_id, raw, ts in filas:
        try:
            datos = parsear(raw)
        except (json.JSONDecodeError, KeyError) as e:
            log.error(f"Pendiente {fila_id} corrupto, se descarta: {e}")
            buffer.borrar(fila_id)
            descartados += 1
            continue

        try:
            writer.escribir(datos, ts)          # con el timestamp original
            buffer.borrar(fila_id)
            subidos += 1
        except Exception as e:
            if es_rechazo_permanente(e):
                log.error(f"Pendiente {fila_id} rechazado definitivamente, se descarta: {e}")
                buffer.borrar(fila_id)
                descartados += 1
                continue
            log.error(f"No se pudo reenviar el pendiente {fila_id}: {e}")
            break

    if subidos:
        log.info(f"Se reenviaron {subidos} lecturas del buffer.")
    if descartados:
        log.warning(f"Se descartaron {descartados} lecturas irrecuperables.")


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
        if es_rechazo_permanente(e):
            # Solo acá el raw aporta: el servidor rechazó el CONTENIDO, y sin
            # verlo no se puede saber qué valor lo disparó. En un fallo de red
            # el dato está bien y volcarlo en cada ciclo solo infla el log.
            log.error(f"Rechazo de contenido. Raw: {raw}")
            return      # reintentarla desde el buffer daría el mismo 400
        buffer.guardar(raw, ts)


def main():
    configurar_logging()
    buffer.init()

    # Limpieza de arranque: si el servicio estuvo caído mucho tiempo, el buffer
    # puede tener lecturas ya fuera de la retención de InfluxDB. Sacarlas acá
    # evita arrancar con una cola taponada.
    pend = buffer.cantidad()
    if pend:
        viejo, nuevo = buffer.rango()
        log.info(
            f"Buffer: {pend} lecturas pendientes "
            f"({time.strftime('%Y-%m-%d %H:%M', time.localtime(viejo))} → "
            f"{time.strftime('%Y-%m-%d %H:%M', time.localtime(nuevo))})."
        )
        if buffer.purgar_vencidos():
            log.info(f"Buffer depurado: quedan {buffer.cantidad()} lecturas.")

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
