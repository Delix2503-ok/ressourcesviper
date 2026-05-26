'use strict';

const RESOURCE = window.GetParentResourceName ? window.GetParentResourceName() : 'vipertpramp';

function nuiFetch(endpoint, data) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).catch(() => {});
}

function esc(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

// ── Tabs ───────────────────────────────────────────────────────────────────
function switchTab(name, btn) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));
    btn.classList.add('active');
    document.getElementById('tab-' + name).classList.remove('hidden');
}

// ── Admin Panel ────────────────────────────────────────────────────────────
function openAdmin(npcs, zones) {
    renderNpcList(npcs || []);
    renderZoneList(zones || []);
    document.getElementById('admin-panel').classList.remove('hidden');
}

function closeAdmin() {
    document.getElementById('admin-panel').classList.add('hidden');
    nuiFetch('closeAdmin');
}

// ── NPC ────────────────────────────────────────────────────────────────────
let selectedNpcType = 'npc';

function setNpcType(t) {
    selectedNpcType = t;
    document.getElementById('type-npc').classList.toggle('active', t === 'npc');
    document.getElementById('type-marker').classList.toggle('active', t === 'marker');
}

function addNpc() {
    const name = document.getElementById('npc-name-input').value.trim();
    if (!name) return;
    document.getElementById('npc-name-input').value = '';
    nuiFetch('createNpc', { name, type: selectedNpcType });
}

function renderNpcList(list) {
    const el = document.getElementById('npc-list');
    if (!list || !list.length) {
        el.innerHTML = '<div class="no-items">Aucun point configuré.</div>';
        return;
    }
    list.sort((a, b) => a.name.localeCompare(b.name));
    el.innerHTML = list.map(n => `
        <div class="list-item">
            <span class="type-badge ${n.type === 'marker' ? 'badge-marker' : 'badge-npc'}">${n.type === 'marker' ? 'MRK' : 'PNJ'}</span>
            <span class="item-name">${esc(n.name)}</span>
            <span class="item-sub">${Math.round(n.x)}, ${Math.round(n.y)}</span>
            <button class="btn-sm btn-tp" onclick="adminTpToNpc(${n.id})">TP</button>
            <button class="btn-sm btn-del" onclick="deleteNpc(${n.id})">SUPPR</button>
        </div>
    `).join('');
}

function adminTpToNpc(id) { nuiFetch('adminTpToNpc', { id }); }
function deleteNpc(id)    { nuiFetch('deleteNpc', { id }); }

// ── Zones ──────────────────────────────────────────────────────────────────
function addZone() {
    const name   = document.getElementById('zone-name-input').value.trim();
    const radius = parseFloat(document.getElementById('zone-radius-input').value) || 50;
    if (!name) return;
    document.getElementById('zone-name-input').value = '';
    nuiFetch('createZone', { name, radius });
}

function renderZoneList(list) {
    const el = document.getElementById('zone-list');
    if (!list || !list.length) {
        el.innerHTML = '<div class="no-items">Aucune zone configurée.</div>';
        return;
    }
    list.sort((a, b) => a.name.localeCompare(b.name));
    el.innerHTML = list.map(z => `
        <div class="list-item">
            <span class="item-name">${esc(z.name)}</span>
            <span class="item-sub">r = ${z.radius}m</span>
            <button class="btn-sm btn-del" onclick="deleteZone(${z.id})">SUPPR</button>
        </div>
    `).join('');
}

function deleteZone(id) { nuiFetch('deleteZone', { id }); }

// ── TP Select ──────────────────────────────────────────────────────────────
function showTpSelect(npcs) {
    const list = document.getElementById('tp-npc-list');
    if (!npcs || !npcs.length) {
        list.innerHTML = '<div class="no-items">Aucune destination disponible.</div>';
    } else {
        list.innerHTML = npcs.map(n => `
            <div class="tp-item" onclick="chooseTp(${n.id})">
                <span class="tp-arrow">▶</span>
                <span>${esc(n.name)}</span>
            </div>
        `).join('');
    }
    document.getElementById('tp-select').classList.remove('hidden');
}

function chooseTp(id) {
    document.getElementById('tp-select').classList.add('hidden');
    nuiFetch('tpSelectChoose', { id });
}

function closeTpSelect() {
    document.getElementById('tp-select').classList.add('hidden');
    nuiFetch('closeTpSelect');
}

// ── Messages NUI ───────────────────────────────────────────────────────────
window.addEventListener('message', function(e) {
    const d = e.data;
    switch (d.type) {
        case 'openAdmin':
            openAdmin(d.npcs, d.zones);
            break;
        case 'npcList':
            renderNpcList(d.npcs || []);
            break;
        case 'zoneList':
            renderZoneList(d.zones || []);
            break;
        case 'showTpSelect':
            showTpSelect(d.npcs);
            break;
    }
});

// ── Clavier ────────────────────────────────────────────────────────────────
document.addEventListener('keydown', function(e) {
    if (e.key !== 'Escape') return;
    const admin = document.getElementById('admin-panel');
    const tp    = document.getElementById('tp-select');
    if (!admin.classList.contains('hidden')) { closeAdmin(); }
    else if (!tp.classList.contains('hidden')) { closeTpSelect(); }
});
