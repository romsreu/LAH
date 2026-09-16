// ── Favicon invertido ──
(function() {
  var link = document.querySelector('link[rel="icon"]');
  if (!link) return;
  var img = new Image();
  img.onload = function() {
    var canvas = document.createElement('canvas');
    canvas.width  = img.naturalWidth  || 64;
    canvas.height = img.naturalHeight || 64;
    var ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0);
    var data = ctx.getImageData(0, 0, canvas.width, canvas.height);
    for (var i = 0; i < data.data.length; i += 4) {
      data.data[i]     = 255 - data.data[i];
      data.data[i + 1] = 255 - data.data[i + 1];
      data.data[i + 2] = 255 - data.data[i + 2];
    }
    ctx.putImageData(data, 0, 0);
    link.href = canvas.toDataURL('image/png');
  };
  img.src = 'icon.png';
})();

// ── Theme toggle ──
(function() {
  var html = document.documentElement;
  var saved = localStorage.getItem('theme') || 'light';
  html.setAttribute('data-theme', saved);

  document.addEventListener('DOMContentLoaded', function() {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    btn.addEventListener('click', function() {
      var next = html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      document.body.classList.add('theme-transitioning');
      html.setAttribute('data-theme', next);
      localStorage.setItem('theme', next);
      setTimeout(function() { document.body.classList.remove('theme-transitioning'); }, 300);
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

// ── Tabs ──
function switchTab(el) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.pane').forEach(p => p.classList.remove('active'));
  el.classList.add('active');
  document.getElementById('pane-' + el.dataset.tab).classList.add('active');
  clearActive();
}

// ── Shared active state ──
var activeEl = null;

function setOverlay(label) {
  var ov = document.getElementById('viz-overlay');
  document.getElementById('viz-overlay-text').textContent = label;
  ov.classList.add('show');
  var fa = document.getElementById('footer-active');
  fa.textContent = label;
  fa.classList.add('show');
}

function clearOverlay() {
  document.getElementById('viz-overlay').classList.remove('show');
  document.getElementById('footer-active').classList.remove('show');
}

function clearActive() {
  if (activeEl) {
    activeEl.classList.remove('active');
    activeEl = null;
  }
  clearOverlay();
  postToGodot(null);
}

function postToGodot(id) {
  var iframe = document.getElementById('godot-iframe');
  if (iframe && iframe.contentWindow) {
    iframe.contentWindow.postMessage({ sensor: id }, '*');
  }
}

// ── Table row toggling (sensores / actuadores) ──
function toggleRow(rowEl, detailId, label, sensorId) {
  var detail = document.getElementById(detailId);
  var isOpen = detail && detail.classList.contains('open');

  // Close all open detail rows in table
  document.querySelectorAll('.row-detail.open').forEach(function(d) {
    d.classList.remove('open');
  });
  document.querySelectorAll('tbody tr.selected').forEach(function(r) {
    r.classList.remove('selected');
  });

  if (!isOpen) {
    rowEl.classList.add('selected');
    if (detail) detail.classList.add('open');
    setOverlay(label);
    postToGodot(sensorId);
    activeEl = rowEl;
  } else {
    clearOverlay();
    postToGodot(null);
    activeEl = null;
  }
}

// ── NFT steps ──
function selectStep(el) {
  if (activeEl === el) { clearActive(); return; }
  if (activeEl) activeEl.classList.remove('active');
  el.classList.add('active');
  activeEl = el;
  var name = el.querySelector('.nft-step-title').textContent;
  var id   = el.dataset.sensor;
  setOverlay('Mostrando: ' + name);
  postToGodot(id);
}
