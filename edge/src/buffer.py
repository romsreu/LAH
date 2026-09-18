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
