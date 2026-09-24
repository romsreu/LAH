"""
arduino.py — LAHI 4.0 / edge

Único dueño del puerto serie. Nadie más abre, escribe ni lee el puerto.

Responsabilidades:
  - Autodetectar el Arduino y conectarse
  - Reconectar cuando se cae el enlace
  - Ejecutar el ciclo pedido/respuesta: manda 'P', lee la línea JSON

El ciclo escribir+leer es una sola transacción indivisible: si falla la escritura
falla la lectura, y la reconexión es la misma. Por eso viven juntos acá.

Protocolo actual del firmware (json_serial.cpp): al recibir 'P' por serie,
el Arduino responde con una línea JSON terminada en \\n. Es el único comando
que entiende hoy.
"""

import logging
import time

import serial
import serial.tools.list_ports

import config

log = logging.getLogger("hydrolab.arduino")

CMD_PEDIR_DATOS = b'P'


class Arduino:
    """Maneja la conexión serie con el Arduino Mega."""

    def __init__(self, puerto=None, baud=None, timeout=5):
        self._puerto_fijo = puerto if puerto is not None else config.SERIAL_PORT
        self._baud = baud if baud is not None else config.SERIAL_BAUD
        self._timeout = timeout
        self._ser = None

    # ── Conexión ─────────────────────────────────────────────────────────────
    @staticmethod
    def detectar_puerto():
        """Busca un Arduino conectado y devuelve su puerto. None si no encuentra."""
        for p in serial.tools.list_ports.comports():
            if "ACM" in p.device or "USB" in p.device:
                log.info(f"Arduino detectado en: {p.device} ({p.description})")
                return p.device
        return None

    def conectar(self, reintento_seg=10, aviso_cada_seg=600):
        """
        Abre el puerto. Reintenta indefinidamente hasta lograrlo.

        Reintenta cada `reintento_seg`, pero el aviso de "no encontrado" se
        loguea cada `aviso_cada_seg`: con el Arduino desenchufado toda una
        noche, un warning cada 10 s llenaba el log de líneas idénticas.
        """
        inicio = time.monotonic()
        ultimo_aviso = None
        while True:
            puerto = self._puerto_fijo or self.detectar_puerto()

            if puerto:
                try:
                    self._ser = serial.Serial(puerto, self._baud, timeout=self._timeout)
                    time.sleep(2)  # el Arduino se reinicia al abrirse el serial
                    self._ser.reset_input_buffer()
                    log.info(f"Conectado a {puerto}.")
                    return
                except serial.SerialException as e:
                    log.error(f"No se pudo abrir {puerto}: {e}")

            ahora = time.monotonic()
            if ultimo_aviso is None or ahora - ultimo_aviso >= aviso_cada_seg:
                minutos = (ahora - inicio) / 60
                log.warning(
                    f"No se encontró el Arduino (hace {minutos:.0f} min). "
                    f"Reintentando cada {reintento_seg}s, próximo aviso en "
                    f"{aviso_cada_seg // 60} min."
                )
                ultimo_aviso = ahora
            time.sleep(reintento_seg)

    def reconectar(self):
        """Cierra lo que haya y vuelve a conectar."""
        self.cerrar()
        self.conectar()

    def cerrar(self):
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass
            self._ser = None

    # ── Comandos ─────────────────────────────────────────────────────────────
    def pedir_datos(self):
        """
        Manda 'P' y devuelve la línea JSON cruda (str), o None si no hubo respuesta.

        Levanta serial.SerialException si se perdió el enlace; el llamador decide
        si reconectar.
        """
        if self._ser is None:
            raise serial.SerialException("Puerto no abierto. Llamá a conectar() primero.")

        self._ser.reset_input_buffer()   # descarta lo que haya quedado colgado
        self._ser.write(CMD_PEDIR_DATOS)

        raw = self._ser.readline().decode(errors="replace").strip()
        return raw or None

    # ── Context manager ──────────────────────────────────────────────────────
    def __enter__(self):
        self.conectar()
        return self

    def __exit__(self, *exc):
        self.cerrar()
        return False
