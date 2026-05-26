/* ============================================================
   VIPER PVP — NUI Logic
   ============================================================ */

'use strict';

// ── Noms d'affichage (FR) ─────────────────────────────────────
const WEAPON_NAMES = {
    weapon_pistol:              'Pistolet',
    weapon_pistol_mk2:          'Pistolet MK2',
    weapon_combatpistol:        'Pistolet de Combat',
    weapon_appistol:            'Pistolet AP',
    weapon_heavypistol:         'Pistolet Lourd',
    weapon_vintagepistol:       'Pistolet Vintage',
    weapon_navyrevolver:        'Revolver de la Marine',
    weapon_revolver:            'Revolver',
    weapon_revolver_mk2:        'Revolver MK2',
    weapon_doubleaction:        'Double Action',
    weapon_ceramicpistol:       'Pistolet Céramique',
    weapon_gadgetpistol:        'Pistolet Gadget',
    weapon_pistol50:            'Pistolet .50',
    weapon_microsmg:            'Micro SMG',
    weapon_minismg:             'Mini SMG',
    weapon_smg:                 'SMG',
    weapon_smg_mk2:             'SMG MK2',
    weapon_assaultsmg:          'Assault SMG',
    weapon_combatpdw:           'Combat PDW',
    weapon_machinepistol:       'Pistolet Mitrailleur',
    weapon_assaultrifle:        'Fusil d\'Assaut',
    weapon_assaultrifle_mk2:    'Fusil d\'Assaut MK2',
    weapon_carbinerifle:        'Carabine',
    weapon_carbinerifle_mk2:    'Carabine MK2',
    weapon_specialcarbine:      'Carabine Spéciale',
    weapon_specialcarbine_mk2:  'Carabine Spéciale MK2',
    weapon_bullpuprifle:        'Bullpup Rifle',
    weapon_bullpuprifle_mk2:    'Bullpup Rifle MK2',
    weapon_compactrifle:        'Fusil Compact',
    weapon_militaryrifle:       'Fusil Militaire',
    weapon_heavyrifle:          'Fusil Lourd',
    weapon_sniperrifle:         'Fusil Sniper',
    weapon_heavysniper:         'Sniper Lourd',
    weapon_heavysniper_mk2:     'Sniper Lourd MK2',
    weapon_marksmanrifle:       'Fusil de Précision',
    weapon_marksmanrifle_mk2:   'Fusil de Précision MK2',
    weapon_pumpshotgun:         'Fusil à Pompe',
    weapon_pumpshotgun_mk2:     'Fusil à Pompe MK2',
    weapon_sawnoffshotgun:      'Fusil Scié',
    weapon_bullpupshotgun:      'Bullpup Shotgun',
    weapon_heavyshotgun:        'Shotgun Lourd',
    weapon_dbshotgun:           'Shotgun Double Canon',
    weapon_autoshotgun:         'Shotgun Automatique',
    weapon_mg:                  'Mitrailleuse',
    weapon_combatmg:            'Mitrailleuse de Combat',
    weapon_combatmg_mk2:        'Mitrailleuse de Combat MK2',
    weapon_gusenberg:           'Gusenberg Sweeper',
    // Armes personnalisées (ggcweapons)
    weapon_glock17:             'Glock-17',
    weapon_glock18c:            'Glock-18 Custom',
    weapon_glock22:             'Glock-22',
    weapon_deagle:              'Desert Eagle',
    weapon_fnx45:               'FN FNX45',
    weapon_m1911:               'M1911',
    weapon_glock20:             'Glock-20',
    weapon_glock19gen4:         'Glock-19 Gen 4',
    weapon_browning:            'BROWNING',
    weapon_pmxfm:               'Beretta PMX',
    weapon_mac10:               'MAC-10',
    weapon_mk47fm:              'Mk47 Mutant',
    weapon_m6ic:                'LWRC M6IC',
    weapon_scarsc:              'Scar SC',
    weapon_m4:                  'M4A1 Carbine',
    weapon_ak47:                'AK-47',
    weapon_ak74:                'AK-74',
    weapon_aks74:               'AKS-74',
    weapon_groza:               'OTs-14 Groza',
};

// ── Images des composants accessoires ────────────────────────
const COMP_IMAGES = {
    'COMPONENT_AT_PI_SUPP':           'at_suppressor.png',
    'COMPONENT_AT_PI_SUPP_02':        'at_suppressor.png',
    'COMPONENT_AT_AR_SUPP':           'at_suppressor.png',
    'COMPONENT_AT_AR_SUPP_02':        'at_suppressor.png',
    'COMPONENT_AT_SR_SUPP':           'at_suppressor.png',
    'COMPONENT_AT_SR_SUPP_03':        'at_suppressor.png',
    'COMPONENT_AT_MUZZLE_1':          'at_muzzle_heavy.png',
    'COMPONENT_AT_MUZZLE_2':          'at_muzzle_flat.png',
    'COMPONENT_AT_MUZZLE_3':          'at_muzzle_bell.png',
    'COMPONENT_AT_MUZZLE_4':          'at_muzzle_fat.png',
    'COMPONENT_AT_MUZZLE_5':          'at_muzzle_slanted.png',
    'COMPONENT_AT_MUZZLE_6':          'at_muzzle_squared.png',
    'COMPONENT_AT_MUZZLE_7':          'at_muzzle_split.png',
    'COMPONENT_AT_SCOPE_MACRO':       'at_scope_holo.png',
    'COMPONENT_AT_SCOPE_MACRO_02':    'at_scope_holo.png',
    'COMPONENT_AT_SCOPE_SMALL':       'at_scope_small.png',
    'COMPONENT_AT_SCOPE_SMALL_02':    'at_scope_small.png',
    'COMPONENT_AT_SCOPE_MEDIUM':      'at_scope_medium.png',
    'COMPONENT_AT_SCOPE_MEDIUM_MK2':  'at_scope_medium.png',
    'COMPONENT_AT_SCOPE_LARGE':       'at_scope_large.png',
    'COMPONENT_AT_SCOPE_LARGE_MK2':   'at_scope_large.png',
    'COMPONENT_AT_SCOPE_MAX':         'at_scope_advanced.png',
    'COMPONENT_AT_RAILCOVER_01':      'at_barrel.png',
    'COMPONENT_AT_AR_FLSH':           'at_flashlight.png',
    'COMPONENT_AT_PI_FLSH':           'at_flashlight.png',
    'COMPONENT_AT_PI_FLSH_02':        'at_flashlight.png',
    'COMPONENT_AT_AR_AFGRIP':         'at_grip.png',
    'COMPONENT_AT_AR_AFGRIP_02':      'at_grip.png',
    'COMPONENT_PISTOL_MK2_BARREL_01': 'at_barrel.png',
    'COMPONENT_PISTOL_MK2_BARREL_02': 'at_barrel.png',
};

function getCompImage(compName) {
    if (COMP_IMAGES[compName]) return 'images/' + COMP_IMAGES[compName];
    if (compName.includes('_CLIP_03')) return 'images/at_clip_drum.png';
    if (compName.includes('_CLIP_02')) return 'images/at_clip_extended2.png';
    if (compName.includes('_CLIP_'))   return 'images/at_clip_extended.png';
    return null;
}

function displayName(name) {
    return WEAPON_NAMES[name] || name.replace('weapon_', '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

// ── Appel NUI ─────────────────────────────────────────────────
function nuiFetch(endpoint, data = {}) {
    return fetch(`https://vipergun/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).catch(() => {});
}

// ── Toast ─────────────────────────────────────────────────────
let toastTimer = null;
function showToast(msg, type = 'success') {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.className = `toast ${type}`;
    t.classList.remove('hidden');
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.add('hidden'), 2800);
}

/* ============================================================
   ADMIN PANEL
   ============================================================ */

let adminCoffres = [];
let coffreSearchTerm = '';

// ── Tabs ──────────────────────────────────────────────────────
const TAB_TITLES = {
    coffres: 'Gestion des Coffres',
    ped:     'PNJ Coffres',
};

function switchTab(name) {
    document.querySelectorAll('.nav-item').forEach(b => b.classList.toggle('active', b.dataset.tab === name));
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.getElementById(`tab-${name}`).classList.add('active');
    document.getElementById('tabTitle').textContent = TAB_TITLES[name] || name;
}

document.querySelectorAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
});

// ── Fermeture ─────────────────────────────────────────────────
document.getElementById('closeAdmin').addEventListener('click', () => {
    document.getElementById('admin-panel').classList.add('hidden');
    nuiFetch('closeAdmin');
});

document.getElementById('adminOverlay').addEventListener('click', () => {
    document.getElementById('admin-panel').classList.add('hidden');
    nuiFetch('closeAdmin');
});

// ── Rendu tableau coffres ─────────────────────────────────────
function renderCoffres() {
    const tbody  = document.getElementById('coffresList');
    const search = coffreSearchTerm.toLowerCase();
    const filtered = adminCoffres.filter(r => {
        if (!search) return true;
        const name = (r.player_name || '').toLowerCase();
        return r.citizenid.toLowerCase().includes(search) || name.includes(search);
    });

    document.getElementById('coffreCount').textContent = `${filtered.length} joueur(s)`;

    if (!filtered.length) {
        tbody.innerHTML = '<tr><td colspan="3" style="text-align:center;color:var(--text-muted);padding:30px">Aucun joueur trouvé</td></tr>';
        return;
    }

    tbody.innerHTML = filtered.map(row => {
        const displayLabel = row.player_name
            ? `<div style="font-weight:600;color:var(--text)">${row.player_name}</div><div style="font-family:monospace;font-size:10px;color:var(--text-muted)">${row.citizenid}</div>`
            : `<div style="font-family:monospace;font-size:12px">${row.citizenid}</div>`;
        return `
        <tr data-cid="${row.citizenid}">
            <td>${displayLabel}</td>
            <td class="center">
                <input class="coffre-count-input" type="number"
                    min="4" max="8" value="${row.coffre_count}" data-cid="${row.citizenid}">
                <span style="color:var(--text-muted);font-size:11px">/ 8</span>
            </td>
            <td class="center">
                <button class="btn-primary btn-sm btn-icon" onclick="saveCoffre('${row.citizenid}')">
                    <i class="fas fa-floppy-disk"></i> Sauvegarder
                </button>
            </td>
        </tr>`;
    }).join('');
}

window.saveCoffre = function(citizenid) {
    const input = document.querySelector(`input[data-cid="${citizenid}"]`);
    const count = parseInt(input.value);
    if (isNaN(count) || count < 4 || count > 8) {
        showToast('Valeur invalide (4–8)', 'error');
        return;
    }
    nuiFetch('admin:updatePlayerCoffres', { citizenid, count });

    const entry = adminCoffres.find(r => r.citizenid === citizenid);
    if (entry) entry.coffre_count = count;

    const label = entry?.player_name || citizenid;
    showToast(`Coffres de ${label} mis à jour (${count})`);
};

document.getElementById('coffreSearch').addEventListener('input', e => {
    coffreSearchTerm = e.target.value;
    renderCoffres();
});

// ── Onglet PNJ ────────────────────────────────────────────────
let pendingPedCoords = null;

document.getElementById('useMyPosition').addEventListener('click', async () => {
    const result = await nuiFetch('admin:useMyPosition');
    if (!result) return;
    const pos = await result.json().catch(() => null);
    if (!pos) return;
    pendingPedCoords = pos;
    showToast(`Position récupérée (${pos.x.toFixed(1)}, ${pos.y.toFixed(1)}, ${pos.z.toFixed(1)})`);
});

document.getElementById('addPed').addEventListener('click', () => {
    if (!pendingPedCoords) {
        showToast('Cliquez d\'abord sur "Ma position"', 'error');
        return;
    }
    const model = document.getElementById('pedModel').value.trim() || 's_m_y_dealer_01';
    nuiFetch('admin:addPed', {
        model,
        x:       pendingPedCoords.x,
        y:       pendingPedCoords.y,
        z:       pendingPedCoords.z,
        heading: pendingPedCoords.heading,
    });
    pendingPedCoords = null;
    showToast('PNJ ajouté !');
});

function renderPeds(peds) {
    const tbody = document.getElementById('pedsList');
    if (!peds || !peds.length) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;color:var(--text-muted);padding:30px">Aucun PNJ configuré — utilisez "Ajouter ici"</td></tr>';
        return;
    }
    tbody.innerHTML = peds.map(p => `
        <tr>
            <td style="color:var(--text-muted);font-size:12px">#${p.id}</td>
            <td style="font-family:monospace;font-size:12px">${p.model}</td>
            <td style="font-size:11px;color:var(--text-muted)">
                ${Number(p.x).toFixed(1)} / ${Number(p.y).toFixed(1)} / ${Number(p.z).toFixed(1)}
                &nbsp;<span style="color:var(--text-muted)">hdg ${Number(p.heading).toFixed(0)}°</span>
            </td>
            <td class="center" style="display:flex;gap:6px;justify-content:center">
                <button class="btn-secondary btn-sm btn-icon" onclick="tpToPed(${p.x},${p.y},${p.z},${p.heading})" title="Se téléporter">
                    <i class="fas fa-location-crosshairs"></i>
                </button>
                <button class="btn-danger btn-sm btn-icon" onclick="removePed(${p.id})" title="Supprimer">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

window.removePed = function(id) {
    nuiFetch('admin:removePed', { id });
    showToast('PNJ supprimé.');
};

window.tpToPed = function(x, y, z, heading) {
    nuiFetch('admin:tpToPed', { x, y, z, heading });
    showToast('Téléportation…');
};

// ── Ouverture du panel ────────────────────────────────────────
function openAdminPanel(data) {
    adminCoffres = data.coffres || [];

    renderCoffres();
    renderPeds(data.peds || []);

    switchTab('coffres');
    document.getElementById('admin-panel').classList.remove('hidden');
}

/* ============================================================
   MENU ACCESSOIRES (F6)
   ============================================================ */

let currentWeaponName = null;

function renderAttachments(weaponName, attachments) {
    currentWeaponName = weaponName;

    document.getElementById('attWeaponName').textContent =
        WEAPON_NAMES[weaponName] || displayName(weaponName);

    const groups = {};
    const ORDER  = ['Bouche', 'Optique', 'Sous-canon', 'Canon', 'Chargeur'];

    for (const att of attachments) {
        if (!groups[att.category]) groups[att.category] = [];
        groups[att.category].push(att);
    }

    let html = '';
    const cats = ORDER.filter(c => groups[c]).concat(
        Object.keys(groups).filter(c => !ORDER.includes(c))
    );

    for (let ci = 0; ci < cats.length; ci++) {
        const cat   = cats[ci];
        const items = groups[cat];

        html += `<div class="att-category">${cat}</div>`;
        for (const att of items) {
            const eq = att.equipped ? 'equipped' : '';
            html += `
            <div class="att-item ${eq}" data-comp="${att.name}" data-equipped="${att.equipped}">
                <div class="att-icon"><i class="fas ${att.icon || 'fa-wrench'}"></i></div>
                <div class="att-label">${att.label}</div>
                <div class="att-status"></div>
            </div>`;
        }

        if (ci < cats.length - 1) html += '<div class="att-separator"></div>';
    }

    document.getElementById('attBody').innerHTML = html || '<p style="padding:14px;color:var(--text-muted)">Aucun accessoire</p>';

    document.querySelectorAll('.att-item').forEach(item => {
        item.addEventListener('click', () => toggleAttachment(item));
    });
}

function toggleAttachment(item) {
    if (item.dataset.busy === 'true') return;
    item.dataset.busy = 'true';

    const compName = item.dataset.comp;
    const equipped = item.dataset.equipped === 'true';

    item.dataset.equipped = String(!equipped);
    item.classList.toggle('equipped', !equipped);

    nuiFetch('toggleAttachment', {
        weaponName:    currentWeaponName,
        componentName: compName,
        equipped:      equipped,
    }).then(r => r && r.json()).then(data => {
        if (!data) {
            item.dataset.equipped = String(equipped);
            item.classList.toggle('equipped', equipped);
            return;
        }
        item.dataset.equipped = String(data.equipped);
        item.classList.toggle('equipped', data.equipped);
    }).catch(() => {
        item.dataset.equipped = String(equipped);
        item.classList.toggle('equipped', equipped);
    }).finally(() => {
        item.dataset.busy = 'false';
    });
}

// ── Navigation clavier du menu accessoires ────────────────────
let attFocusIndex = 0;

function getAttItems() {
    return Array.from(document.querySelectorAll('#attBody .att-item'));
}

function setAttFocus(idx) {
    attFocusIndex = idx;
    const items = getAttItems();
    items.forEach((el, i) => el.classList.toggle('focused', i === attFocusIndex));
    if (items[attFocusIndex]) {
        items[attFocusIndex].scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
}

function openAttachmentMenu(data) {
    renderAttachments(data.weaponName, data.attachments);
    attFocusIndex = 0;
    document.getElementById('attachment-menu').classList.remove('hidden');
    requestAnimationFrame(() => setAttFocus(0));
}

function closeAttachmentMenu() {
    document.getElementById('attachment-menu').classList.add('hidden');
    currentWeaponName = null;
}

document.getElementById('closeAttachments').addEventListener('click', () => {
    closeAttachmentMenu();
    nuiFetch('closeAttachments');
});

document.addEventListener('keydown', e => {
    const attMenu    = document.getElementById('attachment-menu');
    const adminPanel = document.getElementById('admin-panel');

    if (!attMenu.classList.contains('hidden')) {
        if (['ArrowDown', 'ArrowUp', 'Enter', 'Escape', 'F6'].includes(e.key)) {
            e.preventDefault();
            e.stopPropagation();
        }
        const items = getAttItems();
        if (e.key === 'ArrowDown') {
            setAttFocus(attFocusIndex < items.length - 1 ? attFocusIndex + 1 : 0);
        } else if (e.key === 'ArrowUp') {
            setAttFocus(attFocusIndex > 0 ? attFocusIndex - 1 : items.length - 1);
        } else if (e.key === 'Enter') {
            if (items[attFocusIndex]) toggleAttachment(items[attFocusIndex]);
        } else if (e.key === 'Escape' || e.key === 'F6') {
            closeAttachmentMenu();
            nuiFetch('closeAttachments');
        }
        return;
    }

    if (e.key === 'Escape' && !adminPanel.classList.contains('hidden')) {
        adminPanel.classList.add('hidden');
        nuiFetch('closeAdmin');
    }
});

/* ============================================================
   ROUTING DES MESSAGES FIVEM
   ============================================================ */
window.addEventListener('message', event => {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'openAdmin':
            openAdminPanel(data);
            break;
        case 'openAttachments':
            openAttachmentMenu(data);
            break;
        case 'closeAttachments':
            closeAttachmentMenu();
            break;
        case 'updatePeds':
            renderPeds(data.peds || []);
            break;
    }
});
