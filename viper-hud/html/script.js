'use strict';

function post(name, data) {
  fetch(`https://viper-hud/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {})
  });
}

/* ============================================================
   HUD
   ============================================================ */
const hud         = document.getElementById('hud');
const healthFill  = document.getElementById('health-fill');
const healthLabel = document.getElementById('health-label');
const armorFill   = document.getElementById('armor-fill');
const armorLabel  = document.getElementById('armor-label');

function updateHUD(hp, armor) {
  healthFill.style.width  = Math.max(0, Math.min(100, hp))    + '%';
  healthLabel.textContent = hp;
  armorFill.style.width   = Math.max(0, Math.min(100, armor)) + '%';
  armorLabel.textContent  = armor;
}

/* ============================================================
   ARME & MUNITIONS
   ============================================================ */
const weaponSection = document.getElementById('weapon-section');
const weaponImgEl   = document.getElementById('weapon-img');
const ammoSection   = document.getElementById('ammo-section');
const ammoClipEl    = document.getElementById('ammo-clip');
const ammoTotalEl   = document.getElementById('ammo-total');

function updateWeapon(spawnName, clip, total) {
  if (!spawnName) {
    weaponSection.classList.add('invisible');
    ammoSection.classList.add('invisible');
    return;
  }
  weaponSection.classList.remove('invisible');
  ammoSection.classList.remove('invisible');
  const name = spawnName.toLowerCase();
  weaponImgEl.src = 'nui://ox_inventory/web/images/' + name + '.png';
  weaponImgEl.onerror = () => {
    weaponImgEl.onerror = null;
    weaponImgEl.src = 'nui://ggcweapons/images/' + name + '.png';
    weaponImgEl.onerror = () => { weaponImgEl.src = ''; };
  };
  ammoClipEl.textContent  = clip;
  ammoTotalEl.textContent = total;
}

/* ============================================================
   BARRES DE PROGRESSION GENERIQUES
   ============================================================ */
let activeAnim = null;  // annulation possible

function startProgress(boxId, fillId, pctId, durationMs, doneCb) {
  if (activeAnim) {
    cancelAnimationFrame(activeAnim);
    activeAnim = null;
  }
  // Masque toutes les fenetres avant d'ouvrir la nouvelle
  document.getElementById('health-prog').classList.add('hidden');
  document.getElementById('armor-prog').classList.add('hidden');
  document.getElementById('safe-prog').classList.add('hidden');

  const box  = document.getElementById(boxId);
  const fill = document.getElementById(fillId);
  const pct  = document.getElementById(pctId);

  box.classList.remove('hidden');
  fill.style.width   = '0%';
  pct.textContent    = '0%';

  const start = performance.now();

  function tick(now) {
    const progress = Math.min(100, ((now - start) / durationMs) * 100);
    fill.style.width  = progress + '%';
    pct.textContent   = Math.floor(progress) + '%';

    if (progress < 100) {
      activeAnim = requestAnimationFrame(tick);
    } else {
      activeAnim = null;
      setTimeout(() => {
        box.classList.add('hidden');
        if (doneCb) doneCb();
      }, 250);
    }
  }
  activeAnim = requestAnimationFrame(tick);
}

function cancelProgress() {
  if (activeAnim) {
    cancelAnimationFrame(activeAnim);
    activeAnim = null;
  }
  document.getElementById('health-prog').classList.add('hidden');
  document.getElementById('armor-prog').classList.add('hidden');
  document.getElementById('safe-prog').classList.add('hidden');
}

/* ============================================================
   PANEL ADMIN
   ============================================================ */
const adminPanel = document.getElementById('admin-panel');
const playerList = document.getElementById('player-list');
const kickModal  = document.getElementById('kick-modal');
let pendingKick  = null;

// Tabs
document.querySelectorAll('.atab').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.atab').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById('tab-' + btn.dataset.tab).classList.add('active');
  });
});

// Fermer
document.getElementById('close-btn').addEventListener('click', closeAdmin);
function closeAdmin() {
  adminPanel.classList.add('hidden');
  post('closeAdmin');
}

// Rafraichir joueurs
document.getElementById('refresh-players').addEventListener('click', () => post('getPlayers'));

// Rendu joueurs
function renderPlayers(players) {
  if (!players || players.length === 0) {
    playerList.innerHTML = '<div class="empty-msg">Aucun joueur en ligne.</div>';
    return;
  }
  playerList.innerHTML = players.map(p => `
    <div class="player-card">
      <div class="player-id">${p.id}</div>
      <div class="player-info">
        <div class="player-name">${esc(p.name)}</div>
        <div class="player-meta">${esc(p.group)} • ${p.ping} ms</div>
      </div>
      <div class="player-actions">
        <button class="pact-btn pact-heal"  onclick="playerAction('healAll',${p.id})">♥</button>
        <button class="pact-btn pact-armor" onclick="playerAction('healArmor',${p.id})">⬡</button>
        <button class="pact-btn pact-kick"  onclick="confirmKick(${p.id})">✕</button>
      </div>
    </div>`).join('');
}

function playerAction(action, id) { post('adminAction', { action, target: id }); }

function confirmKick(id) {
  pendingKick = id;
  document.getElementById('kick-reason').value = '';
  kickModal.classList.remove('hidden');
}
document.getElementById('modal-cancel').addEventListener('click', () => {
  kickModal.classList.add('hidden'); pendingKick = null;
});
document.getElementById('modal-confirm').addEventListener('click', () => {
  const reason = document.getElementById('kick-reason').value.trim() || 'Expulsé par un admin';
  if (pendingKick !== null) { post('adminAction', { action: 'kick', target: pendingKick, reason }); pendingKick = null; }
  kickModal.classList.add('hidden');
});

// Toggles serveur — état synchro depuis server
document.querySelectorAll('.toggle-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const key   = btn.dataset.key;
    const state = btn.dataset.state === 'true';
    const next  = !state;
    setToggle(btn.id, next, key);
    post('adminAction', { action: key, value: next });
  });
});

// Boutons actions
document.querySelectorAll('.action-btn[data-action]').forEach(btn => {
  btn.addEventListener('click', () => {
    const action = btn.dataset.action;
    if (action === 'noop') return;
    post('adminAction', { action });
  });
});

// SafeZone coords save
document.getElementById('save-coords-btn').addEventListener('click', () => {
  const val = document.getElementById('safe-coords-input').value.trim();
  if (!val) return;
  post('adminAction', { action: 'updateSafeCoords', coords: val });
});

/* ============================================================
   NUI Message handler
   ============================================================ */
window.addEventListener('message', e => {
  const d = e.data;
  switch (d.action) {

    case 'showHUD':
      hud.classList.remove('hidden');
      if (d.playerId) document.getElementById('hud-player-id').textContent = 'ID ' + d.playerId;
      break;

    case 'hideHUD':
      hud.classList.add('hidden');
      break;

    case 'updateHUD':
      updateHUD(d.health, d.armor);
      break;

    case 'updateWeapon':
      updateWeapon(d.weaponSpawn, d.ammoClip, d.ammoTotal);
      break;

    // F3 : barre rouge 5s → soin complet
    case 'startHealthProgress':
      startProgress('health-prog', 'health-fill-prog', 'health-pct', 5000, null);
      break;

    // F4 : barre verte 3s → armure
    case 'startArmorProgress':
      startProgress('armor-prog', 'armor-fill-prog', 'armor-pct', 3000, null);
      break;

    // /safe : barre bleue 20s → callback safeDone
    case 'startSafeProgress':
      startProgress('safe-prog', 'safe-fill-prog', 'safe-pct', 20000, () => {
        post('safeDone', {});
      });
      break;

    // Annulation (joueur bouge)
    case 'cancelProgress':
      cancelProgress();
      break;

    // Panel admin : ouverture avec etat serveur synchro
    case 'openAdmin':
      adminPanel.classList.remove('hidden');
      renderPlayers(d.players);
      if (d.config) applyConfig(d.config);
      break;

    case 'closeAdmin':
      adminPanel.classList.add('hidden');
      break;

    case 'updatePlayers':
      renderPlayers(d.players);
      break;
  }
});

// Applique l'etat venant du SERVEUR (toggles toujours synchro)
function applyConfig(cfg) {
  setToggle('toggle-weather', cfg.weather, 'toggleWeather');
  setToggle('toggle-traffic', cfg.traffic, 'toggleTraffic');
  setToggle('toggle-hunger',  cfg.hunger,  'toggleHunger');
  setToggle('toggle-blips',   cfg.blips,   'toggleBlips');
  if (cfg.safeCoords) {
    document.getElementById('safe-coords-input').value = cfg.safeCoords;
  }
}

function setToggle(id, state, key) {
  const btn = document.getElementById(id);
  if (!btn) return;
  btn.dataset.state = String(state);
  btn.dataset.key   = key;
  btn.textContent   = state ? 'ON' : 'OFF';
  btn.className     = 'toggle-btn ' + (state ? 'on' : 'off');
}

function esc(str) {
  return String(str)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;')
    .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

/* ── Hitmarkers ─────────────────────────────────────────────── */
window.addEventListener('message', function(e) {
  var d = e.data;
  if (!d || d.action !== 'showDamageNumber') return;

  var el       = document.createElement('div');
  el.className = 'dmg ' + (d.isHeadshot ? 'headshot' : 'body');
  el.textContent = String(Math.floor(d.damage));
  el.style.left  = (d.x * 100) + 'vw';

  var startY = d.y * window.innerHeight;
  el.style.top    = startY + 'px';
  el.style.opacity = '1';
  document.body.appendChild(el);

  var t0 = null;
  (function step(ts) {
    if (!t0) t0 = ts;
    var p = Math.min((ts - t0) / 1000, 1);
    el.style.top     = (startY - p * 80) + 'px';
    el.style.opacity = String(1 - p);
    if (p < 1) requestAnimationFrame(step);
    else if (el.parentNode) el.parentNode.removeChild(el);
  })(performance.now());
});
