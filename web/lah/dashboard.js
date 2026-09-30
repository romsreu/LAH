// ── InfluxDB config ───────────────────────────────────────────────────────
const INFLUX = {
  url:    'https://us-east-1-1.aws.cloud2.influxdata.com',
  token:  '',
  org:    'romsreu',
};

// ── Fuente de datos (bucket) ──────────────────────────────────────────────
// En producción siempre se leen los datos reales. Para uso interno (capturas,
// pruebas) se puede forzar la simulación agregando ?src=sim a la URL; no se
// guarda en ningún lado, así que al sacar el parámetro vuelve a real.
const SOURCES = {
  real: { bucket: 'LAH-real' },
  sim:  { bucket: 'LAH-sim'  },
};

function initialSource() {
  const fromUrl = new URLSearchParams(location.search).get('src');
  return SOURCES[fromUrl] ? fromUrl : 'real';
}

let currentSource = initialSource();
const bucket = () => SOURCES[currentSource].bucket;

// ── Storage (puede fallar en modo privado) ────────────────────────────────
const store = {
  get(k)    { try { return localStorage.getItem(k); } catch (_) { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch (_) {} },
};

// ── Rango de tiempo (slider en días) ──────────────────────────────────────
const MIN_DAYS = 1;
const MAX_DAYS = 30;
const RANGE_TICKS = [1, 7, 14, 21, 30];
const RANGE_KEY  = 'lah.rangeDays.v1';
const LAYOUT_KEY = 'lah.layout.v1';

// Agregación automática: ~300 puntos por serie, redondeado a ventanas "limpias"
const AGG_STEPS_MIN = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240];
function aggEvery(days) {
  const target = days * 1440 / 300;
  return (AGG_STEPS_MIN.find(s => s >= target) || AGG_STEPS_MIN[AGG_STEPS_MIN.length - 1]) + 'm';
}

let currentDays = clampDays(parseInt(store.get(RANGE_KEY), 10) || 7);

function clampDays(d) { return Math.min(MAX_DAYS, Math.max(MIN_DAYS, d)); }

// ── Panel definitions ─────────────────────────────────────────────────────
const OVERVIEW_PANELS = [
  { id: 'temp-ext',  label: 'Temperatura exterior',     m: 'temperatura', f: 'exterior',             unit: '°C',    dec: 1 },
  { id: 'temp-int',  label: 'Temperatura interior',     m: 'temperatura', f: 'interior',             unit: '°C',    dec: 1 },
  { id: 'temp-sols', label: 'Temp. solución superior',  m: 'temperatura', f: 'sol_superior',         unit: '°C',    dec: 1 },
  { id: 'temp-soli', label: 'Temp. solución inferior',  m: 'temperatura', f: 'sol_inferior',         unit: '°C',    dec: 1 },
  { id: 'hum-ext',   label: 'Humedad exterior',         m: 'humedad',     f: 'exterior',             unit: '%',     dec: 1 },
  { id: 'hum-int',   label: 'Humedad interior',         m: 'humedad',     f: 'interior',             unit: '%',     dec: 1 },
  { id: 'ec',        label: 'Electroconductividad',     m: 'quimica',     f: 'electroconductividad', unit: 'mS/cm', dec: 2 },
  { id: 'ph',        label: 'pH',                       m: 'quimica',     f: 'ph',                   unit: '',      dec: 2 },
];

// ── Chart definitions ─────────────────────────────────────────────────────
const TREND_CHARTS = [
  { id: 'chart-temp-ext',  label: 'Temperatura exterior',    m: 'temperatura', f: 'exterior',             color: '#3fa83c', unit: '°C',    dec: 1 },
  { id: 'chart-temp-int',  label: 'Temperatura interior',    m: 'temperatura', f: 'interior',             color: '#f5a623', unit: '°C',    dec: 1 },
  { id: 'chart-temp-sols', label: 'Temp. solución superior', m: 'temperatura', f: 'sol_superior',         color: '#e87d3e', unit: '°C',    dec: 1 },
  { id: 'chart-temp-soli', label: 'Temp. solución inferior', m: 'temperatura', f: 'sol_inferior',         color: '#5b9bd5', unit: '°C',    dec: 1 },
  { id: 'chart-hum-ext',   label: 'Humedad exterior',        m: 'humedad',     f: 'exterior',             color: '#29b6f6', unit: '%',     dec: 1 },
  { id: 'chart-hum-int',   label: 'Humedad interior',        m: 'humedad',     f: 'interior',             color: '#7e57c2', unit: '%',     dec: 1 },
  { id: 'chart-ph',        label: 'pH',                      m: 'quimica',     f: 'ph',                   color: '#26c6da', unit: '',      dec: 2 },
  { id: 'chart-ec',        label: 'Electroconductividad',    m: 'quimica',     f: 'electroconductividad', color: '#ff7043', unit: 'mS/cm', dec: 2 },
];

// Cada tarjeta de lectura usa el color de su gráfica
function colorFor(m, f) {
  const c = TREND_CHARTS.find(c => c.m === m && c.f === f);
  return c ? c.color : 'var(--moss)';
}

const chartInstances = {};
const chartLoadSeq = {};
let booted = false;
const REDUCED_MOTION = matchMedia('(prefers-reduced-motion: reduce)').matches;
// En pantallas táctiles arrastrar sobre la gráfica tiene que desplazar la
// página; ahí el zoom se hace solo con pellizco.
const TOUCH = matchMedia('(hover: none) and (pointer: coarse)').matches;

// ── Queries ───────────────────────────────────────────────────────────────
async function influxQuery(flux) {
  try {
    const resp = await fetch(
      `${INFLUX.url}/api/v2/query?org=${encodeURIComponent(INFLUX.org)}`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Token ${INFLUX.token}`,
          'Content-Type': 'application/vnd.flux',
          'Accept': 'application/csv',
        },
        body: flux,
      }
    );
    if (!resp.ok) return null;
    return await resp.text();
  } catch (_) { return null; }
}

async function queryLast(measurement, field) {
  const csv = await influxQuery(
    `from(bucket: "${bucket()}")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "${measurement}" and r._field == "${field}")
  |> last()`
  );
  return csv ? parseLastValue(csv) : null;
}

async function queryTimeSeries(measurement, field, days) {
  const csv = await influxQuery(
    `from(bucket: "${bucket()}")
  |> range(start: -${days}d)
  |> filter(fn: (r) => r._measurement == "${measurement}" and r._field == "${field}")
  |> aggregateWindow(every: ${aggEvery(days)}, fn: mean, createEmpty: false)
  |> sort(columns: ["_time"])`
  );
  return csv ? parseTimeSeries(csv) : [];
}

// ── CSV parsers ───────────────────────────────────────────────────────────
function parseLastValue(csv) {
  const lines = csv.split('\n').filter(l => l.trim() && !l.startsWith('#'));
  if (lines.length < 2) return null;
  let valueIdx = -1, headerIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    const idx = lines[i].split(',').indexOf('_value');
    if (idx >= 0) { valueIdx = idx; headerIdx = i; break; }
  }
  if (valueIdx < 0) return null;
  const rows = lines.slice(headerIdx + 1).filter(l => l.trim());
  if (!rows.length) return null;
  const v = parseFloat(rows[rows.length - 1].split(',')[valueIdx]);
  return isNaN(v) ? null : v;
}

function parseTimeSeries(csv) {
  const lines = csv.split('\n').filter(l => l.trim() && !l.startsWith('#'));
  if (lines.length < 2) return [];
  let timeIdx = -1, valueIdx = -1, headerIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    const cols = lines[i].split(',');
    const ti = cols.indexOf('_time'), vi = cols.indexOf('_value');
    if (ti >= 0 && vi >= 0) { timeIdx = ti; valueIdx = vi; headerIdx = i; break; }
  }
  if (timeIdx < 0) return [];
  const points = [];
  for (const line of lines.slice(headerIdx + 1)) {
    if (!line.trim()) continue;
    const cols = line.split(',');
    const t = cols[timeIdx], v = parseFloat(cols[valueIdx]);
    if (t && !isNaN(v)) points.push({ x: new Date(t), y: v });
  }
  return points;
}

// ── Íconos de las herramientas de tarjeta ─────────────────────────────────
const ICON_GRIP = `<svg viewBox="0 0 24 24"><g class="dots"><circle cx="9" cy="6" r="1.6"/><circle cx="15" cy="6" r="1.6"/><circle cx="9" cy="12" r="1.6"/><circle cx="15" cy="12" r="1.6"/><circle cx="9" cy="18" r="1.6"/><circle cx="15" cy="18" r="1.6"/></g></svg>`;
const ICON_HIDE = `<svg viewBox="0 0 24 24"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><path d="M14.12 14.12a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>`;

function toolsHTML(label) {
  return `<div class="card-tools">
    <button class="tool-btn drag-handle" type="button" aria-label="Mover ${label}" title="Arrastrar para intercambiar">${ICON_GRIP}</button>
    <button class="tool-btn" type="button" data-action="hide" aria-label="Ocultar ${label}" title="Ocultar">${ICON_HIDE}</button>
  </div>`;
}

function htmlToEl(html) {
  const t = document.createElement('template');
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
}

// ── Panel rendering ───────────────────────────────────────────────────────
function buildPanelEl(p) {
  return htmlToEl(`<article class="card db-stat" data-id="${p.id}" data-status="loading" style="--accent:${colorFor(p.m, p.f)}">
  <div class="db-stat-head">
    <span class="db-stat-label">${p.label}</span>
    ${toolsHTML(p.label)}
  </div>
  <div class="db-stat-body">
    <span class="db-stat-num">—</span>
    <span class="db-stat-unit">${p.unit}</span>
  </div>
  <div class="db-stat-foot"><span class="status-dot"></span><span class="status-text">Esperando lectura</span></div>
</article>`);
}

function countTo(el, from, to, dec) {
  if (REDUCED_MOTION || from === to) { el.textContent = to.toFixed(dec); return; }
  const t0 = performance.now(), dur = 900;
  cancelAnimationFrame(el._raf);
  const step = now => {
    const k = Math.min(1, (now - t0) / dur);
    const e = 1 - Math.pow(1 - k, 3);
    el.textContent = (from + (to - from) * e).toFixed(dec);
    if (k < 1) el._raf = requestAnimationFrame(step);
  };
  el._raf = requestAnimationFrame(step);
}

function updatePanel(p, value) {
  const el = document.querySelector(`#overview-grid [data-id="${p.id}"]`);
  if (!el) return;
  const num = el.querySelector('.db-stat-num');
  const txt = el.querySelector('.status-text');
  if (value === null) {
    el.dataset.status = 'loading';
    num.textContent = '—';
    txt.textContent = 'Sin lecturas en la última hora';
    el._value = null;
    return;
  }
  // Siempre verde mientras se definen los rangos
  el.dataset.status = 'ok';
  txt.textContent = 'Midiendo';
  countTo(num, el._value ?? 0, value, p.dec);
  el._value = value;
  el.classList.remove('flash');
  void el.offsetWidth;
  el.classList.add('flash');
}

// ── Chart rendering ───────────────────────────────────────────────────────
function cssVar(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

function buildChartEl(c) {
  return htmlToEl(`<article class="card chart-card" data-id="${c.id}">
  <div class="chart-head">
    <div class="chart-title"><span class="swatch" style="background:${c.color}"></span>${c.label}</div>
    ${toolsHTML(c.label)}
  </div>
  <div class="chart-stats"></div>
  <div class="chart-wrap">
    <canvas id="${c.id}"></canvas>
    <div class="chart-empty">Sin datos en este período</div>
    <button class="zoom-reset" type="button">Ver período completo</button>
  </div>
</article>`);
}

function fillGradient(color) {
  return ctx => {
    const { ctx: g, chartArea } = ctx.chart;
    if (!chartArea) return color + '22';
    const gr = g.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
    gr.addColorStop(0, color + '45');
    gr.addColorStop(1, color + '00');
    return gr;
  };
}

function syncZoomState(chart) {
  const card = chart.canvas.closest('.chart-card');
  if (card) card.classList.toggle('zoomed', chart.isZoomedOrPanned());
}

function initChart(c, card) {
  const canvas = card.querySelector('canvas');
  const tick = cssVar('--chart-tick'), grid = cssVar('--chart-grid');
  const fmtY = v => Number(v).toFixed(c.dec);
  chartInstances[c.id] = new Chart(canvas.getContext('2d'), {
    type: 'line',
    data: { datasets: [{ label: c.label, data: [],
      borderColor: c.color, backgroundColor: fillGradient(c.color),
      fill: true, tension: 0.35, pointRadius: 0, borderWidth: 2,
      pointHoverRadius: 4, pointHoverBackgroundColor: c.color, pointHoverBorderColor: '#fff', pointHoverBorderWidth: 2,
    }]},
    options: {
      responsive: true, maintainAspectRatio: false,
      animation: REDUCED_MOTION ? false : { duration: 700, easing: 'easeOutQuart' },
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: cssVar('--soil'), titleColor: cssVar('--panel'), bodyColor: cssVar('--panel'),
          padding: 10, cornerRadius: 8, displayColors: false,
          titleFont: { family: 'Inter', weight: '500', size: 11 },
          bodyFont: { family: 'Lexend Deca', size: 14 },
          callbacks: { label: ctx => `${fmtY(ctx.parsed.y)} ${c.unit}`.trim() },
        },
        zoom: {
          zoom: {
            drag: { enabled: !TOUCH, backgroundColor: c.color + '22', borderColor: c.color, borderWidth: 1 },
            wheel: { enabled: true, modifierKey: 'ctrl' },
            pinch: { enabled: true },
            mode: 'x',
            onZoomComplete: ({ chart }) => syncZoomState(chart),
          },
          pan: { enabled: !TOUCH, mode: 'x', modifierKey: 'shift', onPanComplete: ({ chart }) => syncZoomState(chart) },
          limits: { x: { min: 'original', max: 'original', minRange: 30 * 60 * 1000 } },
        },
      },
      scales: {
        x: {
          type: 'time',
          time: {
            tooltipFormat: 'dd/MM HH:mm',
            displayFormats: { minute: 'HH:mm', hour: 'HH:mm', day: 'dd/MM', week: 'dd/MM', month: 'MM/yyyy' },
          },
          ticks: { maxTicksLimit: 7, maxRotation: 0, color: tick, font: { size: 10, family: 'Inter' } },
          grid: { display: false },
          border: { display: false },
        },
        y: {
          ticks: { maxTicksLimit: 5, color: tick, font: { size: 10, family: 'Inter' }, callback: v => fmtY(v) },
          grid: { color: grid },
          border: { display: false },
        },
      },
    },
  });
  // Permitir scroll vertical con el dedo sobre la gráfica (el plugin pone 'none')
  if (TOUCH) canvas.style.touchAction = 'pan-y';
  card.querySelector('.zoom-reset').addEventListener('click', () => {
    chartInstances[c.id].resetZoom();
    card.classList.remove('zoomed');
  });
}

function updateChart(c, points) {
  const inst = chartInstances[c.id];
  if (!inst) return;
  const card = inst.canvas.closest('.chart-card');
  inst.data.datasets[0].data = points;
  inst.update();
  card.classList.toggle('no-data', points.length === 0);

  const stats = card.querySelector('.chart-stats');
  if (!points.length) { stats.innerHTML = ''; return; }
  const ys = points.map(p => p.y);
  const min = Math.min(...ys), max = Math.max(...ys);
  const avg = ys.reduce((a, b) => a + b, 0) / ys.length;
  const u = c.unit ? ' ' + c.unit : '';
  stats.innerHTML =
    `<span>Mín <b>${min.toFixed(c.dec)}${u}</b></span>` +
    `<span>Prom <b>${avg.toFixed(c.dec)}${u}</b></span>` +
    `<span>Máx <b>${max.toFixed(c.dec)}${u}</b></span>`;
}

async function loadChart(c, resetZoom) {
  const seq = chartLoadSeq[c.id] = (chartLoadSeq[c.id] || 0) + 1;
  const points = await queryTimeSeries(c.m, c.f, currentDays);
  // Descartar respuestas viejas si el slider se movió mientras tanto
  if (seq !== chartLoadSeq[c.id] || !chartInstances[c.id]) return;
  if (resetZoom) {
    chartInstances[c.id].resetZoom('none');
    chartInstances[c.id].canvas.closest('.chart-card').classList.remove('zoomed');
  }
  updateChart(c, points);
}

function recolorCharts() {
  const tick = cssVar('--chart-tick'), grid = cssVar('--chart-grid');
  const bg = cssVar('--soil'), fg = cssVar('--panel');
  Object.values(chartInstances).forEach(inst => {
    const s = inst.options.scales, t = inst.options.plugins.tooltip;
    s.x.ticks.color = s.y.ticks.color = tick;
    s.y.grid.color = grid;
    t.backgroundColor = bg; t.titleColor = fg; t.bodyColor = fg;
    inst.update('none');
  });
}

// ── Layout personalizable (orden + ocultos, guardado en localStorage) ─────
const GROUPS = {
  overview: {
    defs: OVERVIEW_PANELS, gridId: 'overview-grid', noun: 'lecturas', revealBase: 1,
    build: buildPanelEl,
    // La carga inicial la hace refreshOverview; acá solo tarjetas que se vuelven a mostrar
    mount: (p) => { if (booted) queryLast(p.m, p.f).then(v => updatePanel(p, v)); },
    unmount: () => {},
  },
  charts: {
    defs: TREND_CHARTS, gridId: 'chart-grid', noun: 'gráficas', revealBase: 10,
    build: buildChartEl,
    mount: (c, el) => { initChart(c, el); loadChart(c); },
    unmount: (id) => {
      if (chartInstances[id]) { chartInstances[id].destroy(); delete chartInstances[id]; }
    },
  },
};

function defaultLayout() {
  const l = {};
  for (const key in GROUPS) l[key] = { order: GROUPS[key].defs.map(d => d.id), hidden: [] };
  return l;
}

function loadLayout() {
  const base = defaultLayout();
  let saved = null;
  try { saved = JSON.parse(store.get(LAYOUT_KEY)); } catch (_) {}
  if (!saved) return base;
  for (const key in base) {
    const s = saved[key];
    if (!s || !Array.isArray(s.order)) continue;
    const known = base[key].order;
    // Respetar el orden guardado; sumar al final variables nuevas que no existían
    const order = s.order.filter(id => known.includes(id));
    known.forEach(id => { if (!order.includes(id)) order.push(id); });
    base[key] = { order, hidden: (s.hidden || []).filter(id => known.includes(id)) };
  }
  return base;
}

let layout = loadLayout();
const saveLayout = () => store.set(LAYOUT_KEY, JSON.stringify(layout));

const defById = (key, id) => GROUPS[key].defs.find(d => d.id === id);
const visibleIds = key => layout[key].order.filter(id => !layout[key].hidden.includes(id));
const gridOf = key => document.getElementById(GROUPS[key].gridId);
const cardOf = (key, id) => gridOf(key).querySelector(`.card[data-id="${id}"]`);

// FLIP: anima a las tarjetas vecinas hacia su nueva posición tras un cambio
function flip(container, mutate) {
  const first = new Map([...container.children].map(el => [el, el.getBoundingClientRect()]));
  mutate();
  if (REDUCED_MOTION) return;
  [...container.children].forEach(el => {
    const f = first.get(el);
    if (!f) return;
    const l = el.getBoundingClientRect();
    const dx = f.left - l.left, dy = f.top - l.top;
    if (dx || dy) {
      el.animate([{ transform: `translate(${dx}px, ${dy}px)` }, { transform: 'none' }],
        { duration: 480, easing: 'cubic-bezier(0.22, 1, 0.36, 1)' });
    }
  });
}

function updateEmpty(key) {
  const grid = gridOf(key);
  const note = grid.querySelector('.empty-note');
  if (visibleIds(key).length) { if (note) note.remove(); return; }
  if (note) return;
  const el = htmlToEl(`<div class="empty-note">Ocultaste todas las ${GROUPS[key].noun}. <button type="button">Elegir cuáles mostrar</button></div>`);
  el.querySelector('button').addEventListener('click', openDrawer);
  grid.appendChild(el);
}

function renderGroup(key) {
  const g = GROUPS[key], grid = gridOf(key);
  visibleIds(key).forEach(id => g.unmount(id));
  grid.innerHTML = '';
  visibleIds(key).forEach((id, i) => {
    const def = defById(key, id);
    const el = g.build(def);
    el.classList.add('reveal');
    el.style.setProperty('--i', g.revealBase + i);
    el.addEventListener('animationend', () => el.classList.remove('reveal'), { once: true });
    grid.appendChild(el);
    g.mount(def, el);
  });
  updateEmpty(key);
}

const leaveTimers = {};

function setHidden(key, id, hide) {
  const g = GROUPS[key], st = layout[key], grid = gridOf(key);
  const isHidden = st.hidden.includes(id);
  if (hide === isHidden) return;
  st.hidden = hide ? [...st.hidden, id] : st.hidden.filter(x => x !== id);
  saveLayout();
  syncToggles();

  const existing = cardOf(key, id);
  if (hide) {
    if (!existing) return;
    existing.classList.add('is-leaving');
    leaveTimers[id] = setTimeout(() => {
      delete leaveTimers[id];
      flip(grid, () => { g.unmount(id); existing.remove(); updateEmpty(key); });
    }, REDUCED_MOTION ? 0 : 260);
    return;
  }

  // Mostrar: si todavía se estaba yendo, cancelar la salida
  if (leaveTimers[id]) {
    clearTimeout(leaveTimers[id]);
    delete leaveTimers[id];
    if (existing) { existing.classList.remove('is-leaving'); return; }
  }
  const def = defById(key, id);
  const el = g.build(def);
  const vis = visibleIds(key);
  const next = vis.slice(vis.indexOf(id) + 1).map(x => cardOf(key, x)).find(Boolean) || null;
  flip(grid, () => { grid.insertBefore(el, next); updateEmpty(key); });
  el.classList.add('is-entering');
  el.addEventListener('animationend', () => el.classList.remove('is-entering'), { once: true });
  g.mount(def, el);
}

// Tras intercambiar tarjetas, trasladar el orden visible al layout conservando
// la posición de las ocultas
function syncOrderFromDOM(key) {
  const domIds = [...gridOf(key).querySelectorAll('.card')].map(el => el.dataset.id);
  const st = layout[key];
  let k = 0;
  st.order = st.order.map(id => st.hidden.includes(id) ? id : domIds[k++]);
  saveLayout();
}

function initSortable(key) {
  const grid = gridOf(key);
  grid.addEventListener('click', e => {
    const btn = e.target.closest('[data-action="hide"]');
    if (btn) setHidden(key, btn.closest('.card').dataset.id, true);
  });
  if (typeof Sortable === 'undefined') return;
  Sortable.create(grid, {
    swap: true,
    swapClass: 'swap-target',
    handle: '.drag-handle',
    draggable: '.card',
    animation: REDUCED_MOTION ? 0 : 280,
    easing: 'cubic-bezier(0.22, 1, 0.36, 1)',
    ghostClass: 'sortable-ghost',
    chosenClass: 'sortable-chosen',
    onEnd: () => syncOrderFromDOM(key),
  });
}

// ── Panel de personalización ──────────────────────────────────────────────
function buildToggles(key) {
  const box = document.getElementById('toggles-' + key);
  box.innerHTML = GROUPS[key].defs.map(d => {
    const color = d.color || colorFor(d.m, d.f);
    return `<label class="toggle-row">
      <span class="swatch" style="background:${color}"></span>${d.label}
      <span class="switch"><input type="checkbox" role="switch" data-id="${d.id}"><i></i></span>
    </label>`;
  }).join('');
  box.addEventListener('change', e => {
    const input = e.target.closest('input[data-id]');
    if (input) setHidden(key, input.dataset.id, !input.checked);
  });
}

function syncToggles() {
  for (const key in GROUPS) {
    const st = layout[key];
    document.querySelectorAll(`#toggles-${key} input[data-id]`).forEach(inp => {
      inp.checked = !st.hidden.includes(inp.dataset.id);
    });
    const count = document.getElementById('count-' + key);
    if (count) count.textContent = `${st.order.length - st.hidden.length} de ${st.order.length}`;
  }
}

// El foco solo se mueve si se usó el teclado (con el mouse no hace falta y
// dejaba un anillo de foco a la vista). Un click con teclado tiene detail 0.
function openDrawer(e) {
  document.body.classList.add('drawer-open');
  const drawer = document.getElementById('drawer');
  drawer.setAttribute('aria-hidden', 'false');
  drawer.inert = false;
  if (!e || e.detail === 0) {
    setTimeout(() => document.getElementById('drawer-close').focus({ preventScroll: true }), 50);
  }
}

function closeDrawer(e) {
  if (!document.body.classList.contains('drawer-open')) return;
  document.body.classList.remove('drawer-open');
  const drawer = document.getElementById('drawer');
  drawer.setAttribute('aria-hidden', 'true');
  drawer.inert = true;
  const porTeclado = !e || e.type === 'keydown' || e.detail === 0;
  if (porTeclado) document.getElementById('customize-btn').focus({ preventScroll: true });
  else if (document.activeElement) document.activeElement.blur();
}

function resetLayout() {
  Object.values(leaveTimers).forEach(clearTimeout);
  for (const id in leaveTimers) delete leaveTimers[id];
  for (const key in GROUPS) layout[key].order.forEach(id => GROUPS[key].unmount(id));
  layout = defaultLayout();
  saveLayout();
  syncToggles();
  for (const key in GROUPS) renderGroup(key);
}

// ── Slider de rango ───────────────────────────────────────────────────────
function daysLabel(d) { return d === 1 ? '1 día' : `${d} días`; }

function paintRange() {
  const input = document.getElementById('range');
  const field = document.getElementById('range-field');
  const p = (currentDays - MIN_DAYS) / (MAX_DAYS - MIN_DAYS);
  input.value = currentDays;
  input.style.setProperty('--p', `calc(11px + (100% - 22px) * ${p})`);
  field.style.setProperty('--thumb-x', `calc(11px + (100% - 22px) * ${p})`);
  document.getElementById('range-bubble').textContent = daysLabel(currentDays);
  document.getElementById('range-value').textContent = daysLabel(currentDays);
  document.getElementById('charts-range-label').textContent =
    currentDays === 1 ? 'Últimas 24 horas' : `Últimos ${currentDays} días`;
  document.querySelectorAll('#range-ticks span').forEach(s =>
    s.classList.toggle('on', +s.dataset.v === currentDays));
}

function initRange() {
  const input = document.getElementById('range');
  const field = document.getElementById('range-field');
  const ticks = document.getElementById('range-ticks');
  input.min = MIN_DAYS; input.max = MAX_DAYS; input.step = 1;

  ticks.innerHTML = RANGE_TICKS.map(v =>
    `<span data-v="${v}" style="left:${(v - MIN_DAYS) / (MAX_DAYS - MIN_DAYS) * 100}%">${v === 1 ? '1 día' : v + ' d'}</span>`
  ).join('');

  let debounce = null, hideBubble = null;
  const commit = () => {
    store.set(RANGE_KEY, String(currentDays));
    refreshCharts(true);
  };
  const setDays = (d, immediate) => {
    d = clampDays(d);
    if (d === currentDays) return;
    currentDays = d;
    paintRange();
    clearTimeout(debounce);
    debounce = setTimeout(commit, immediate ? 0 : 350);
  };
  const flashBubble = () => {
    field.classList.add('active');
    clearTimeout(hideBubble);
    hideBubble = setTimeout(() => field.classList.remove('active'), 1200);
  };

  input.addEventListener('input', () => { setDays(+input.value); flashBubble(); });
  input.addEventListener('pointerdown', flashBubble);
  ticks.addEventListener('click', e => {
    const t = e.target.closest('span[data-v]');
    if (t) { setDays(+t.dataset.v, true); flashBubble(); }
  });
  paintRange();
}

// ── PDF / Print ───────────────────────────────────────────────────────────
// Antes de imprimir: tema claro y hojas A4 reales armadas con las tarjetas
// visibles (en el orden del usuario). Cada gráfica se agrega a la hoja actual
// y, si no entra, pasa a una hoja nueva; así el pie queda siempre al fondo.
// Al terminar se devuelven las tarjetas a su lugar. Se engancha a
// beforeprint/afterprint para que también funcione con Ctrl+P.
let printState = null;

function el(tag, cls, html) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html) e.innerHTML = html;
  return e;
}

function buildPrintPages() {
  const root = document.getElementById('print-pages');
  const footerTpl = document.getElementById('tpl-print-footer');
  const rangeText = currentDays === 1 ? 'Últimas 24 horas' : `Últimos ${currentDays} días`;
  root.innerHTML = '';

  const newPage = () => {
    const page = el('section', 'print-page');
    const body = el('div', 'pp-body');
    page.appendChild(body);
    page.appendChild(footerTpl.content.cloneNode(true));
    root.appendChild(page);
    return body;
  };
  const fits = body => body.scrollHeight <= body.clientHeight + 1;

  let body = newPage();
  const header = document.getElementById('tpl-print-header').content.cloneNode(true);
  header.querySelector('[data-print="date"]').textContent =
    new Date().toLocaleString('es-AR', { dateStyle: 'long', timeStyle: 'short' });
  header.querySelector('[data-print="range"]').textContent = rangeText;
  body.appendChild(header);

  // Lecturas actuales: se mueve la grilla entera
  const ovGrid = gridOf('overview');
  const moved = { ovGrid, ovParent: ovGrid.parentNode, ovNext: ovGrid.nextSibling, charts: [] };
  if (visibleIds('overview').length) {
    const sec = el('section', 'dash-section', '<div class="dash-section-header"><h2 class="dash-section-title">Lecturas actuales</h2></div>');
    sec.appendChild(ovGrid);
    body.appendChild(sec);
  }

  // Tendencias: una gráfica por fila, repartidas entre hojas
  let grid = null, titled = false;
  const startCharts = () => {
    const sec = el('section', 'dash-section', titled ? '' :
      `<div class="dash-section-header"><h2 class="dash-section-title">Tendencias</h2><span class="dash-section-sub">${rangeText}</span></div>`);
    grid = el('div', 'chart-grid');
    sec.appendChild(grid);
    body.appendChild(sec);
    return sec;
  };
  let sec = startCharts();
  for (const id of visibleIds('charts')) {
    const card = cardOf('charts', id);
    if (!card) continue;
    moved.charts.push(card);
    grid.appendChild(card);
    if (fits(body)) { titled = true; continue; }
    card.remove();
    if (!grid.children.length) sec.remove();   // no dejar el título solo al pie
    body = newPage();
    sec = startCharts();
    grid.appendChild(card);
    titled = true;
  }
  if (!moved.charts.length) sec.remove();
  return moved;
}

function preparePrint() {
  if (printState) return;
  const html = document.documentElement;
  printState = { theme: html.getAttribute('data-theme') };

  html.setAttribute('data-theme', 'light');
  document.body.classList.add('print-prep');
  recolorCharts();
  printState.moved = buildPrintPages();
  Object.values(chartInstances).forEach(inst => {
    inst.options.devicePixelRatio = 3;
    inst.options.animation = false;
    inst.resize();
    inst.update('none');
  });
}

function restorePrint() {
  if (!printState) return;
  const { theme, moved } = printState;
  printState = null;

  moved.ovParent.insertBefore(moved.ovGrid, moved.ovNext);
  const chartGrid = gridOf('charts');
  moved.charts.forEach(card => chartGrid.appendChild(card));
  document.getElementById('print-pages').innerHTML = '';

  document.documentElement.setAttribute('data-theme', theme);
  document.body.classList.remove('print-prep');
  recolorCharts();
  Object.values(chartInstances).forEach(inst => {
    delete inst.options.devicePixelRatio;
    inst.options.animation = REDUCED_MOTION ? false : { duration: 700, easing: 'easeOutQuart' };
    inst.resize();
    inst.update('none');
  });
}

function downloadPDF() {
  preparePrint();
  // Dar un frame para que el layout de A4 se aplique antes de abrir el diálogo
  requestAnimationFrame(() => requestAnimationFrame(() => window.print()));
}

window.addEventListener('beforeprint', preparePrint);
window.addEventListener('afterprint', restorePrint);

// ── Refresh ───────────────────────────────────────────────────────────────
function stampTime(ok) {
  const live = document.getElementById('live');
  const el = document.getElementById('db-updated');
  live.classList.toggle('on', ok);
  live.classList.toggle('off', !ok);
  el.textContent = ok
    ? 'En vivo, actualizado a las ' + new Date().toLocaleTimeString('es-AR')
    : 'Sin lecturas recientes';
}

async function refreshOverview() {
  const ids = visibleIds('overview');
  const values = await Promise.all(ids.map(async id => {
    const p = defById('overview', id);
    const v = await queryLast(p.m, p.f);
    updatePanel(p, v);
    return v;
  }));
  stampTime(values.some(v => v !== null));
}

async function refreshCharts(resetZoom) {
  await Promise.all(visibleIds('charts')
    .filter(id => chartInstances[id])
    .map(id => loadChart(defById('charts', id), resetZoom)));
}

// ── Init ──────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function () {
  initRange();

  for (const key in GROUPS) {
    buildToggles(key);
    initSortable(key);
    renderGroup(key);
  }
  syncToggles();
  refreshOverview();
  booted = true;

  document.getElementById('customize-btn').addEventListener('click', openDrawer);
  document.getElementById('drawer-close').addEventListener('click', closeDrawer);
  document.getElementById('scrim').addEventListener('click', closeDrawer);
  document.getElementById('layout-reset').addEventListener('click', resetLayout);
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeDrawer(e); });
  document.addEventListener('themechange', recolorCharts);

  const pdfBtn = document.getElementById('pdf-btn');
  if (pdfBtn) pdfBtn.addEventListener('click', downloadPDF);

  // Auto-refresh
  setInterval(refreshOverview, 30000);
  setInterval(() => refreshCharts(false), 60000);
});
