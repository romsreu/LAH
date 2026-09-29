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

      var r = btn.getBoundingClientRect();
      var x = r.left + r.width / 2;
      var y = r.top + r.height / 2;
      var radius = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));

      var t = document.startViewTransition(function() { applyTheme(next); });
      t.ready.then(function() {
        html.animate(
          { clipPath: ['circle(0px at ' + x + 'px ' + y + 'px)', 'circle(' + radius + 'px at ' + x + 'px ' + y + 'px)'] },
          { duration: 700, easing: 'cubic-bezier(0.65, 0, 0.25, 1)', pseudoElement: '::view-transition-new(root)' }
        );
      });
    });
  });
})();

// ── Help tooltip toggle ──
document.addEventListener('DOMContentLoaded', function() {
  var helpBtn = document.getElementById('viz-help-btn');
  var helpTip = document.getElementById('viz-help-tooltip');
  if (!helpBtn || !helpTip) return;
  helpBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    var open = helpTip.classList.toggle('show');
    helpBtn.classList.toggle('open', open);
  });
  document.addEventListener('click', function() {
    helpTip.classList.remove('show');
    helpBtn.classList.remove('open');
  });
});

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
