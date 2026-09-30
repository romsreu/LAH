// ── Theme toggle ──
// Con View Transitions API el tema nuevo se revela en un círculo que crece
// desde el botón; sin soporte (o con reduced-motion) se hace un fundido de colores.
(function() {
  var html = document.documentElement;
  var saved = null;
  try { saved = localStorage.getItem('theme'); } catch (_) {}
  if (!saved) saved = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  html.setAttribute('data-theme', saved);

  function applyTheme(next) {
    html.setAttribute('data-theme', next);
    try { localStorage.setItem('theme', next); } catch (_) {}
    document.dispatchEvent(new CustomEvent('themechange', { detail: next }));
  }

  var animando = false;

  document.addEventListener('DOMContentLoaded', function() {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    btn.addEventListener('click', function() {
      var next = html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      var reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

      if (!document.startViewTransition || reduced) {
        document.body.classList.add('theme-transitioning');
        applyTheme(next);
        setTimeout(function() { document.body.classList.remove('theme-transitioning'); }, 450);
        return;
      }

      if (animando) return;   // ignorar clicks mientras dura el efecto
      animando = true;

      var r = btn.getBoundingClientRect();
      var x = r.left + r.width / 2;
      var y = r.top + r.height / 2;
      var radius = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
      // El tema nuevo arranca ya recortado a un círculo de radio 0 desde CSS
      // (ver ::view-transition-new en styles.css): así no se ve un cuadro con
      // todo el tema nuevo antes de que empiece la animación.
      html.style.setProperty('--vt-x', x + 'px');
      html.style.setProperty('--vt-y', y + 'px');
      // mientras dura, se congelan las transiciones de color de la página
      html.classList.add('vt-activa');

      var t = document.startViewTransition(function() { applyTheme(next); });
      t.ready.then(function() {
        html.animate(
          { clipPath: ['circle(0px at ' + x + 'px ' + y + 'px)', 'circle(' + radius + 'px at ' + x + 'px ' + y + 'px)'] },
          { duration: 650, easing: 'cubic-bezier(0.33, 1, 0.68, 1)', fill: 'both', pseudoElement: '::view-transition-new(root)' }
        );
      });
      t.finished.finally(function() {
        html.classList.remove('vt-activa');
        animando = false;
      });
    });
  });
})();

// ── Shared active state ──
var activeEl = null;

function clearActive() {
  if (activeEl) {
    activeEl.classList.remove('active');
    activeEl = null;
  }
  postToGodot(null);
}

function postToGodot(id) {
  var iframe = document.getElementById('godot-iframe');
  if (iframe && iframe.contentWindow) {
    iframe.contentWindow.postMessage({ sensor: id }, '*');
  }
}

// ── NFT steps ──
function selectStep(el) {
  if (activeEl === el) { clearActive(); return; }
  if (activeEl) activeEl.classList.remove('active');
  el.classList.add('active');
  activeEl = el;
  postToGodot(el.dataset.sensor);
}
