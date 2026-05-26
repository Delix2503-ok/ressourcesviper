'use strict';

const panel = document.getElementById('panel');

window.copyText = function(text) {
    navigator.clipboard.writeText(text).then(() => {
        const toast = document.getElementById('toast');
        if (toast) { toast.textContent = 'Copié !'; toast.classList.add('show'); setTimeout(() => toast.classList.remove('show'), 1500); }
    });
};

function licenseCell(name, license) {
    if (!name && !license) return `<span class="no-killer">— (inconnu)</span>`;
    const btn = license ? `<button class="copy-btn" onclick="copyText('${esc(license)}')" title="Copier la licence">⎘</button>` : '';
    return `<span class="col-name">${esc(name || '?')}</span>
            <span class="col-license">${esc(license || '')}${btn}</span>`;
}

function nuiFetch(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

// Tab switching
document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById('tab-' + btn.dataset.tab).classList.add('active');
    });
});

document.getElementById('closeBtn').addEventListener('click', closePanel);

function closePanel() {
    panel.classList.add('hidden');
    nuiFetch('close');
}

function fmtDate(str) {
    if (!str) return '—';
    const d = new Date(str);
    if (isNaN(d)) return str;
    const dd  = String(d.getDate()).padStart(2, '0');
    const mm  = String(d.getMonth() + 1).padStart(2, '0');
    const yy  = String(d.getFullYear()).slice(-2);
    const hh  = String(d.getHours()).padStart(2, '0');
    const min = String(d.getMinutes()).padStart(2, '0');
    return `${dd}/${mm}/${yy} à ${hh}h${min}`;
}

function esc(str) {
    if (str == null) return '';
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function setEmpty(tbodyId, cols, msg) {
    document.getElementById(tbodyId).innerHTML =
        `<tr class="empty-row"><td colspan="${cols}">${msg}</td></tr>`;
}

// ── Kills ──────────────────────────────────────────────────────────────────
window.searchKills = function() {
    const license = document.getElementById('kills-license').value.trim();
    if (!license) return;
    nuiFetch('searchKills', { license });
    setEmpty('kills-body', 3, 'Chargement...');
};

function renderKills(rows) {
    const tbody = document.getElementById('kills-body');
    const arr = Array.isArray(rows) ? rows : [];
    if (arr.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="3">Aucun résultat sur les 7 derniers jours</td></tr>';
        return;
    }
    tbody.innerHTML = arr.map(r => `<tr>
        <td class="col-date">${fmtDate(r.created_at)}</td>
        <td>${licenseCell(r.victim_name, r.victim_license)}</td>
        <td>${licenseCell(r.killer_name, r.killer_license)}</td>
    </tr>`).join('');
}

// ── Loot ───────────────────────────────────────────────────────────────────
window.searchLoot = function() {
    const license = document.getElementById('loot-license').value.trim();
    if (!license) return;
    nuiFetch('searchLoot', { license });
    setEmpty('loot-body', 5, 'Chargement...');
};

function renderLoot(rows) {
    const tbody = document.getElementById('loot-body');
    const arr = Array.isArray(rows) ? rows : [];
    if (arr.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="5">Aucun résultat sur les 7 derniers jours</td></tr>';
        return;
    }
    tbody.innerHTML = arr.map(r => {
        let prisPar;
        if (r.from_type === 'player' && r.from_player_name) {
            prisPar = `<span class="looter-name">${esc(r.from_player_name)}</span>`;
        } else if (r.from_type === 'drop') {
            prisPar = '<span class="col-source">Ramassé (sol)</span>';
        } else if (r.from_type === 'stash') {
            prisPar = '<span class="col-source">Coffre</span>';
        } else {
            prisPar = `<span class="col-source">${esc(r.from_type || '—')}</span>`;
        }
        return `<tr>
            <td class="col-date">${fmtDate(r.created_at)}</td>
            <td>${licenseCell(r.player_name, r.player_license)}</td>
            <td class="col-item">${esc(r.item_label || r.item_name)}<span class="col-license">${esc(r.item_name)}</span></td>
            <td class="col-qty">${esc(r.quantity)}</td>
            <td>${prisPar}</td>
        </tr>`;
    }).join('');
}

// ── Messages NUI ───────────────────────────────────────────────────────────
window.addEventListener('message', e => {
    const msg = e.data;
    switch (msg.type) {
        case 'open':
            panel.classList.remove('hidden');
            setEmpty('kills-body', 3, 'Entrez une licence et cliquez Rechercher');
            setEmpty('loot-body',  5, 'Entrez une licence et cliquez Rechercher');
            break;
        case 'close':
            panel.classList.add('hidden');
            break;
        case 'receiveKills':
            renderKills(msg.data);
            break;
        case 'receiveLoot':
            renderLoot(msg.data);
            break;
    }
});

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closePanel();
});
