'use strict';

const RESOURCE_NAME = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'viperpvp_redzone';

let zones          = [];
let selectedZoneId = null;
let isCreating     = false;

let safezones          = [];
let selectedSafezoneId = null;
let isCreatingSafezone = false;

let adminLbPlayers  = [];
let adminLbSelected = new Set();

let ambientMuted = true; // sons PNJ coupes par defaut

let deathEWaitInt = null;

// ════════════════════════════════════════
//  MESSAGES NUI ENTRANTS (depuis le client Lua)
// ════════════════════════════════════════

window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || !d.type) return;

    switch (d.type) {
        case 'updateHUD':   updateHUD(d);           break;
        case 'toggleAdmin': toggleAdmin(d.visible);  break;
        case 'adminData':
            zones = d.zones || [];
            renderZoneList();
            if (selectedZoneId) {
                const z = zones.find(z => z.id === selectedZoneId);
                if (z) selectZone(z.id);
            }
            break;
        case 'leaderboardData':
            renderLeaderboard(d.players || [], d.isAdmin, d.myStats || null);
            break;
        case 'toggleLeaderboard':
            toggleLeaderboard(d.visible);
            break;
        case 'voteStart':   voteStart(d.options, d.duration); break;
        case 'voteEnd':     voteEnd(d.winnerId, d.winnerName); break;
        case 'voteUpdate':  voteUpdateCounts(d.counts); break;
        case 'voteSelect':  voteSetSelected(d.index); break;
        case 'voteVoted':   voteMarkVoted(d.index); break;
        case 'voteHide':    document.getElementById('vote-panel').classList.add('hidden'); break;
        case 'safezoneData':
            safezones = d.safezones || [];
            renderSafezoneList();
            if (selectedSafezoneId) {
                const sz = safezones.find(z => z.id === selectedSafezoneId);
                if (sz) selectSafezone(sz.id);
            }
            break;
        case 'adminLbData':
            adminLbPlayers = d.players || [];
            renderAdminLeaderboard();
            break;
        case 'deathScreen':     showDeathScreen(d.totalSecs, d.reviveSecs); break;
        case 'deathHide':       hideDeathScreen();                           break;
        case 'deathEAvailable': showDeathEHint();                            break;
        case 'deathTimerUpdate': updateDeathTimer(d.remaining);              break;
        case 'lootStart':    showLootBar(d.duration);   break;
        case 'lootCancel':   hideLootBar();             break;
        case 'lootDone':     hideLootBar();             break;
        case 'reviveStart':  showReviveBar(d.duration); break;
        case 'reviveCancel': hideReviveBar();            break;
        case 'reviveDone':   hideReviveBar();            break;
        case 'tpNpcData':        renderTpNpcList(d.npcs || []);          break;
        case 'tpAdminSafezones': renderTpAdminSafezones(d.safezones || []); break;
        case 'showTpSelect':     showTpSelect(d.safezones || []);           break;
    }
});

// ════════════════════════════════════════
//  HUD
// ════════════════════════════════════════

function updateHUD(data) {
    const hud = document.getElementById('hud');
    if (!data.visible) { hud.classList.add('hidden'); return; }

    hud.classList.remove('hidden');
    document.getElementById('hud-name').textContent     = data.name;
    document.getElementById('hud-kills').textContent    = `${data.kills} / ${data.threshold} kills`;
    document.getElementById('hud-my-kills').textContent = data.myKills ?? 0;

    const myKills  = data.myKills  ?? 0;
    const myDeaths = data.myDeaths ?? 0;
    document.getElementById('hud-my-kd').textContent = calcKd(myKills, myDeaths);

    const pct = data.threshold > 0
        ? Math.min((data.kills / data.threshold) * 100, 100)
        : 0;
    document.getElementById('hud-bar').style.width = pct + '%';

    // Leader
    const leaderBlock = document.getElementById('hud-leader-block');
    const leaderSep   = document.getElementById('hud-leader-sep');
    if (data.leaderName) {
        document.getElementById('hud-leader-name').textContent  = data.leaderName;
        document.getElementById('hud-leader-score').textContent = data.leaderKills ?? 0;
        leaderBlock.classList.remove('hidden');
        leaderSep.classList.remove('hidden');
    } else {
        leaderBlock.classList.add('hidden');
        leaderSep.classList.add('hidden');
    }
}

// ════════════════════════════════════════
//  PANEL ADMIN
// ════════════════════════════════════════

function toggleAdmin(visible) {
    document.getElementById('admin-panel').classList.toggle('hidden', !visible);
    document.getElementById('overlay').classList.toggle('hidden', !visible);
    if (!visible) {
        selectedZoneId     = null;
        isCreating         = false;
        selectedSafezoneId = null;
        isCreatingSafezone = false;
        adminLbSelected.clear();
        document.getElementById('zone-editor').classList.add('hidden');
        document.getElementById('editor-empty').classList.remove('hidden');
        document.getElementById('sz-editor').classList.add('hidden');
        document.getElementById('sz-editor-empty').classList.remove('hidden');
        switchAdminTab('redzones');
    }
}

function switchAdminTab(tab) {
    ['redzones', 'safezones', 'tpnpc', 'lb', 'monde'].forEach(t => {
        document.getElementById('panel-tab-' + t).classList.toggle('hidden', tab !== t);
        document.getElementById('tab-btn-' + t).classList.toggle('panel-nav-active', tab === t);
    });
    if (tab === 'lb')    nuiFetch('getAdminLeaderboard', {});
    if (tab === 'tpnpc') nuiFetch('getTpNpcList', {});
}

function toggleMuteAmbient() {
    ambientMuted = !ambientMuted;
    const btn = document.getElementById('btn-mute-ambient');
    if (ambientMuted) {
        btn.textContent = '🔇 COUPÉS';
        btn.style.borderColor = '#39FF14';
        btn.style.color = '#39FF14';
    } else {
        btn.textContent = '🔊 ACTIFS';
        btn.style.borderColor = '#ff4444';
        btn.style.color = '#ff4444';
    }
    nuiFetch('toggleAmbientSounds', { muted: ambientMuted });
}

function closePanel() {
    nuiFetch('closeAdmin', {});
}

function forceVote() {
    showConfirm('Forcer un vote maintenant parmi 3 zones aléatoires ?', () => {
        nuiFetch('forceVote', {});
    });
}

// ─── Liste des zones ───

function renderZoneList() {
    const list = document.getElementById('zone-list');
    list.innerHTML = '';

    if (zones.length === 0) {
        list.innerHTML = '<p style="color:#444;font-size:12px;text-align:center;padding:12px 0;">Aucune zone créée</p>';
        return;
    }

    zones.forEach(z => {
        const div = document.createElement('div');
        div.className = 'zone-item'
            + (z.active    ? ' active-zone' : '')
            + (z.id === selectedZoneId ? ' selected' : '');

        div.innerHTML = `
            <div class="zone-item-name">${esc(z.name)}</div>
            <div class="zone-item-state ${z.active ? 'state-on' : 'state-off'}">
                ${z.active ? '&#9679; ACTIVE' : '&#9675; Inactive'}
            </div>
            ${z.active
                ? `<div class="zone-item-progress">${z.killCount} / ${z.killThreshold} kills</div>`
                : ''}
        `;
        div.addEventListener('click', () => selectZone(z.id));
        list.appendChild(div);
    });
}

// ─── Sélectionner / éditer une zone ───

function selectZone(id) {
    const z = zones.find(z => z.id === id);
    if (!z) return;

    selectedZoneId = id;
    isCreating     = false;
    renderZoneList();

    document.getElementById('editor-empty').classList.add('hidden');
    document.getElementById('zone-editor').classList.remove('hidden');
    document.getElementById('editor-title').textContent = 'Modifier la zone';

    document.getElementById('edit-id').value        = z.id;
    document.getElementById('edit-name').value      = z.name;
    document.getElementById('edit-x').value         = z.x;
    document.getElementById('edit-y').value         = z.y;
    document.getElementById('edit-z').value         = z.z;
    document.getElementById('edit-radius').value     = z.radius;
    document.getElementById('edit-threshold').value  = z.killThreshold;
    document.getElementById('edit-reward').value     = z.moneyReward;
    document.getElementById('edit-win-reward').value = z.winReward ?? 15000;

    // Masquer "Activer" si déjà active
    document.getElementById('btn-activate').classList.toggle('hidden', z.active);
    document.getElementById('btn-delete').classList.remove('hidden');
}

// ─── Créer une nouvelle zone ───

function newZone() {
    selectedZoneId = null;
    isCreating     = true;
    renderZoneList();

    document.getElementById('editor-empty').classList.add('hidden');
    document.getElementById('zone-editor').classList.remove('hidden');
    document.getElementById('editor-title').textContent = 'Nouvelle zone';

    document.getElementById('edit-id').value        = '';
    document.getElementById('edit-name').value      = '';
    document.getElementById('edit-x').value         = '';
    document.getElementById('edit-y').value         = '';
    document.getElementById('edit-z').value         = '';
    document.getElementById('edit-radius').value     = 150;
    document.getElementById('edit-threshold').value  = 20;
    document.getElementById('edit-reward').value     = 300;
    document.getElementById('edit-win-reward').value = 15000;

    document.getElementById('btn-activate').classList.add('hidden');
    document.getElementById('btn-delete').classList.add('hidden');
}

// ─── Récupérer la position actuelle ───

function getCoords() {
    nuiFetch('getCoords', {}).then(data => {
        if (!data) return;
        document.getElementById('edit-x').value = data.x;
        document.getElementById('edit-y').value = data.y;
        document.getElementById('edit-z').value = data.z;
    });
}

// ─── Enregistrer (créer ou modifier) ───

function saveZone() {
    const name      = document.getElementById('edit-name').value.trim();
    const x         = parseFloat(document.getElementById('edit-x').value);
    const y         = parseFloat(document.getElementById('edit-y').value);
    const z         = parseFloat(document.getElementById('edit-z').value);
    const radius    = parseFloat(document.getElementById('edit-radius').value);
    const threshold = parseInt(document.getElementById('edit-threshold').value);
    const reward    = parseInt(document.getElementById('edit-reward').value);
    const winReward = parseInt(document.getElementById('edit-win-reward').value);

    if (!name || isNaN(x) || isNaN(y) || isNaN(z) || isNaN(radius)) {
        alert('Veuillez remplir tous les champs obligatoires (nom, coordonnées, rayon).');
        return;
    }
    if (threshold < 1) { alert('Le seuil de kills doit être d\'au moins 1.'); return; }

    const data = { name, x, y, z, radius, killThreshold: threshold, moneyReward: reward, winReward };

    if (isCreating) {
        nuiFetch('createZone', data);
    } else {
        data.id = parseInt(document.getElementById('edit-id').value);
        nuiFetch('updateZone', data);
    }
}

// ─── Forcer l'activation d'une zone ───

function activateZone() {
    if (!selectedZoneId) return;
    nuiFetch('activateZone', { id: selectedZoneId });
}

// ─── Supprimer une zone ───

function deleteZone() {
    if (!selectedZoneId) return;
    const z = zones.find(z => z.id === selectedZoneId);
    if (!z) return;

    showConfirm(`Supprimer définitivement la zone "${z.name}" ?`, () => {
        nuiFetch('deleteZone', { id: selectedZoneId });
        selectedZoneId = null;
        isCreating     = false;
        document.getElementById('zone-editor').classList.add('hidden');
        document.getElementById('editor-empty').classList.remove('hidden');
    });
}

// ════════════════════════════════════════
//  UTILITAIRES
// ════════════════════════════════════════

function nuiFetch(callback, data) {
    return fetch(`https://${RESOURCE_NAME}/${callback}`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(data),
    }).then(r => r.json()).catch(() => null);
}

function esc(str) {
    const d = document.createElement('div');
    d.appendChild(document.createTextNode(str));
    return d.innerHTML;
}

function calcKd(kills, deaths) {
    if (kills === 0 && deaths === 0) return '—';
    return (kills / Math.max(1, deaths)).toFixed(2);
}

function showConfirm(message, onConfirm) {
    document.getElementById('confirm-text').textContent = message;
    document.getElementById('confirm-modal').classList.remove('hidden');

    const modal  = document.getElementById('confirm-modal');
    const yesBtn = document.getElementById('confirm-yes');
    const noBtn  = document.getElementById('confirm-no');

    const cleanup = () => {
        modal.classList.add('hidden');
        yesBtn.removeEventListener('click', handleYes);
        noBtn.removeEventListener('click', handleNo);
    };

    const handleYes = () => { cleanup(); onConfirm(); };
    const handleNo  = () => { cleanup(); };

    yesBtn.addEventListener('click', handleYes);
    noBtn.addEventListener('click', handleNo);
}

// ════════════════════════════════════════
//  VOTE
// ════════════════════════════════════════

let voteOptionsList = [];
let voteTimerInt    = null;

function voteStart(options, duration) {
    voteOptionsList = options;

    const container = document.getElementById('vote-options');
    container.innerHTML = '';
    options.forEach((opt, i) => {
        const card = document.createElement('div');
        card.className = 'vote-card' + (i === 0 ? ' vote-selected' : '');
        card.id = 'vote-card-' + i;
        card.innerHTML = `
            <div class="vote-card-name">${esc(opt.name)}</div>
            <div class="vote-card-votes" id="vote-votes-${opt.id}">0 vote</div>
            <div class="vote-card-bar-bg"><div class="vote-card-bar" id="vote-bar-${opt.id}"></div></div>`;
        container.appendChild(card);
    });

    document.getElementById('vote-result').classList.add('hidden');
    document.getElementById('vote-hint').textContent = '← → pour naviguer  •  ENTRÉE pour voter';
    document.getElementById('vote-panel').classList.remove('hidden');

    let remaining = duration;
    const timerEl = document.getElementById('vote-timer');
    timerEl.textContent = remaining;
    clearInterval(voteTimerInt);
    voteTimerInt = setInterval(() => {
        remaining--;
        if (timerEl) timerEl.textContent = remaining;
        if (remaining <= 0) clearInterval(voteTimerInt);
    }, 1000);
}

function voteSetSelected(index) {
    document.querySelectorAll('.vote-card').forEach((card, i) => {
        card.classList.toggle('vote-selected', i === index);
    });
}

function voteMarkVoted(index) {
    document.querySelectorAll('.vote-card').forEach((card, i) => {
        if (i === index) card.classList.add('vote-voted');
    });
    const hint = document.getElementById('vote-hint');
    if (hint) hint.textContent = '✓ Vote enregistré !';
}

function voteUpdateCounts(counts) {
    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    voteOptionsList.forEach(opt => {
        const count = counts[opt.id] || 0;
        const pct   = total > 0 ? (count / total * 100) : 0;
        const el  = document.getElementById('vote-votes-' + opt.id);
        const bar = document.getElementById('vote-bar-'   + opt.id);
        if (el)  el.textContent = count + ' vote' + (count !== 1 ? 's' : '');
        if (bar) bar.style.width = pct + '%';
    });
}

function voteEnd(winnerId, winnerName) {
    clearInterval(voteTimerInt);
    document.querySelectorAll('.vote-card').forEach((card, i) => {
        const opt = voteOptionsList[i];
        if (!opt) return;
        card.classList.toggle('vote-winner', opt.id === winnerId);
        card.classList.toggle('vote-loser',  opt.id !== winnerId);
    });
    const result = document.getElementById('vote-result');
    result.innerHTML = '&#127942; Prochaine zone : <strong>' + esc(winnerName) + '</strong>';
    result.classList.remove('hidden');
}

// ════════════════════════════════════════
//  LEADERBOARD
// ════════════════════════════════════════

function toggleLeaderboard(visible) {
    document.getElementById('lb-panel').classList.toggle('hidden', !visible);
    document.getElementById('lb-overlay').classList.toggle('hidden', !visible);
    if (!visible) switchLbTab('classement');
}

function switchLbTab(tab) {
    document.getElementById('lb-tab-classement').classList.toggle('hidden', tab !== 'classement');
    document.getElementById('lb-tab-mystats').classList.toggle('hidden',    tab !== 'mystats');
    document.getElementById('lb-tab-btn-classement').classList.toggle('lb-tab-active', tab === 'classement');
    document.getElementById('lb-tab-btn-mystats').classList.toggle('lb-tab-active',    tab === 'mystats');
}

function closeLeaderboard() {
    nuiFetch('closeLeaderboard', {});
}

function resetLeaderboard() {
    showConfirm('Réinitialiser le classement mensuel ? Cette action est irréversible.', () => {
        nuiFetch('resetLeaderboard', {});
    });
}

function renderMyStats(myStats) {
    const el = document.getElementById('my-stats-content');
    if (!myStats) {
        el.innerHTML = '<div class="no-stats">Aucune statistique disponible.<br>Jouez dans une RedZone pour apparaître ici.</div>';
        return;
    }
    const kd = calcKd(myStats.kills_total, myStats.deaths_total);

    el.innerHTML = `
        <div class="my-stats-rank">
            <div class="my-stats-rank-num">#${myStats.rank}</div>
            <div class="my-stats-rank-label">Rang mensuel</div>
        </div>
        <div class="my-stats-grid">
            <div class="stat-card">
                <div class="stat-val">${myStats.kills_total}</div>
                <div class="stat-key">Kills total</div>
            </div>
            <div class="stat-card">
                <div class="stat-val">${myStats.deaths_total}</div>
                <div class="stat-key">Morts</div>
            </div>
            <div class="stat-card">
                <div class="stat-val stat-val-kd">${kd}</div>
                <div class="stat-key">K/D Ratio</div>
            </div>
        </div>`;
}

// ════════════════════════════════════════
//  ADMIN LEADERBOARD
// ════════════════════════════════════════

function renderAdminLeaderboard() {
    const tbody = document.getElementById('lb-admin-tbody');
    if (!tbody) return;
    adminLbSelected.clear();
    updateLbAdminDeleteBtn();

    const selectAll = document.getElementById('lb-admin-select-all');
    if (selectAll) { selectAll.checked = false; selectAll.indeterminate = false; }

    if (adminLbPlayers.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;color:#444;padding:24px;">Aucune statistique disponible</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    adminLbPlayers.forEach((p, i) => {
        const rank = i + 1;
        const kd   = calcKd(p.kills_total, p.deaths_total);
        const cls  = rank === 1 ? 'row-gold' : rank === 2 ? 'row-silver' : rank === 3 ? 'row-bronze' : '';
        const tr   = document.createElement('tr');
        tr.className = cls;
        tr.dataset.cid = p.citizenid;
        tr.innerHTML = `
            <td class="col-check">
                <input type="checkbox" class="lb-admin-check" data-cid="${esc(p.citizenid)}"
                    onchange="lbAdminToggle('${esc(p.citizenid)}', this)">
            </td>
            <td class="col-rank">${rank}</td>
            <td class="col-name">${esc(p.player_name)}</td>
            <td class="col-stat">${p.kills_total}</td>
            <td class="col-stat">${p.deaths_total}</td>
            <td class="col-stat">${kd}</td>`;
        tbody.appendChild(tr);
    });
}

function lbAdminToggle(cid, checkbox) {
    if (checkbox.checked) adminLbSelected.add(cid);
    else adminLbSelected.delete(cid);

    // Mettre à jour la surbrillance de la ligne
    const tr = checkbox.closest('tr');
    if (tr) tr.classList.toggle('lb-row-selected', checkbox.checked);

    // Mettre à jour "Tout sélectionner"
    const selectAll = document.getElementById('lb-admin-select-all');
    if (selectAll) {
        selectAll.checked       = adminLbSelected.size === adminLbPlayers.length && adminLbPlayers.length > 0;
        selectAll.indeterminate = adminLbSelected.size > 0 && adminLbSelected.size < adminLbPlayers.length;
    }
    updateLbAdminDeleteBtn();
}

function lbAdminSelectAll(checked) {
    adminLbSelected.clear();
    document.querySelectorAll('.lb-admin-check').forEach(cb => {
        cb.checked = checked;
        const tr = cb.closest('tr');
        if (tr) tr.classList.toggle('lb-row-selected', checked);
        if (checked) adminLbSelected.add(cb.dataset.cid);
    });
    const selectAll = document.getElementById('lb-admin-select-all');
    if (selectAll) selectAll.indeterminate = false;
    updateLbAdminDeleteBtn();
}

function updateLbAdminDeleteBtn() {
    const btn = document.getElementById('lb-admin-delete-btn');
    if (!btn) return;
    btn.disabled = adminLbSelected.size === 0;
    btn.textContent = adminLbSelected.size > 0
        ? `\u{1F5D1} Supprimer (${adminLbSelected.size} joueur${adminLbSelected.size > 1 ? 's' : ''})`
        : '\u{1F5D1} Supprimer la sélection';
}

function lbAdminDeleteSelected() {
    if (adminLbSelected.size === 0) return;
    const names = adminLbPlayers
        .filter(p => adminLbSelected.has(p.citizenid))
        .map(p => p.player_name)
        .join(', ');
    showConfirm(`Supprimer définitivement ${adminLbSelected.size} joueur(s) du leaderboard ?\n${names}`, () => {
        nuiFetch('deleteLeaderboardPlayers', { citizenids: [...adminLbSelected] });
    });
}

// ════════════════════════════════════════
//  SAFEZONES
// ════════════════════════════════════════

function renderSafezoneList() {
    const list = document.getElementById('sz-list');
    list.innerHTML = '';

    if (safezones.length === 0) {
        list.innerHTML = '<p style="color:#444;font-size:12px;text-align:center;padding:12px 0;">Aucune safezone créée</p>';
        return;
    }

    safezones.forEach(z => {
        const div = document.createElement('div');
        div.className = 'zone-item'
            + (z.active ? ' sz-active-zone' : '')
            + (z.id === selectedSafezoneId ? ' selected' : '');

        div.innerHTML = `
            <div class="zone-item-name">${esc(z.name)}</div>
            <div class="zone-item-state ${z.active ? 'state-on' : 'state-off'}">
                ${z.active ? '&#9679; Tir bloqué' : '&#9675; Désactivée'}
            </div>
            <div class="zone-item-progress">Rayon : ${z.radius}m</div>
        `;
        div.addEventListener('click', () => selectSafezone(z.id));
        list.appendChild(div);
    });
}

function selectSafezone(id) {
    const z = safezones.find(z => z.id === id);
    if (!z) return;

    selectedSafezoneId = id;
    isCreatingSafezone = false;
    renderSafezoneList();

    document.getElementById('sz-editor-empty').classList.add('hidden');
    document.getElementById('sz-editor').classList.remove('hidden');
    document.getElementById('sz-editor-title').textContent = 'Modifier la safezone';

    document.getElementById('sz-edit-id').value     = z.id;
    document.getElementById('sz-edit-name').value   = z.name;
    document.getElementById('sz-edit-x').value      = z.x;
    document.getElementById('sz-edit-y').value      = z.y;
    document.getElementById('sz-edit-z').value      = z.z;
    document.getElementById('sz-edit-radius').value = z.radius;

    const toggleBtn = document.getElementById('sz-btn-toggle');
    toggleBtn.classList.remove('hidden');
    if (z.active) {
        toggleBtn.textContent = '&#9679; Désactiver';
        toggleBtn.classList.remove('sz-disabled');
    } else {
        toggleBtn.textContent = '&#9675; Activer';
        toggleBtn.classList.add('sz-disabled');
    }
    document.getElementById('sz-btn-delete').classList.remove('hidden');
}

function newSafezone() {
    selectedSafezoneId = null;
    isCreatingSafezone = true;
    renderSafezoneList();

    document.getElementById('sz-editor-empty').classList.add('hidden');
    document.getElementById('sz-editor').classList.remove('hidden');
    document.getElementById('sz-editor-title').textContent = 'Nouvelle safezone';

    document.getElementById('sz-edit-id').value     = '';
    document.getElementById('sz-edit-name').value   = '';
    document.getElementById('sz-edit-x').value      = '';
    document.getElementById('sz-edit-y').value      = '';
    document.getElementById('sz-edit-z').value      = '';
    document.getElementById('sz-edit-radius').value = 100;

    document.getElementById('sz-btn-toggle').classList.add('hidden');
    document.getElementById('sz-btn-delete').classList.add('hidden');
}

function getSafezoneCoords() {
    nuiFetch('getSafezoneCoords', {}).then(data => {
        if (!data) return;
        document.getElementById('sz-edit-x').value = data.x;
        document.getElementById('sz-edit-y').value = data.y;
        document.getElementById('sz-edit-z').value = data.z;
    });
}

function saveSafezone() {
    const name   = document.getElementById('sz-edit-name').value.trim();
    const x      = parseFloat(document.getElementById('sz-edit-x').value);
    const y      = parseFloat(document.getElementById('sz-edit-y').value);
    const z      = parseFloat(document.getElementById('sz-edit-z').value);
    const radius = parseFloat(document.getElementById('sz-edit-radius').value);

    if (!name || isNaN(x) || isNaN(y) || isNaN(z) || isNaN(radius)) {
        alert('Veuillez remplir tous les champs obligatoires (nom, coordonnées, rayon).');
        return;
    }

    const data = { name, x, y, z, radius };

    if (isCreatingSafezone) {
        nuiFetch('createSafezone', data);
    } else {
        data.id = parseInt(document.getElementById('sz-edit-id').value);
        nuiFetch('updateSafezone', data);
    }
}

function toggleSafezone() {
    if (!selectedSafezoneId) return;
    nuiFetch('toggleSafezone', { id: selectedSafezoneId });
}

function deleteSafezone() {
    if (!selectedSafezoneId) return;
    const z = safezones.find(z => z.id === selectedSafezoneId);
    if (!z) return;

    showConfirm(`Supprimer définitivement la safezone "${z.name}" ?`, () => {
        nuiFetch('deleteSafezone', { id: selectedSafezoneId });
        selectedSafezoneId = null;
        isCreatingSafezone = false;
        document.getElementById('sz-editor').classList.add('hidden');
        document.getElementById('sz-editor-empty').classList.remove('hidden');
    });
}

// ════════════════════════════════════════
//  BARRES DE PROGRESSION (LOOT / REVIVE)
// ════════════════════════════════════════

let lootAnimHandle   = null;
let reviveAnimHandle = null;

function showLootBar(durationSecs) {
    if (lootAnimHandle) { cancelAnimationFrame(lootAnimHandle); lootAnimHandle = null; }
    const box  = document.getElementById('loot-bar');
    const fill = document.getElementById('loot-bar-fill');
    const pct  = document.getElementById('loot-bar-pct');
    if (!box || !fill || !pct) return;
    box.classList.remove('hidden');
    fill.style.width = '0%';
    pct.textContent  = '0%';
    const start = performance.now();
    const dur   = durationSecs * 1000;
    function tick(now) {
        const progress = Math.min(100, ((now - start) / dur) * 100);
        fill.style.width = progress + '%';
        pct.textContent  = Math.floor(progress) + '%';
        if (progress < 100) lootAnimHandle = requestAnimationFrame(tick);
        else lootAnimHandle = null;
    }
    lootAnimHandle = requestAnimationFrame(tick);
}

function hideLootBar() {
    if (lootAnimHandle) { cancelAnimationFrame(lootAnimHandle); lootAnimHandle = null; }
    const box  = document.getElementById('loot-bar');
    const fill = document.getElementById('loot-bar-fill');
    const pct  = document.getElementById('loot-bar-pct');
    if (box)  box.classList.add('hidden');
    if (fill) fill.style.width = '0%';
    if (pct)  pct.textContent  = '0%';
}

function showReviveBar(durationSecs) {
    if (reviveAnimHandle) { cancelAnimationFrame(reviveAnimHandle); reviveAnimHandle = null; }
    const box  = document.getElementById('revive-bar');
    const fill = document.getElementById('revive-bar-fill');
    const pct  = document.getElementById('revive-bar-pct');
    if (!box || !fill || !pct) return;
    box.classList.remove('hidden');
    fill.style.width = '0%';
    pct.textContent  = '0%';
    const start = performance.now();
    const dur   = durationSecs * 1000;
    function tick(now) {
        const progress = Math.min(100, ((now - start) / dur) * 100);
        fill.style.width = progress + '%';
        pct.textContent  = Math.floor(progress) + '%';
        if (progress < 100) reviveAnimHandle = requestAnimationFrame(tick);
        else reviveAnimHandle = null;
    }
    reviveAnimHandle = requestAnimationFrame(tick);
}

function hideReviveBar() {
    if (reviveAnimHandle) { cancelAnimationFrame(reviveAnimHandle); reviveAnimHandle = null; }
    const box  = document.getElementById('revive-bar');
    const fill = document.getElementById('revive-bar-fill');
    const pct  = document.getElementById('revive-bar-pct');
    if (box)  box.classList.add('hidden');
    if (fill) fill.style.width = '0%';
    if (pct)  pct.textContent  = '0%';
}

// ════════════════════════════════════════
//  ÉCRAN DE MORT / COMA
// ════════════════════════════════════════

function showDeathScreen(totalSecs, reviveSecs) {
    document.getElementById('death-screen').classList.remove('hidden');
    document.getElementById('death-e-hint').classList.add('hidden');
    document.getElementById('death-e-wait').classList.remove('hidden');

    updateDeathTimer(totalSecs);

    let eWait = reviveSecs;
    const el = document.getElementById('death-e-countdown');
    if (el) el.textContent = eWait;

    clearInterval(deathEWaitInt);
    deathEWaitInt = setInterval(() => {
        eWait--;
        if (el) el.textContent = Math.max(0, eWait);
        if (eWait <= 0) {
            clearInterval(deathEWaitInt);
            showDeathEHint();
        }
    }, 1000);
}

function hideDeathScreen() {
    document.getElementById('death-screen').classList.add('hidden');
    clearInterval(deathEWaitInt);
}

function showDeathEHint() {
    document.getElementById('death-e-hint').classList.remove('hidden');
    document.getElementById('death-e-wait').classList.add('hidden');
}

function updateDeathTimer(remaining) {
    const el = document.getElementById('death-timer-val');
    if (!el) return;
    const mins = Math.floor(remaining / 60);
    const secs = remaining % 60;
    el.textContent = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

// ════════════════════════════════════════
//  NPC TP
// ════════════════════════════════════════

let tpAdminSafezonesCache = [];

function renderTpNpcList(npcs) {
    const list = document.getElementById('tpnpc-list');
    if (!list) return;
    list.innerHTML = '';

    if (npcs.length === 0) {
        list.innerHTML = '<p style="color:#444;font-size:12px;text-align:center;padding:20px 0;">Aucun NPC TP créé</p>';
        return;
    }

    npcs.forEach(n => {
        const div = document.createElement('div');
        div.className = 'tpnpc-item';
        div.innerHTML = `
            <div class="tpnpc-item-info">
                <span class="tpnpc-item-id">${n.name ? esc(n.name) : 'NPC #' + n.id}</span>
                <span class="tpnpc-item-coords">X: ${n.x.toFixed(1)}  Y: ${n.y.toFixed(1)}  Z: ${n.z.toFixed(1)}</span>
            </div>
            <div style="display:flex;gap:4px;">
                <button class="btn tpnpc-tp-btn" onclick="adminTpToNpc(${n.x},${n.y},${n.z},'${esc(n.name||'NPC #'+n.id)}')">&#10148; TP</button>
                <button class="btn btn-delete tpnpc-del-btn" onclick="deleteTpNpc(${n.id})">&#128465;</button>
            </div>
        `;
        list.appendChild(div);
    });
}

function spawnTpNpc() {
    const input = document.getElementById('tpnpc-name-input');
    const name = input ? input.value.trim() : '';
    if (!name) { if (input) input.focus(); return; }
    nuiFetch('spawnTpNpc', { name });
    if (input) input.value = '';
}

function deleteTpNpc(id) {
    showConfirm('Supprimer ce NPC TP ?', () => {
        nuiFetch('deleteTpNpc', { id });
    });
}

function renderTpAdminSafezones(safezones) {
    safezones.sort((a, b) => {
        if (a.name === 'Zone Principale') return -1;
        if (b.name === 'Zone Principale') return 1;
        return a.name.localeCompare(b.name);
    });
    tpAdminSafezonesCache = safezones;
    const list = document.getElementById('tpnpc-sz-list');
    if (!list) return;
    list.innerHTML = '';

    if (safezones.length === 0) {
        list.innerHTML = '<p style="color:#444;font-size:12px;text-align:center;padding:20px 0;">Aucune safezone configurée</p>';
        return;
    }
    safezones.forEach(sz => {
        const div = document.createElement('div');
        div.className = 'tpnpc-sz-item';
        div.innerHTML = `
            <span class="tpnpc-sz-name">&#128205; ${esc(sz.name)}</span>
            <button class="btn tpnpc-tp-btn" onclick="adminTpTo(${sz.id})">&#10148; TP</button>
        `;
        list.appendChild(div);
    });
}

function adminTpToNpc(x, y, z, name) {
    nuiFetch('adminTpToSafezone', { x, y, z, name });
}

function adminTpTo(id) {
    const sz = tpAdminSafezonesCache.find(z => z.id === id);
    if (!sz) return;
    nuiFetch('adminTpToSafezone', { id: sz.id, name: sz.name, x: sz.x, y: sz.y, z: sz.z });
}

function showTpSelect(safezones) {
    safezones.sort((a, b) => {
        if (a.name === 'Zone Principale') return -1;
        if (b.name === 'Zone Principale') return 1;
        return a.name.localeCompare(b.name);
    });

    const list = document.getElementById('tp-select-list');
    list.innerHTML = '';

    if (safezones.length === 0) {
        list.innerHTML = '<p style="color:#888;text-align:center;padding:24px;">Aucune safezone disponible.</p>';
    } else {
        safezones.forEach(sz => {
            const btn = document.createElement('button');
            btn.className = 'tp-sz-btn';
            btn.innerHTML = `&#128205; ${esc(sz.name)}`;
            btn.addEventListener('click', () => {
                document.getElementById('tp-select-overlay').classList.add('hidden');
                document.getElementById('tp-select-panel').classList.add('hidden');
                nuiFetch('tpToSafezone', { id: sz.id, name: sz.name, x: sz.x, y: sz.y, z: sz.z });
            });
            list.appendChild(btn);
        });
    }

    document.getElementById('tp-select-overlay').classList.remove('hidden');
    document.getElementById('tp-select-panel').classList.remove('hidden');
}

function closeTpSelect() {
    document.getElementById('tp-select-overlay').classList.add('hidden');
    document.getElementById('tp-select-panel').classList.add('hidden');
    nuiFetch('tpSelectClose', {});
}

function renderLeaderboard(players, isAdmin, myStats) {
    toggleLeaderboard(true);
    renderMyStats(myStats);

    // ─── Podium ───
    const podium = document.getElementById('lb-podium');
    podium.innerHTML = '';

    const slots = [
        { rank: 2, idx: 1, cls: 'silver', medal: '&#129352;' },
        { rank: 1, idx: 0, cls: 'gold',   medal: '&#129351;' },
        { rank: 3, idx: 2, cls: 'bronze',  medal: '&#129353;' },
    ];

    slots.forEach(slot => {
        const p = players[slot.idx];
        if (p) {
            const kd = calcKd(p.kills_total, p.deaths_total);
            podium.innerHTML += `
                <div class="podium-block podium-${slot.cls}">
                    <div class="podium-medal">${slot.medal}</div>
                    <div class="podium-rank">#${slot.rank}</div>
                    <div class="podium-name">${esc(p.player_name)}</div>
                    <div class="podium-kills">${p.kills_month} kills</div>
                    <div class="podium-kd">K/D ${kd}</div>
                    <div class="podium-base"></div>
                </div>`;
        } else {
            podium.innerHTML += `
                <div class="podium-block podium-${slot.cls} podium-empty">
                    <div class="podium-medal">—</div>
                    <div class="podium-rank">#${slot.rank}</div>
                    <div class="podium-name">—</div>
                    <div class="podium-kills">0 kills</div>
                    <div class="podium-kd">K/D 0.00</div>
                    <div class="podium-base"></div>
                </div>`;
        }
    });

    // ─── Table ───
    const tbody = document.getElementById('lb-tbody');
    tbody.innerHTML = '';

    if (players.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#444;padding:24px;">Aucune statistique disponible</td></tr>';
        return;
    }

    players.forEach((p, i) => {
        const rank = i + 1;
        const kd = calcKd(p.kills_total, p.deaths_total);
        const cls  = rank === 1 ? 'row-gold' : rank === 2 ? 'row-silver' : rank === 3 ? 'row-bronze' : '';
        tbody.innerHTML += `
            <tr class="${cls}">
                <td class="col-rank">${rank}</td>
                <td class="col-name">${esc(p.player_name)}</td>
                <td class="col-stat">${p.kills_total}</td>
                <td class="col-stat">${p.deaths_total}</td>
                <td class="col-stat">${kd}</td>
            </tr>`;
    });
}
