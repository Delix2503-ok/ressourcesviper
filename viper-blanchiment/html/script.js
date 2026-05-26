'use strict';

// ─── State ────────────────────────────────────────────────────────────────────
let laundryState = { blackMoney: 0, laundryRate: 0.80, minAmount: 500, maxAmount: 50000, duration: 60 };
let adminSpots   = [];

// ─── Helpers ──────────────────────────────────────────────────────────────────
const $  = id => document.getElementById(id);
const fmt = n  => Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

function resourceName() {
  return window.GetParentResourceName ? window.GetParentResourceName() : 'viper-blanchiment';
}

function post(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data ?? {}),
  });
}

function toast(msg, type = 'success') {
  let c = document.getElementById('toast-container');
  if (!c) {
    c = document.createElement('div');
    c.id = 'toast-container';
    document.body.appendChild(c);
  }
  const t = document.createElement('div');
  t.className = `toast ${type}`;
  t.textContent = msg;
  c.appendChild(t);
  setTimeout(() => { t.style.opacity = '0'; t.style.transition = 'opacity 0.4s'; }, 2800);
  setTimeout(() => t.remove(), 3200);
}

// ─── Message handler (FiveM → NUI) ───────────────────────────────────────────
window.addEventListener('message', ({ data }) => {
  switch (data.action) {
    case 'openLaundry':    openLaundry(data);            break;
    case 'openAdmin':      openAdmin(data);              break;
    case 'closeAdmin':     closeAdminPanel();            break;
    case 'updateSpots':    updateSpots(data.spots);      break;
    case 'startProgress':  startProgress(data);          break;
    case 'updateProgress': updateProgress(data);         break;
    case 'stopProgress':   stopProgress();               break;
  }
});

// ─── Laundry ──────────────────────────────────────────────────────────────────
function openLaundry(data) {
  laundryState = {
    blackMoney  : data.blackMoney  ?? 0,
    laundryRate : data.laundryRate ?? 0.80,
    minAmount   : data.minAmount   ?? 500,
    maxAmount   : data.maxAmount   ?? 50000,
    duration    : data.duration    ?? 60,
  };

  $('black-money-amount').textContent = '$' + fmt(laundryState.blackMoney);
  $('rate-value').textContent = Math.round(laundryState.laundryRate * 100) + '%';
  $('duration-label').textContent = laundryState.duration;
  $('vip-badge').classList.toggle('hidden', !data.isVip);
  $('laundry-amount').value = '';
  refreshPreview();

  $('laundry-overlay').classList.remove('hidden');
  $('laundry-amount').focus();
}

function closeLaundry() {
  $('laundry-overlay').classList.add('hidden');
  post('closeLaundry');
}

function refreshPreview() {
  const amount  = parseInt($('laundry-amount').value) || 0;
  const receive = Math.floor(amount * laundryState.laundryRate);
  const fee     = amount - receive;
  $('preview-receive').textContent = '$' + fmt(receive);
  $('preview-fee').textContent     = '$' + fmt(fee);
}

function setMax() {
  const max = Math.min(laundryState.blackMoney, laundryState.maxAmount);
  $('laundry-amount').value = max;
  refreshPreview();
}

function quickAmount(n) {
  const capped = Math.min(n, laundryState.blackMoney, laundryState.maxAmount);
  $('laundry-amount').value = capped;
  refreshPreview();
}

function startLaundry() {
  const amount = parseInt($('laundry-amount').value) || 0;

  if (amount < laundryState.minAmount) {
    toast(`Minimum: $${fmt(laundryState.minAmount)}`, 'error');
    return;
  }
  if (amount > laundryState.blackMoney) {
    toast('Argent sale insuffisant !', 'error');
    return;
  }
  if (amount > laundryState.maxAmount) {
    toast(`Maximum par session: $${fmt(laundryState.maxAmount)}`, 'error');
    return;
  }

  closeLaundry();
  post('startLaundry', { amount });
}

$('laundry-amount').addEventListener('input', refreshPreview);

// ─── Admin ────────────────────────────────────────────────────────────────────
function openAdmin(data) {
  adminSpots = data.spots ?? [];

  // Peupler le select des modèles de PED
  const sel = $('ped-model-select');
  sel.innerHTML = '';
  (data.pedModels ?? []).forEach(pm => {
    const opt = document.createElement('option');
    opt.value       = pm.model;
    opt.textContent = pm.label;
    sel.appendChild(opt);
  });

  renderSpots();
  $('admin-overlay').classList.remove('hidden');
}

function closeAdminPanel() { $('admin-overlay').classList.add('hidden'); }

function closeAdmin() {
  closeAdminPanel();
  post('closeAdmin');
}

function updateSpots(spots) {
  adminSpots = spots ?? [];
  if (!$('admin-overlay').classList.contains('hidden')) renderSpots();
}

function renderSpots() {
  const container = $('spots-list');
  $('spots-count').textContent = adminSpots.length;

  if (adminSpots.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <i class="fas fa-map-marked-alt"></i>
        <p>Aucun spot configuré.<br>Ajoutez-en un ci-dessus.</p>
      </div>`;
    return;
  }

  container.innerHTML = adminSpots.map(s => `
    <div class="spot-card" id="spot-card-${s.id}">
      <span class="spot-id">#${s.id}</span>
      <div class="spot-info">
        <div class="spot-name">${escHtml(s.name)}</div>
        <div class="spot-meta">
          X: ${s.x.toFixed(1)} &nbsp;Y: ${s.y.toFixed(1)} &nbsp;Z: ${s.z.toFixed(1)}
          &nbsp;·&nbsp; ${escHtml(s.pedModel)}
        </div>
      </div>
      <div class="spot-actions">
        <button class="btn-icon tp" onclick="teleportToSpot(${s.id})" title="Téléporter">
          <i class="fas fa-location-arrow"></i>
        </button>
        <button class="btn-icon del" onclick="removeSpot(${s.id})" title="Supprimer">
          <i class="fas fa-trash"></i>
        </button>
      </div>
    </div>
  `).join('');
}

function addSpot() {
  const name     = $('spot-name').value.trim();
  const pedModel = $('ped-model-select').value;
  post('addSpot', { name, pedModel });
  $('spot-name').value = '';
}

function removeSpot(id) {
  post('removeSpot', { id });
}

function teleportToSpot(id) {
  post('teleportToSpot', { id });
}

// ─── Keyboard shortcuts ───────────────────────────────────────────────────────
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    if (!$('laundry-overlay').classList.contains('hidden')) closeLaundry();
    else if (!$('admin-overlay').classList.contains('hidden'))  closeAdmin();
  }
  if (e.key === 'Enter' && !$('laundry-overlay').classList.contains('hidden')) startLaundry();
});

// ─── Barre de progression ─────────────────────────────────────────────────────
function startProgress(data) {
  $('progress-money-info').textContent =
    '$' + fmt(data.amount) + ' → $' + fmt(data.receive);
  $('progress-time-info').textContent = '...';
  $('progress-fill').style.width = '0%';
  $('progress-pct').textContent  = '0%';
  $('progress-bar-overlay').classList.remove('hidden');
}

function updateProgress(data) {
  const pct = Math.min(Math.round(data.pct), 100);
  $('progress-fill').style.width = pct + '%';
  $('progress-pct').textContent  = pct + '%';
  $('progress-time-info').textContent = data.remaining + 's';
}

function stopProgress() {
  $('progress-bar-overlay').classList.add('hidden');
  $('progress-fill').style.width = '0%';
}

// ─── Utils ────────────────────────────────────────────────────────────────────
function escHtml(str) {
  return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
