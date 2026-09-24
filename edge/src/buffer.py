"""
buffer.py — LAHI 4.0 / edge

Buffer local store-and-forward sobre SQLite.

Rol: cajón temporal de strings, no base de datos analítica. Guarda el JSON crudo
del Arduino cuando InfluxDB Cloud no está disponible (corte de internet, proxy
caído) y lo devuelve para reenviarlo cuando vuelve la conexión.

Se guarda el timestamp original de la lectura para que, al reenviar, el dato
quede registrado en el momento en que se midió y no cuando volvió el enlace.
"""

import logging
import sqlite3
import time

import config

log = logging.getLogger("hydrolab.buffer")


def _conectar():
    return sqlite3.connect(config.DB_LOCAL)


def init():
    """Crea la tabla de pendientes si no existe."""
    with _conectar() as con:
        con.execute("""
            CREATE TABLE IF NOT EXISTS pendientes (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                json_crudo TEXT NOT NULL,
                timestamp  REAL NOT NULL
            )
        """)


def guardar(raw, ts):
    """Encola un JSON crudo con su timestamp de lectura (epoch segundos)."""
    with _conectar() as con:
        con.execute(
            "INSERT INTO pendientes (json_crudo, timestamp) VALUES (?, ?)",
            (raw, ts),
        )
    log.warning("Dato guardado en buffer local.")


def pendientes():
    """Devuelve [(id, json_crudo, ts), ...] en orden de llegada."""
    with _conectar() as con:
        return con.execute(
            "SELECT id, json_crudo, timestamp FROM pendientes ORDER BY id"
        ).fetchall()


def borrar(fila_id):
    """Borra un pendiente ya confirmado en InfluxDB."""
    with _conectar() as con:
        con.execute("DELETE FROM pendientes WHERE id = ?", (fila_id,))


def cantidad():
    with _conectar() as con:
        return con.execute("SELECT COUNT(*) FROM pendientes").fetchone()[0]


def rango():
    """(ts_mas_viejo, ts_mas_nuevo) o (None, None) si está vacío."""
    with _conectar() as con:
        return tuple(con.execute(
            "SELECT MIN(timestamp), MAX(timestamp) FROM pendientes"
        ).fetchone())


def purgar_vencidos(edad_maxima_seg=None):
    """
    Borra las lecturas más viejas que BUFFER_MAX_DIAS. Devuelve cuántas borró.

    InfluxDB rechaza con HTTP 400 cualquier timestamp fuera de la retención del
    bucket. Esas lecturas no se pueden subir nunca: reintentarlas tapona la cola
    y no hay forma de recuperarlas. Se descartan.
    """
    if edad_maxima_seg is None:
        edad_maxima_seg = config.BUFFER_MAX_SEG

    corte = time.time() - edad_maxima_seg
    with _conectar() as con:
        cur = con.execute("DELETE FROM pendientes WHERE timestamp < ?", (corte,))
        borradas = cur.rowcount

    if borradas > 0:
        dias = edad_maxima_seg / 86400
        log.warning(
            f"Se descartaron {borradas} lecturas de más de {dias:.0f} días: "
            f"quedaron fuera de la retención de InfluxDB y no se pueden subir."
        )
    return borradas


# No hay VACUUM a propósito: el buffer cicla (se llena y se vacía), así que las
# páginas que libera un DELETE las reutiliza el siguiente INSERT. El archivo se
# estabiliza en su máximo histórico. Compactar no ganaría espacio y en cambio
# reescribiría el archivo entero sobre la tarjeta SD, que tiene ciclos contados.
