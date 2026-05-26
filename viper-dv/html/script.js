'use strict';

const $ = id => document.getElementById(id);

function rn() {
  return window.GetParentResourceName ? window.GetParentResourceName() : 'viper-dv';
}

function post(endpoint, data) {
  return fetch(`https://${rn()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data ?? {}),
  });
}

// ─── Messages FiveM → NUI ─────────────────────────────────────────────────────

window.addEventListener('message', ({ data }) => {
  switch (data.action) {
    case 'openPanel':
      $('panel').classList.remove('hidden');
      renderZones(data.zones ?? []);
      break;
    case 'updateZones':
      renderZones(data.zones ?? []);
      break;
  }
});

// ─── Fermer ───────────────────────────────────────────────────────────────────

function closePanel() {
  $('panel').classList.add('hidden');
  post('closePanel');
}

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closePanel();
});

// ─── DV ──────────────────────────────────────────────────────────────────────

function setRadius(n) {
  $('dv-radius').value = n;
}

function doDv() {
  const radius = parseInt($('dv-radius').value) || 30;
  post('dvRadius', { radius });
  closePanel();
}

// ─── Zones parking ────────────────────────────────────────────────────────────

function addZone() {
  const name = $('zone-name').value.trim();
  if (!name) { $('zone-name').focus(); return; }
  post('addZone', { name });
  $('zone-name').value = '';
  closePanel();
}

function removeZone(id) {
  post('removeZone', { id });
}

function tpZone(id) {
  post('tpZone', { id });
  closePanel();
}

function renderZones(zones) {
  const list = $('zones-list');
  if (!zones || zones.length === 0) {
    list.innerHTML = '<div class="empty-zones">Aucune zone configurée.</div>';
    return;
  }
  list.innerHTML = zones.map(z => `
    <div class="zone-card" id="zone-${z.id}">
      <span class="zone-id">#${z.id}</span>
      <span class="zone-name">${esc(z.name)}</span>
      <span class="zone-coords">${z.x.toFixed(0)}, ${z.y.toFixed(0)}</span>
      <div class="zone-actions">
        <button class="btn-icon tp"  onclick="tpZone(${z.id})"    title="TP"><i class="fas fa-location-arrow"></i></button>
        <button class="btn-icon del" onclick="removeZone(${z.id})" title="Supprimer"><i class="fas fa-trash"></i></button>
      </div>
    </div>
  `).join('');
}

function esc(str) {
  return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
