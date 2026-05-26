'use strict';

const RESOURCE = window.GetParentResourceName ? window.GetParentResourceName() : 'viperjail';

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

function formatTime(secs) {
    secs = Math.max(0, Math.floor(secs));
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = secs % 60;
    const pad = n => String(n).padStart(2, '0');
    if (h > 0) return `${pad(h)}:${pad(m)}:${pad(s)}`;
    return `${pad(m)}:${pad(s)}`;
}

// ── Toast (remplace alert) ─────────────────────────────────────────────────
function showToast(msg, type) {
    let toast = document.getElementById('toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'toast';
        toast.style.cssText = `
            position:fixed;top:14px;left:50%;transform:translateX(-50%);
            padding:8px 20px;border-radius:5px;font-size:12px;letter-spacing:1px;
            font-weight:bold;text-transform:uppercase;z-index:9999;
            transition:opacity 0.3s;pointer-events:none;
        `;
        document.body.appendChild(toast);
    }
    toast.style.background = type === 'error' ? 'rgba(180,20,20,0.9)' : 'rgba(20,120,20,0.9)';
    toast.style.color = '#fff';
    toast.style.border = type === 'error' ? '1px solid #ff4444' : '1px solid #39ff14';
    toast.style.opacity = '1';
    toast.textContent = msg;
    clearTimeout(toast._t);
    toast._t = setTimeout(() => { toast.style.opacity = '0'; }, 2500);
}

// ── État local ─────────────────────────────────────────────────────────────
let locations = [];
let onlinePlayers = [];
let offlinePlayers = [];

// ── Tabs ───────────────────────────────────────────────────────────────────
function switchTab(name, btn) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));
    btn.classList.add('active');
    document.getElementById('tab-' + name).classList.remove('hidden');
    if (name === 'logs') refreshLogs();
}

// ── Jail screen ────────────────────────────────────────────────────────────
function showJail(remaining) {
    document.getElementById('jail-timer').textContent = formatTime(remaining);
    document.getElementById('jail-screen').classList.remove('hidden');
}

function updateJailTimer(remaining) {
    const el = document.getElementById('jail-timer');
    if (el) el.textContent = formatTime(remaining);
}

function hideJail() {
    document.getElementById('jail-screen').classList.add('hidden');
}

// ── Admin Panel ────────────────────────────────────────────────────────────
function openAdmin(online, offline, locs) {
    locations      = locs    || [];
    onlinePlayers  = online  || [];
    offlinePlayers = offline || [];
    renderOnline(onlinePlayers);
    renderOffline(offlinePlayers);
    renderCells(locations);
    document.getElementById('admin-panel').classList.remove('hidden');
}

function closeAdmin() {
    document.getElementById('admin-panel').classList.add('hidden');
    nuiFetch('closeAdmin');
}

function refreshAdmin() {
    nuiFetch('refreshAdmin');
}

// ── Location select options ────────────────────────────────────────────────
function buildLocOptions() {
    if (!locations.length)
        return '<option value="">— aucune cellule —</option>';
    return '<option value="">Choisir…</option>' +
        locations.map(l => `<option value="${l.id}">${esc(l.name)}</option>`).join('');
}

// Met à jour tous les selects déjà dans le DOM
function refreshAllLocSelects() {
    const opts = buildLocOptions();
    document.querySelectorAll('.loc-select').forEach(sel => {
        const prev = sel.value;
        sel.innerHTML = opts;
        if (prev) sel.value = prev;
    });
}

// ── Online players ─────────────────────────────────────────────────────────
function renderOnline(list) {
    const el = document.getElementById('online-list');
    if (!list.length) {
        el.innerHTML = '<div class="no-items">Aucun joueur en ligne.</div>';
        return;
    }
    el.innerHTML = list.map(p => {
        if (p.jailed) {
            return `
            <div class="player-row" id="pr-${p.src}">
                <span class="player-name">${esc(p.name)}</span>
                <span class="badge-jailed">EN PRISON — ${formatTime(p.remaining)}</span>
                <button class="btn-sm btn-unjail" onclick="unjailPlayer(${p.src})">LIBÉRER</button>
            </div>`;
        }
        return `
        <div class="player-row" id="pr-${p.src}">
            <span class="player-name">${esc(p.name)}</span>
            <span class="badge-free">LIBRE</span>
            <div class="jail-controls">
                <input class="reason-input" type="text" id="reason-${p.src}" placeholder="Raison…" maxlength="255">
                <input class="min-input" type="number" id="min-${p.src}" min="1" max="10080" value="10" title="minutes">
                <select class="loc-select" id="loc-${p.src}">${buildLocOptions()}</select>
                <button class="btn-sm btn-jail" onclick="jailPlayer(${p.src})">JAIL</button>
            </div>
        </div>`;
    }).join('');
}

function renderOffline(list) {
    const el = document.getElementById('offline-list');
    if (!list.length) {
        el.innerHTML = '<div class="no-items">Aucun prisonnier hors ligne.</div>';
        return;
    }
    el.innerHTML = list.map(p => `
        <div class="player-row">
            <span class="player-name">${esc(p.name)}</span>
            <span class="badge-jailed">HORS LIGNE — ${formatTime(p.remaining)}</span>
            <button class="btn-sm btn-unjail" onclick="unjailOffline('${esc(p.citizenid)}')">RETIRER</button>
        </div>
    `).join('');
}

// ── Cells ──────────────────────────────────────────────────────────────────
function renderCells(list) {
    const el = document.getElementById('cell-list');
    if (!list.length) {
        el.innerHTML = '<div class="no-items">Aucune cellule configurée.</div>';
        return;
    }
    el.innerHTML = list.map(l => `
        <div class="cell-row" id="cell-${l.id}">
            <span class="cell-name">${esc(l.name)}</span>
            <span class="cell-coords">${Math.round(l.x)}, ${Math.round(l.y)}, ${Math.round(l.z)}</span>
            <button class="btn-sm btn-del" onclick="deleteLocation(${l.id})">SUPPR</button>
        </div>
    `).join('');
}

// ── Logs ───────────────────────────────────────────────────────────────────
function refreshLogs() {
    const license = document.getElementById('log-license-input').value.trim();
    if (license) nuiFetch('getLogs', { license });
}

function searchLogs() {
    const license = document.getElementById('log-license-input').value.trim();
    if (!license) { showToast('Entre une licence FiveM.', 'error'); return; }
    nuiFetch('getLogs', { license });
}

function formatDate(val) {
    if (!val) return '?';
    const d = new Date(val);
    if (isNaN(d.getTime())) return String(val).substring(0, 19).replace('T', ' ');
    return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit' })
        + ' ' + d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}

function renderLogs(list) {
    const el  = document.getElementById('log-list');
    const hdr = document.getElementById('log-player-header');
    const cnt = document.getElementById('log-entry-count');
    const nm  = document.getElementById('log-player-name');
    if (!list || !list.length) {
        el.innerHTML = '<div class="no-items">Aucun historique trouvé pour cette licence.</div>';
        if (hdr) hdr.classList.add('hidden');
        return;
    }
    if (nm)  nm.textContent  = list[0].player_name || '?';
    if (cnt) cnt.textContent = list.length + ' entrée' + (list.length > 1 ? 's' : '');
    if (hdr) hdr.classList.remove('hidden');
    el.innerHTML = list.map(l => {
        const isJail = l.action === 'JAIL';
        const badge  = isJail
            ? `<span class="badge-jailed">JAIL${l.duration_minutes ? ' ' + l.duration_minutes + 'min' : ''}</span>`
            : `<span class="badge-free">LIBÉRÉ</span>`;
        const loc    = (isJail && l.jail_location_name)
            ? `<span class="log-loc">${esc(l.jail_location_name)}</span>`
            : '';
        const reason = l.reason
            ? `<span class="log-reason">"${esc(l.reason)}"</span>`
            : '';
        return `
        <div class="log-row">
            ${badge}
            ${loc}
            ${reason}
            <span class="log-staff">par ${esc(l.staff_name)}</span>
            <span class="log-date">${esc(formatDate(l.created_at))}</span>
        </div>`;
    }).join('');
}

// ── Actions ────────────────────────────────────────────────────────────────
function jailPlayer(src) {
    const minEl    = document.getElementById('min-'    + src);
    const locEl    = document.getElementById('loc-'    + src);
    const reasonEl = document.getElementById('reason-' + src);
    const minutes    = minEl    ? (parseInt(minEl.value) || 10) : 10;
    const locationId = locEl    ? parseInt(locEl.value)         : NaN;
    const reason     = reasonEl ? reasonEl.value.trim()         : '';

    if (!locationId || isNaN(locationId)) {
        showToast('Sélectionne une cellule !', 'error');
        return;
    }
    nuiFetch('jailPlayer', { src, minutes, locationId, reason: reason || null });
}

function unjailPlayer(src) {
    nuiFetch('unjailPlayer', { src });
}

function unjailOffline(citizenid) {
    nuiFetch('unjailOffline', { citizenid });
}

function addLocation() {
    const name = document.getElementById('cell-name-input').value.trim();
    if (!name) { showToast('Entre un nom de cellule.', 'error'); return; }
    document.getElementById('cell-name-input').value = '';
    nuiFetch('addLocation', { name });
}

function deleteLocation(id) {
    nuiFetch('deleteLocation', { id });
}

// ── Messages NUI ───────────────────────────────────────────────────────────
window.addEventListener('message', function(e) {
    const d = e.data;
    switch (d.type) {
        case 'showJail':
            showJail(d.remaining);
            break;
        case 'tick':
            updateJailTimer(d.remaining);
            break;
        case 'hideJail':
            hideJail();
            break;
        case 'openAdmin':
            openAdmin(d.online, d.offline, d.locations);
            break;
        case 'locationAdded':
            locations.push(d.location);
            renderCells(locations);
            refreshAllLocSelects();   // met à jour tous les selects existants
            break;
        case 'locationDeleted':
            locations = locations.filter(l => l.id !== d.id);
            renderCells(locations);
            refreshAllLocSelects();
            break;
        case 'logsData':
            renderLogs(d.logs);
            break;
    }
});

// ── ESC ────────────────────────────────────────────────────────────────────
document.addEventListener('keydown', function(e) {
    if (e.key !== 'Escape') return;
    if (!document.getElementById('admin-panel').classList.contains('hidden')) {
        closeAdmin();
    }
});
