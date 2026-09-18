# LAHI 4.0 — edge

Bridge que corre en la Raspberry Pi: le pide lecturas al Arduino Mega por puerto
serie y las publica en InfluxDB Cloud para el posterior uso de clientes.

<img width="2058" height="764" alt="flujo_de_persistencia" src="https://github.com/user-attachments/assets/9d9f2921-8f64-4b33-ba66-2e141e765fca" />

## Estructura

```
edge/
├── src/
│   ├── main.py            # entrypoint: orquesta el ciclo
│   ├── arduino.py         # único dueño del puerto serie
│   ├── influx_writer.py   # mapea el JSON a measurements y publica
│   ├── buffer.py          # store-and-forward en SQLite
│   └── config.py          # configuración por variables de entorno
├── config/
│   └── .env.example       # plantilla, copiar a .env
├── systemd/
│   └── hydrolab-edge.service
└── requirements.txt
```

### Por qué el puerto serie tiene un solo dueño

Mandar `'P'` y leer la respuesta es una transacción indivisible: si falla la
escritura falla la lectura, y la reconexión es la misma. Partirlo en dos módulos
obligaría a repartir la lógica de reconexión entre ellos. `arduino.py` abre,
reconecta, escribe y lee; nadie más toca el puerto.

Si más adelante se agregan comandos (mover un setpoint, forzar una bomba), un
`control.py` decidiría *qué* comando corresponde y *cuándo*, y se lo pediría a
`arduino.py` para que lo escriba. Hoy el firmware solo reconoce `'P'`, así que
ese módulo todavía no existe.

## Instalación en la Raspberry

```bash
# 1. Clonar
cd /home/romsreu/hydrolab
git clone <url-del-repo> .     # o copiar la carpeta edge/

# 2. Dependencias
pip install -r edge/requirements.txt --break-system-packages

# 3. Permiso al puerto serie (requiere logout/login)
sudo usermod -a -G dialout romsreu

# 4. Configuración
cp edge/config/.env.example edge/config/.env
nano edge/config/.env          # completar INFLUX_TOKEN
chmod 600 edge/config/.env     # el token no debería ser legible por todos
```

### Servicio systemd

```bash
sudo cp edge/systemd/hydrolab-edge.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable hydrolab-edge
sudo systemctl start hydrolab-edge
sudo systemctl status hydrolab-edge
```

> **Si venís del servicio viejo `hydrolab-bridge`, desactivalo primero.**
> Con los dos habilitados arrancan ambos, se pelean por el puerto serie y
> duplican escrituras en InfluxDB:
> ```bash
> sudo systemctl disable --now hydrolab-bridge
> sudo rm /etc/systemd/system/hydrolab-bridge.service
> sudo systemctl daemon-reload
> ```

### Logs

```bash
journalctl -u hydrolab-edge -f        # en vivo
tail -f /home/romsreu/hydrolab/edge/hydrolab.log
```

## Configuración

Todo sale de variables de entorno, listadas en `config/.env.example`. Las carga
systemd vía `EnvironmentFile`; para correr a mano las lee `python-dotenv`.

`config/.env` **no se versiona** — ahí vive el token de InfluxDB.

Dos variables merecen atención:

**`INFLUX_PROXY`** — la red de la facultad bloquea el 443 saliente. Si hay que
salir por proxy, va acá; el cliente de InfluxDB lo recibe directo, sin depender
de que systemd propague variables del sistema. Vacío = conexión directa.

**`CAMPO_LED_INFERIOR`** — el firmware manda hoy `led_estante_iniferior_estado`,
con un typo histórico. El parseo usa el nombre de esta variable, así que los dos
lados pueden corregirse por separado sin que se rompa el pipeline. Si no
coinciden, el parseo tira `KeyError` y **no se sube ninguna lectura**.

## Correr a mano (sin servicio)

```bash
cd /home/romsreu/hydrolab/edge
PYTHONPATH=src python3 src/main.py
```

## Problemas conocidos del firmware

- **Ambos LEDs reportan el mismo estado.** En `json_serial.cpp`,
  `led_estante_superior_estado` y `led_estante_iniferior_estado` se asignan los
  dos desde `LED_state`. El panel de actuadores de Grafana muestra las dos
  líneas idénticas; no es un problema del bridge.
- **Typo `iniferior`** en el nombre del campo JSON (ver arriba).
