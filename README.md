Sistema hidropónico indoor diseñado para facilitar el cultivo en entornos donde las condiciones del suelo o el clima no son favorables. El sistema permite producir en espacios cerrados y controlados, optimizando el uso del agua y los nutrientes sin depender de la tierra.

Está montado dentro de un armario metálico autocontenido con dos niveles de cultivo, iluminación LED, ventilación forzada y control automático de variables como temperatura, pH y conductividad eléctrica. Además, incorpora dosificación de nutrientes y registro continuo de datos para monitoreo y análisis del funcionamiento del sistema.

El proyecto utiliza Arduino y Raspberry Pi para la automatización, adquisición de datos y control del sistema, incluyendo monitoreo remoto, almacenamiento histórico de variables y operación manual o automática de actuadores.

Este repositorio reúne el código fuente, la documentación técnica, esquemas electrónicos y herramientas relacionadas con el desarrollo del laboratorio hidropónico realizado en la UTN Facultad Regional Santa Fe.

## Estructura del repositorio

Es un monorepo: cada subsistema del laboratorio vive en su propia carpeta de nivel superior.

```
LAH/
├── firmware/          # Código embebido (Arduino / C++)
│   ├── main/          #   Sketch principal: control, sensores, actuadores, display
│   └── tests/         #   Sketches de prueba por componente (DHT22, pH/EC, bombas…)
│
├── edge/              # Bridge en la Raspberry Pi (Python)
│   ├── src/           #   Lee el Arduino por serie y publica en InfluxDB Cloud
│   ├── config/        #   Plantilla de variables de entorno
│   └── systemd/       #   Unit para arranque automático
│
├── twin/              # Gemelo digital interactivo en Godot (visualización 3D)
│
├── web/               # Sitios web del sistema
│   └── sites/lah/     #   Sitio principal - landing + dashboard
│   
├── tools/             # Utilidades: simulador de datos, mapa de pines
├── docs/              # Documentación técnica, informes y esquemas (PDF)
├── assets/            # Recursos compartidos (logos, imágenes)
└── README.md
```

### Subsistemas

| Carpeta | Qué contiene | Tecnología |
|---|---|---|
| `firmware/` | Adquisición de sensores, control de actuadores, lógica de programas y display. `main/` es el sketch de producción; `tests/` valida cada componente por separado. | Arduino / C++ |
| `edge/` | Bridge que corre en la Raspberry Pi: pide lecturas al Arduino por puerto serie, las mapea al esquema de InfluxDB y las publica. Incluye buffer local (SQLite) para cortes de conexión y servicio `systemd` para arranque automático. | Python / InfluxDB |
| `twin/` | Modelo digital interactivo del armario y sus componentes. | Godot, Onshape |
| `web/` | Interfaz de usuario: landing con la simulación 3D embebida y dashboard de monitoreo. | HTML / CSS / JS |
| `tools/` | Scripts de apoyo al desarrollo (p. ej. `simulate_data.py`, `mapa_pines.html`). | Python / HTML |
| `docs/` | Informes de proyecto, documentación de variables y funciones, planos. | PDF |
