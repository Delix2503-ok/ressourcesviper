'use strict';

const panel = document.getElementById('panel');

// ── Tabs ─────────────────────────────────────────────────────────────────────

document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById('tab-' + tab.dataset.tab).classList.add('active');
    });
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function nuiFetch(action, data) {
    return fetch(`https://viper-coca/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

function fmtCoords(o) {
    if (!o || o.x === undefined) return '—';
    return `${o.x.toFixed(1)}, ${o.y.toFixed(1)}, ${o.z.toFixed(1)}`;
}

function updateUI(data) {
    const zone = data.zone;
    const npc  = data.npc;
    const price = data.price;

    // Zone tab
    const zStatus = document.getElementById('zone-status');
    if (zone && zone.x) {
        zStatus.textContent = zone.active ? 'Active' : 'Inactive';
        zStatus.className = 'badge ' + (zone.active ? 'badge-on' : 'badge-off');
        document.getElementById('zone-pos').textContent = fmtCoords(zone);
        document.getElementById('zone-radius').textContent = zone.radius ? zone.radius + ' m' : '—';
    } else {
        zStatus.textContent = 'Aucune';
        zStatus.className = 'badge badge-off';
        document.getElementById('zone-pos').textContent = '—';
        document.getElementById('zone-radius').textContent = '—';
    }

    // NPC tab
    const nStatus = document.getElementById('npc-status');
    if (npc && npc.x) {
        nStatus.textContent = 'Présent';
        nStatus.className = 'badge badge-on';
        document.getElementById('npc-pos').textContent = fmtCoords(npc);
    } else {
        nStatus.textContent = 'Absent';
        nStatus.className = 'badge badge-off';
        document.getElementById('npc-pos').textContent = '—';
    }

    // Config tab
    document.getElementById('current-price').textContent = price !== undefined ? `$${price}` : '—';
}

// ── Message from client ───────────────────────────────────────────────────────

window.addEventListener('message', e => {
    const { action, data } = e.data;
    if (action === 'open') {
        updateUI(data);
        panel.classList.remove('hidden');
    } else if (action === 'update') {
        updateUI(data);
    }
});

// ── Close ─────────────────────────────────────────────────────────────────────

function closePanel() {
    panel.classList.add('hidden');
    nuiFetch('close');
}

document.getElementById('btn-close').addEventListener('click', closePanel);

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closePanel();
});

// ── Zone buttons ──────────────────────────────────────────────────────────────

document.getElementById('btn-set-zone').addEventListener('click', () => {
    const radius = parseInt(document.getElementById('input-radius').value) || 30;
    nuiFetch('setZone', { radius });
});

document.getElementById('btn-toggle-zone').addEventListener('click', () => {
    nuiFetch('toggleZone');
});

// ── NPC buttons ───────────────────────────────────────────────────────────────

document.getElementById('btn-spawn-npc').addEventListener('click', () => {
    nuiFetch('spawnNpc');
});

document.getElementById('btn-delete-npc').addEventListener('click', () => {
    nuiFetch('deleteNpc');
});

// ── Config buttons ────────────────────────────────────────────────────────────

document.getElementById('btn-set-price').addEventListener('click', () => {
    const price = parseInt(document.getElementById('input-price').value) || 0;
    nuiFetch('setPrice', { price });
});
