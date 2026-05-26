'use strict';

let currentMode = null;
let kits = [];
let editingId = null;

function esc(str) {
    if (str == null) return '';
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function itemLabel(name) {
    return name.replace(/^weapon_/,'').replace(/_/g,' ').replace(/\b\w/g, c => c.toUpperCase());
}

function nuiFetch(cb, data) {
    fetch('https://viper_kit/' + cb, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    });
}

// ── NUI Messages ───────────────────────────────────────────────────────────────
window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.type === 'openAdmin')  openAdmin(d.kits);
    if (d.type === 'openPlayer') openPlayer(d.kits);
});

document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeUI(); });

// ── Close ──────────────────────────────────────────────────────────────────────
function closeUI() {
    document.getElementById('root').classList.add('hidden');
    document.getElementById('admin-panel').classList.add('hidden');
    document.getElementById('player-panel').classList.add('hidden');
    nuiFetch('close');
}
document.getElementById('close-admin').addEventListener('click', closeUI);
document.getElementById('close-player').addEventListener('click', closeUI);

// ══ PANEL ADMIN ════════════════════════════════════════════════════════════════

function openAdmin(kitsList) {
    const alreadyOpen = currentMode === 'admin';
    kits = kitsList || [];
    currentMode = 'admin';
    document.getElementById('root').classList.remove('hidden');
    document.getElementById('admin-panel').classList.remove('hidden');
    document.getElementById('player-panel').classList.add('hidden');
    renderAdminList();
    if (!alreadyOpen) showEmpty();
    else if (editingId && !kits.find(k => k.id === editingId)) showEmpty();
}

function renderAdminList() {
    const list = document.getElementById('admin-kits-list');
    document.getElementById('kit-count').textContent = kits.length;

    if (!kits.length) {
        list.innerHTML = '<div style="padding:14px 12px;color:var(--text-dim);font-size:12px;text-align:center;letter-spacing:1px">Aucun kit</div>';
        return;
    }
    list.innerHTML = kits.map(k => `
        <div class="kit-row" data-id="${k.id}" onclick="selectKit(${k.id})">
            <span class="kit-row-name">${esc(k.name)}</span>
            <span class="kit-row-badges">
                ${k.permission        ? `<span class="kit-row-perm">${esc(k.permission.replace('group.',''))}</span>` : ''}
                ${k.one_time          ? `<span class="kit-row-once">1×</span>` : ''}
                ${k.cooldown_minutes  ? `<span class="kit-row-cd">${k.cooldown_minutes}min</span>` : ''}
            </span>
            <button class="kit-del-btn" onclick="event.stopPropagation();deleteKit(${k.id})" title="Supprimer">✕</button>
        </div>
    `).join('');
    if (editingId) highlightRow(editingId);
}

function highlightRow(id) {
    document.querySelectorAll('.kit-row').forEach(r => r.classList.toggle('active', parseInt(r.dataset.id) === id));
}

function showEmpty() {
    editingId = null;
    document.getElementById('editor-empty').classList.remove('hidden');
    document.getElementById('editor-form').classList.add('hidden');
    document.querySelectorAll('.kit-row').forEach(r => r.classList.remove('active'));
}

function selectKit(id) {
    const kit = kits.find(k => k.id === id);
    if (!kit) return;
    editingId = id;
    document.getElementById('form-title').textContent = 'MODIFIER LE KIT';
    document.getElementById('edit-id').value = id;
    document.getElementById('field-name').value = kit.name || '';
    document.getElementById('field-perm').value = kit.permission || '';
    document.getElementById('field-cooldown').value = kit.cooldown_minutes || 0;
    setToggle(!!kit.one_time);

    const container = document.getElementById('items-container');
    container.innerHTML = '';
    (kit.items || []).forEach(item => addItemRow(item.item, item.amount));

    document.getElementById('editor-empty').classList.add('hidden');
    document.getElementById('editor-form').classList.remove('hidden');
    highlightRow(id);
}

// Toggle one-shot
function setToggle(val) {
    const cb = document.getElementById('field-onetime');
    cb.checked = val;
    document.getElementById('onetime-hint').textContent = val ? 'Oui' : 'Non';
    document.getElementById('onetime-hint').style.color = val ? 'var(--orange)' : 'var(--text-dim)';
}
document.getElementById('field-onetime').addEventListener('change', function() {
    setToggle(this.checked);
});

// Nouveau kit
document.getElementById('btn-new-kit').addEventListener('click', () => {
    editingId = null;
    document.getElementById('form-title').textContent = 'NOUVEAU KIT';
    document.getElementById('edit-id').value = '';
    document.getElementById('field-name').value = '';
    document.getElementById('field-perm').value = '';
    document.getElementById('field-cooldown').value = 0;
    setToggle(false);
    document.getElementById('items-container').innerHTML = '';
    addItemRow();
    document.getElementById('editor-empty').classList.add('hidden');
    document.getElementById('editor-form').classList.remove('hidden');
    document.querySelectorAll('.kit-row').forEach(r => r.classList.remove('active'));
    document.getElementById('field-name').focus();
});

document.getElementById('btn-add-item').addEventListener('click', () => addItemRow());

function addItemRow(itemName = '', amount = 1) {
    const container = document.getElementById('items-container');
    const row = document.createElement('div');
    row.className = 'item-row';
    row.innerHTML = `
        <input type="text" class="item-name" placeholder="weapon_pistol50 · money · ammo_pistol · bread …" value="${esc(itemName)}" />
        <input type="text" class="amount-input" placeholder="Qté" value="${amount}" />
        <button class="item-row-del" onclick="this.closest('.item-row').remove()" title="Retirer">✕</button>
    `;
    container.appendChild(row);
    row.querySelector('.item-name').focus();
}

// Sauvegarder
document.getElementById('btn-save').addEventListener('click', () => {
    const name = document.getElementById('field-name').value.trim();
    const perm = document.getElementById('field-perm').value.trim();
    const oneTime = document.getElementById('field-onetime').checked;
    if (!name) { document.getElementById('field-name').focus(); return; }

    const cooldown = parseInt(document.getElementById('field-cooldown').value) || 0;

    const items = [];
    document.querySelectorAll('#items-container .item-row').forEach(row => {
        const item   = row.querySelector('.item-name').value.trim();
        const amount = parseInt(row.querySelector('.amount-input').value) || 1;
        if (item) items.push({ item, amount });
    });

    const data = { name, permission: perm, one_time: oneTime, cooldown_minutes: cooldown, items };
    if (editingId) { data.id = editingId; nuiFetch('adminEdit', data); }
    else            { nuiFetch('adminCreate', data); }
});

document.getElementById('btn-cancel').addEventListener('click', showEmpty);

document.getElementById('btn-spawn-npc').addEventListener('click', () => {
    const btn = document.getElementById('btn-spawn-npc');
    nuiFetch('spawnNpcHere');
    btn.textContent = '✔ SPAWNÉ';
    btn.classList.add('spawned');
    setTimeout(() => { btn.textContent = '📍 SPAWN ICI'; btn.classList.remove('spawned'); }, 2500);
});

function deleteKit(id) {
    nuiFetch('adminDelete', { id });
    if (editingId === id) showEmpty();
}

// ══ PANEL JOUEUR ═══════════════════════════════════════════════════════════════

function openPlayer(kitsList) {
    kits = kitsList || [];
    currentMode = 'player';
    document.getElementById('root').classList.remove('hidden');
    document.getElementById('player-panel').classList.remove('hidden');
    document.getElementById('admin-panel').classList.add('hidden');

    const grid = document.getElementById('player-kits-grid');
    grid.innerHTML = kits.map(k => {
        const used = k.already_used;
        const itemsHtml = (k.items && k.items.length)
            ? k.items.map(i => `<div class="kit-item-line">${esc(itemLabel(i.item))} <span style="color:var(--green);opacity:.7">x${i.amount}</span></div>`).join('')
            : '<div style="color:var(--text-dim);font-size:11px;letter-spacing:1px">Aucun item</div>';

        const onCooldown = !used && (k.cooldown_remaining > 0);
        const disabled   = used || onCooldown;

        const badges = [
            k.permission       ? `<span class="kit-card-perm">${esc(k.permission.replace('group.','').toUpperCase())}</span>` : '',
            k.one_time         ? `<span class="kit-card-once">${used ? 'UTILISÉ' : 'ONE SHOT'}</span>` : '',
            k.cooldown_minutes ? `<span class="kit-card-cd">${onCooldown ? k.cooldown_remaining + ' min' : k.cooldown_minutes + 'min CD'}</span>` : '',
        ].filter(Boolean).join('');

        let btnLabel = 'RÉCUPÉRER';
        if (used)            btnLabel = 'DÉJÀ UTILISÉ';
        else if (onCooldown) btnLabel = k.cooldown_remaining + ' MIN';

        return `
            <div class="kit-card${disabled ? ' kit-used' : ''}">
                <div class="kit-card-header">
                    <span class="kit-card-name">${esc(k.name)}</span>
                    <span class="kit-card-badges">${badges}</span>
                </div>
                <div class="kit-card-items">${itemsHtml}</div>
                <button class="kit-card-claim" onclick="claimKit(${k.id})" ${disabled ? 'disabled' : ''}>
                    ${btnLabel}
                </button>
            </div>
        `;
    }).join('');
}

function claimKit(id) {
    nuiFetch('claim', { id });
    closeUI();
}
