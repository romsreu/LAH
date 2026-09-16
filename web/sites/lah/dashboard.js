// ── InfluxDB config ───────────────────────────────────────────────────────
const INFLUX = {
  url:    'https://us-east-1-1.aws.cloud2.influxdata.com',
  token:  '2XskEdBZSQpRpDpf9JV7MC1Yv2z6HUBvPdhIQbqmIwQSp7UwNPWU9yaW3kNg3TBtImkhUp8ojXBd8K_Kb0-0xw==',
  org:    'romsreu',
  bucket: 'hydrolab',
};

// ── Rangos disponibles ────────────────────────────────────────────────────
const RANGES = [
  { value: '-1h',  label: '1 h'     },
  { value: '-6h',  label: '6 h'     },
  { value: '-12h', label: '12 h'    },
  { value: '-24h', label: '24 h'    },
  { value: '-7d',  label: '7 días'  },
  { value: '-30d', label: '30 días' },
];

// Agregación automática según rango para no sobrecargar
const AGG = {
  '-1h':  null,
  '-6h':  '5m',
  '-12h': '10m',
  '-24h': '30m',
  '-7d':  '3h',
  '-30d': '12h',
};

let currentRange = '-6h';

// ── Panel definitions ─────────────────────────────────────────────────────
const OVERVIEW_PANELS = [
  { id: 'temp-ext',  label: 'Temperatura Exterior',     m: 'temperatura', f: 'exterior',            unit: '°C',    dec: 1 },
  { id: 'temp-int',  label: 'Temperatura Interior',     m: 'temperatura', f: 'interior',            unit: '°C',    dec: 1 },
  { id: 'temp-sols', label: 'Temp. Solución Superior',  m: 'temperatura', f: 'sol_superior',         unit: '°C',    dec: 1 },
  { id: 'temp-soli', label: 'Temp. Solución Inferior',  m: 'temperatura', f: 'sol_inferior',         unit: '°C',    dec: 1 },
  { id: 'hum-ext',   label: 'Humedad Exterior',         m: 'humedad',     f: 'exterior',            unit: '%',     dec: 1 },
  { id: 'hum-int',   label: 'Humedad Interior',         m: 'humedad',     f: 'interior',            unit: '%',     dec: 1 },
  { id: 'ec',        label: 'Electroconductividad',     m: 'quimica',     f: 'electroconductividad', unit: 'mS/cm', dec: 2 },
  { id: 'ph',        label: 'pH',                       m: 'quimica',     f: 'ph',                  unit: '',      dec: 2 },
];

// ── Chart definitions ─────────────────────────────────────────────────────
const TREND_CHARTS = [
  { id: 'chart-temp-ext',  label: 'Temperatura Exterior',    m: 'temperatura', f: 'exterior',             color: '#3fa83c', unit: '°C'    },
  { id: 'chart-temp-int',  label: 'Temperatura Interior',    m: 'temperatura', f: 'interior',             color: '#f5a623', unit: '°C'    },
  { id: 'chart-temp-sols', label: 'Temp. Solución Superior', m: 'temperatura', f: 'sol_superior',          color: '#e87d3e', unit: '°C'    },
  { id: 'chart-temp-soli', label: 'Temp. Solución Inferior', m: 'temperatura', f: 'sol_inferior',          color: '#5b9bd5', unit: '°C'    },
  { id: 'chart-hum-ext',   label: 'Humedad Exterior',        m: 'humedad',     f: 'exterior',             color: '#29b6f6', unit: '%'     },
  { id: 'chart-hum-int',   label: 'Humedad Interior',        m: 'humedad',     f: 'interior',             color: '#7e57c2', unit: '%'     },
  { id: 'chart-ph',        label: 'pH',                      m: 'quimica',     f: 'ph',                   color: '#26c6da', unit: ''      },
  { id: 'chart-ec',        label: 'Electroconductividad',    m: 'quimica',     f: 'electroconductividad',  color: '#ff7043', unit: 'mS/cm' },
];

const chartInstances = {};

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
    `from(bucket: "${INFLUX.bucket}")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "${measurement}" and r._field == "${field}")
  |> last()`
  );
  return csv ? parseLastValue(csv) : null;
}

async function queryTimeSeries(measurement, field, range) {
  const agg = AGG[range];
  const aggClause = agg
    ? `|> aggregateWindow(every: ${agg}, fn: mean, createEmpty: false)`
    : '';
  const csv = await influxQuery(
    `from(bucket: "${INFLUX.bucket}")
  |> range(start: ${range})
  |> filter(fn: (r) => r._measurement == "${measurement}" and r._field == "${field}")
  ${aggClause}
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

// ── Panel rendering ───────────────────────────────────────────────────────
function buildPanelHTML(p) {
  return `<div class="db-stat" id="panel-${p.id}" data-status="loading">
  <span class="db-stat-label">${p.label}</span>
  <div class="db-stat-body">
    <span class="db-stat-num">—</span>
    <span class="db-stat-unit">${p.unit}</span>
  </div>
</div>`;
}

function updatePanel(p, value) {
  const el = document.getElementById('panel-' + p.id);
  if (!el) return;
  // Siempre verde mientras se definen los rangos
  el.dataset.status = value !== null ? 'ok' : 'loading';
  el.querySelector('.db-stat-num').textContent = value !== null ? value.toFixed(p.dec) : '—';
}

// ── Chart rendering ───────────────────────────────────────────────────────
function fmtLabel(date, range) {
  if (range === '-7d' || range === '-30d') {
    return date.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' })
      + ' ' + date.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' });
  }
  return date.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' });
}

function buildChartHTML(c) {
  return `<div class="chart-card">
  <span class="chart-card-label">${c.label}</span>
  <div class="chart-wrap"><canvas id="${c.id}"></canvas></div>
</div>`;
}

function initChart(c) {
  const canvas = document.getElementById(c.id);
  if (!canvas) return;
  chartInstances[c.id] = new Chart(canvas.getContext('2d'), {
    type: 'line',
    data: { labels: [], datasets: [{ label: c.label, data: [],
      borderColor: c.color, backgroundColor: c.color + '22',
      fill: true, tension: 0.35, pointRadius: 0, borderWidth: 2,
    }]},
    options: {
      responsive: true, maintainAspectRatio: false, animation: false,
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: ctx => `${ctx.parsed.y.toFixed(1)} ${c.unit}` } },
      },
      scales: {
        x: { ticks: { maxTicksLimit: 8, color: '#a89880', font: { size: 10 } }, grid: { color: 'rgba(0,0,0,0.06)' } },
        y: { ticks: { color: '#a89880', font: { size: 10 }, callback: v => v.toFixed(1) + ' ' + c.unit }, grid: { color: 'rgba(0,0,0,0.06)' } },
      },
    },
  });
}

function updateChart(c, points, range) {
  const inst = chartInstances[c.id];
  if (!inst) return;
  inst.data.labels = points.map(p => fmtLabel(p.x, range));
  inst.data.datasets[0].data = points.map(p => p.y);
  inst.update();
}

// ── Time filter UI ────────────────────────────────────────────────────────
function buildRangeButtons() {
  const container = document.getElementById('range-filter');
  if (!container) return;
  container.innerHTML = RANGES.map(r =>
    `<button class="tf-btn${r.value === currentRange ? ' active' : ''}" data-range="${r.value}">${r.label}</button>`
  ).join('');
  container.addEventListener('click', function(e) {
    const btn = e.target.closest('.tf-btn');
    if (!btn) return;
    currentRange = btn.dataset.range;
    container.querySelectorAll('.tf-btn').forEach(b => b.classList.toggle('active', b === btn));
    updateRangeTitle();
    refreshCharts();
  });
}

function updateRangeTitle() {
  const el = document.getElementById('charts-range-label');
  if (!el) return;
  const r = RANGES.find(r => r.value === currentRange);
  el.textContent = r ? 'últimas ' + r.label : '';
}

// ── PDF / Print ───────────────────────────────────────────────────────────
function downloadPDF() {
  const el = document.getElementById('print-date');
  if (el) el.textContent = 'Generado: ' + new Date().toLocaleString('es-AR');
  window.print();
}

// ── Refresh ───────────────────────────────────────────────────────────────
function stampTime() {
  const el = document.getElementById('db-updated');
  if (el) el.textContent = 'Última actualización: ' + new Date().toLocaleTimeString('es-AR');
}

async function refreshOverview() {
  await Promise.all(OVERVIEW_PANELS.map(async p => {
    updatePanel(p, await queryLast(p.m, p.f));
  }));
  stampTime();
}

async function refreshCharts() {
  await Promise.all(TREND_CHARTS.map(async c => {
    updateChart(c, await queryTimeSeries(c.m, c.f, currentRange), currentRange);
  }));
}

// ── Init ──────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function () {
  // Stat panels
  const grid = document.getElementById('overview-grid');
  if (grid) grid.innerHTML = OVERVIEW_PANELS.map(buildPanelHTML).join('');

  // Charts
  const chartGrid = document.getElementById('chart-grid');
  if (chartGrid) {
    chartGrid.innerHTML = TREND_CHARTS.map(buildChartHTML).join('');
    TREND_CHARTS.forEach(initChart);
  }

  buildRangeButtons();
  updateRangeTitle();

  // PDF button
  const pdfBtn = document.getElementById('pdf-btn');
  if (pdfBtn) pdfBtn.addEventListener('click', downloadPDF);

  // Carga inicial
  refreshOverview();
  refreshCharts();

  // Auto-refresh
  setInterval(refreshOverview, 30000);
  setInterval(refreshCharts,  60000);
});
