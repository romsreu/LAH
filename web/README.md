# web/

Sitios web del sistema HydroLab. Cada carpeta bajo `sites/` es un sitio; `shared/`
contiene assets que pueden usar varios sitios sin duplicarlos.

```
web/
├── sites/
│   └── lah/          # sitio principal (LAH - UTN), el que va a Netlify
│       ├── index.html      landing con la simulación 3D embebida
│       ├── dashboard.html  panel de monitoreo
│       └── *.js  styles.css  logos/iconos
└── shared/
    └── twin-sim/     # export web de Godot (simulación 3D), compartido
```

## Cómo se conecta la simulación 3D

La landing (`sites/lah/index.html`) embebe la simulación en un `<iframe>` que
apunta con ruta relativa al export compartido:

```html
<iframe src="../../shared/twin-sim/hydro_virtualization.html"></iframe>
```

Así el export (~100 MB) se versiona una sola vez en `shared/` y no se duplica
por cada sitio.

## Correr localmente

Hay que servir desde la raíz de `web/` (no desde `sites/lah/`), porque el iframe
sube a `../../shared/`:

```bash
cd web
python3 -m http.server 8000
# abrir http://localhost:8000/sites/lah/
```

## Deploy en Netlify

Configurado en [`netlify.toml`](../netlify.toml) (raíz del repo):

- **publish:** `web`  (se publica toda la carpeta, no solo el sitio)
- **redirect:** `/` → `/sites/lah/`  (la raíz del dominio abre el sitio)

⚠️ Si el sitio en Netlify fue creado apuntando a la carpeta vieja
(`webpage/page`), actualizá el *publish directory* a `web` en el panel —o dejá
que tome la config del `netlify.toml`.

## Agregar otro sitio

1. Crear `web/sites/<nombre>/` con su `index.html`.
2. Si necesita la simulación 3D, referenciar `../../shared/twin-sim/…`.
3. Agregar su redirect/deploy correspondiente en `netlify.toml`.
