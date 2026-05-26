'use strict';

// ═══════════════════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════════════════
let allItems    = [];
let allNpcs     = [];
let allCNpcs    = [];
let allLogs     = [];
let allCoins    = [];
let categories  = [];
let activeCat   = null;
let mode        = null;   // 'player' | 'admin'
let adminTab    = 'items'; // 'items' | 'garage' | 'custom' | 'logs' | 'coins'
let tebexUrl    = '';
let ownedIds    = new Set(); // IDs des articles déjà achetés (achat unique)

// Delete confirmation state (double-clic)
const delPending     = {};
const delNpcPending  = {};
const delCNpcPending = {};

// ═══════════════════════════════════════════════════════════════════════════
// NUI
// ═══════════════════════════════════════════════════════════════════════════
const RESOURCE = (() => {
    try { return window.GetParentResourceName(); } catch { return 'viper-boutique'; }
})();

function nuiFetch(endpoint, data) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════
function esc(s) {
    return String(s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function fmt(n) {
    return Number(n).toLocaleString('fr-FR');
}

// Multi-source image fallback (ox_inventory → ggcweapons → vipergun)
function imgFallback(img) {
    try {
        const list = JSON.parse(img.dataset.fallbacks || '[]');
        if (list.length > 0) {
            img.dataset.fallbacks = JSON.stringify(list.slice(1));
            img.src = list[0];
        } else {
            img.closest('.card-img-wrap').classList.add('no-img');
        }
    } catch { img.closest('.card-img-wrap').classList.add('no-img'); }
}
window.imgFallback = imgFallback;

function makeImgTag(item) {
    // Si une image custom est définie, l'utiliser directement
    if (item.image_url && item.image_url !== '') {
        return `<img src="${esc(item.image_url)}" onerror="this.closest('.card-img-wrap').classList.add('no-img')" alt="" />`;
    }
    // Sinon fallback chain depuis ox_inventory / vipergun
    const name = item.item_name || '';
    if (!name) {
        return `<img src="" onerror="this.closest('.card-img-wrap').classList.add('no-img')" alt="" />`;
    }
    const up = name.toUpperCase();
    const lo = name.toLowerCase();
    const fallbacks = JSON.stringify([
        `nui://ox_inventory/web/images/${lo}.png`,
        `nui://ggcweapons/images/${lo}.png`,
        `nui://vipergun/html/images/${up}.png`,
        `nui://vipergun/html/images/${lo}.png`,
    ]);
    return `<img src="nui://ox_inventory/web/images/${up}.png"
         data-fallbacks='${fallbacks}'
         onerror="imgFallback(this)" alt="" />`;
}

function makePriceHtml(price) {
    if (price <= 0) return `<span class="price-free">GRATUIT</span>`;
    return `<span class="price-vc">VC</span><span class="price-val">${fmt(price)}</span>`;
}

// ═══════════════════════════════════════════════════════════════════════════
// Coins
// ═══════════════════════════════════════════════════════════════════════════
function setCoins(n) {
    const el = document.getElementById('player-coins');
    if (el) el.textContent = fmt(n);
}

// ═══════════════════════════════════════════════════════════════════════════
// Categories
// ═══════════════════════════════════════════════════════════════════════════
function renderCategories(containerId) {
    const container = document.getElementById(containerId);
    container.innerHTML = '';
    categories.forEach(cat => {
        const count = allItems.filter(i => i.category === cat.id).length;
        const btn   = document.createElement('button');
        btn.className      = 'cat-btn' + (cat.id === activeCat ? ' active' : '');
        btn.dataset.catId  = cat.id;
        btn.innerHTML = `
            <span class="cat-icon">${cat.icon}</span>
            <span class="cat-label">${cat.label}</span>
            <span class="cat-count">${count}</span>`;
        btn.addEventListener('click', () => switchCategory(cat.id));
        container.appendChild(btn);
    });

    // Bouton GARAGE NPC uniquement dans le panel admin
    if (containerId === 'admin-cats') {
        const sep = document.createElement('div');
        sep.className = 'cat-separator';
        sep.style.marginTop = 'auto';
        container.appendChild(sep);

        const gBtn = document.createElement('button');
        gBtn.className = 'cat-btn' + (adminTab === 'garage' ? ' active' : '');
        gBtn.id = 'tab-garage-npc';
        gBtn.innerHTML = `<span class="cat-icon">🔧</span><span class="cat-label">GARAGE NPC</span>`;
        gBtn.addEventListener('click', showGaragePanel);
        container.appendChild(gBtn);

        const cBtn = document.createElement('button');
        cBtn.className = 'cat-btn' + (adminTab === 'custom' ? ' active' : '');
        cBtn.id = 'tab-custom-npc';
        cBtn.innerHTML = `<span class="cat-icon">🔩</span><span class="cat-label">ATELIER NPC</span>`;
        cBtn.addEventListener('click', showCustomNpcPanel);
        container.appendChild(cBtn);

        const logsBtn = document.createElement('button');
        logsBtn.className = 'cat-btn' + (adminTab === 'logs' ? ' active' : '');
        logsBtn.id = 'tab-logs';
        logsBtn.innerHTML = `<span class="cat-icon">📋</span><span class="cat-label">LOGS COINS</span>`;
        logsBtn.addEventListener('click', showLogsPanel);
        container.appendChild(logsBtn);

        const coinsBtn = document.createElement('button');
        coinsBtn.className = 'cat-btn' + (adminTab === 'coins' ? ' active' : '');
        coinsBtn.id = 'tab-coins';
        coinsBtn.innerHTML = `<span class="cat-icon">💰</span><span class="cat-label">SOLDES</span>`;
        coinsBtn.addEventListener('click', showCoinsPanel);
        container.appendChild(coinsBtn);

        const placeBtn = document.getElementById('btn-place-npc');
        if (placeBtn) {
            placeBtn.onclick = () => {
                const nameEl = document.getElementById('npc-name-input');
                const name   = nameEl ? nameEl.value.trim() : '';
                if (!name) { nameEl && nameEl.focus(); return; }
                nuiFetch('placeGarageNpc', { name });
                if (nameEl) nameEl.value = '';
            };
        }

        const placeCBtn = document.getElementById('btn-place-cnpc');
        if (placeCBtn) {
            placeCBtn.onclick = () => {
                const nameEl = document.getElementById('cnpc-name-input');
                const name   = nameEl ? nameEl.value.trim() : '';
                if (!name) { nameEl && nameEl.focus(); return; }
                nuiFetch('placeCustomNpc', { name });
                if (nameEl) nameEl.value = '';
            };
        }
    }
}

function switchCategory(catId) {
    activeCat = catId;
    if (mode === 'player') {
        renderCategories('player-cats');
        renderPlayerItems();
    } else {
        showItemsPanel();
        renderCategories('admin-cats');
        renderAdminItems();
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Player panel
// ═══════════════════════════════════════════════════════════════════════════
function openPlayer(items, coins, cats, url, owned) {
    allItems   = items;
    categories = cats;
    activeCat  = cats[0]?.id ?? null;
    mode       = 'player';
    if (url) tebexUrl = url;
    ownedIds   = new Set((owned || []).map(id => Number(id)));

    setCoins(coins);

    document.getElementById('root').classList.remove('hidden');
    document.getElementById('player-panel').classList.remove('hidden');
    document.getElementById('admin-panel').classList.add('hidden');

    renderCategories('player-cats');
    renderPlayerItems();
}

function renderPlayerItems() {
    const cat   = categories.find(c => c.id === activeCat);
    const grid  = document.getElementById('player-items');
    const title = document.getElementById('player-cat-title');
    const count = document.getElementById('player-cat-count');

    const items = allItems.filter(i => i.category === activeCat);
    title.textContent = cat ? cat.label : '';
    count.textContent = items.length > 0 ? items.length + ' article' + (items.length > 1 ? 's' : '') : '';

    grid.innerHTML = '';

    if (items.length === 0) {
        grid.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">⬡</div>
                <p>AUCUN ARTICLE DISPONIBLE</p>
            </div>`;
        return;
    }

    items.forEach(item => {
        const maxQty = Math.max(1, item.max_qty || 1);
        const hasQty = maxQty > 1;

        const qtyHtml = hasQty ? `
            <div class="qty-wrap">
                <button class="qty-btn" onclick="adjQty(this,-1)">−</button>
                <input type="number" class="qty-input" value="1" min="1" max="${maxQty}"
                       oninput="clampQty(this,${maxQty})" />
                <button class="qty-btn" onclick="adjQty(this,1)">+</button>
            </div>` : '';

        const isOwned = ownedIds.has(Number(item.id));

        const card = document.createElement('div');
        card.className = 'item-card';
        card.innerHTML = `
            <div class="card-img-wrap">${makeImgTag(item)}</div>
            <div class="card-info">
                <div class="card-label">${esc(item.label)}</div>
                ${item.description ? `<div class="card-desc">${esc(item.description)}</div>` : ''}
            </div>
            <div class="card-price">${makePriceHtml(item.price)}</div>
            <div class="card-footer">
                ${isOwned ? '' : qtyHtml}
                ${isOwned
                    ? `<button class="btn-buy btn-owned" disabled>POSSÉDÉ</button>`
                    : `<button class="btn-buy" onclick="buyItem(${item.id},this)">ACHETER</button>`
                }
            </div>`;
        grid.appendChild(card);
    });
}

function adjQty(btn, delta) {
    const input = btn.closest('.qty-wrap').querySelector('.qty-input');
    const max   = parseInt(input.max) || 99;
    input.value = Math.min(max, Math.max(1, (parseInt(input.value) || 1) + delta));
}
window.adjQty = adjQty;

function clampQty(input, max) {
    const v = parseInt(input.value) || 1;
    input.value = Math.min(max, Math.max(1, v));
}
window.clampQty = clampQty;

let pendingBuy = null;

function buyItem(id, btn) {
    const card  = btn.closest('.item-card');
    const qtyEl = card.querySelector('.qty-input');
    const qty   = qtyEl ? parseInt(qtyEl.value) || 1 : 1;
    const item  = allItems.find(i => i.id == id);
    if (!item) return;

    pendingBuy = { id, qty };
    document.getElementById('modal-item-name').textContent  = item.label;
    document.getElementById('modal-item-price').textContent = item.price <= 0 ? 'GRATUIT' : fmt(item.price * qty) + ' VC';
    document.getElementById('buy-modal').classList.remove('hidden');
}
window.buyItem = buyItem;

// ═══════════════════════════════════════════════════════════════════════════
// Admin panel
// ═══════════════════════════════════════════════════════════════════════════
function openAdmin(items, cats, npcs, cnpcs) {
    allItems   = items;
    allNpcs    = npcs  || [];
    allCNpcs   = cnpcs || [];
    categories = cats;
    activeCat  = cats[0]?.id ?? null;
    mode       = 'admin';
    adminTab   = 'items';

    document.getElementById('root').classList.remove('hidden');
    document.getElementById('admin-panel').classList.remove('hidden');
    document.getElementById('player-panel').classList.add('hidden');

    // Remplir le select catégorie dans l'éditeur
    const sel = document.getElementById('edit-category');
    sel.innerHTML = cats.map(c => `<option value="${c.id}">${c.label}</option>`).join('');

    hideEditor();
    showItemsPanel();
    renderCategories('admin-cats');
    renderAdminItems();
}

const ALL_ADMIN_PANELS = ['items-panel','garage-npc-panel','custom-npc-panel','logs-panel','coins-panel'];
const ALL_ADMIN_TABS   = ['tab-garage-npc','tab-custom-npc','tab-logs','tab-coins'];

function hideAllAdminPanels() {
    ALL_ADMIN_PANELS.forEach(id => { const el = document.getElementById(id); if (el) el.classList.add('hidden'); });
    ALL_ADMIN_TABS.forEach(id   => { const el = document.getElementById(id); if (el) el.classList.remove('active'); });
    document.querySelectorAll('#admin-cats .cat-btn[data-cat-id]').forEach(b => b.classList.remove('active'));
}

function showItemsPanel() {
    adminTab = 'items';
    hideAllAdminPanels();
    document.getElementById('items-panel').classList.remove('hidden');
}

function showGaragePanel() {
    adminTab = 'garage';
    hideAllAdminPanels();
    document.getElementById('garage-npc-panel').classList.remove('hidden');
    const t = document.getElementById('tab-garage-npc'); if (t) t.classList.add('active');
    hideEditor();
    renderNpcList();
}

function showCustomNpcPanel() {
    adminTab = 'custom';
    hideAllAdminPanels();
    document.getElementById('custom-npc-panel').classList.remove('hidden');
    const t = document.getElementById('tab-custom-npc'); if (t) t.classList.add('active');
    hideEditor();
    renderCNpcList();
}

function showLogsPanel() {
    adminTab = 'logs';
    hideAllAdminPanels();
    document.getElementById('logs-panel').classList.remove('hidden');
    const t = document.getElementById('tab-logs'); if (t) t.classList.add('active');
    hideEditor();
    nuiFetch('adminGetLogs');
    renderLogs();
}

function showCoinsPanel() {
    adminTab = 'coins';
    hideAllAdminPanels();
    document.getElementById('coins-panel').classList.remove('hidden');
    const t = document.getElementById('tab-coins'); if (t) t.classList.add('active');
    hideEditor();
    nuiFetch('adminGetLogs');
    renderCoinsTable('');
}

function renderLogs() {
    const wrap = document.getElementById('logs-table');
    if (!wrap) return;
    wrap.innerHTML = '';
    const header = document.createElement('div');
    header.className = 'log-row header';
    header.innerHTML = `<span>#</span><span>JOUEUR</span><span>CITIZENID</span><span>MONTANT</span><span>DATE</span>`;
    wrap.appendChild(header);
    if (allLogs.length === 0) {
        wrap.innerHTML += `<div class="empty-state" style="margin-top:20px"><div class="empty-icon">📋</div><p>AUCUN LOG</p></div>`;
        return;
    }
    allLogs.forEach(l => {
        const row = document.createElement('div');
        row.className = 'log-row';
        row.innerHTML = `
            <span class="log-id">${l.id}</span>
            <span class="log-name">${esc(l.player_name)}</span>
            <span class="log-cid">${esc(l.citizenid)}</span>
            <span class="log-amt">+${fmt(l.amount)} VC</span>
            <span class="log-date">${esc(l.given_at)}</span>`;
        wrap.appendChild(row);
    });
}

function renderCoinsTable(search) {
    const wrap = document.getElementById('coins-table');
    if (!wrap) return;
    wrap.innerHTML = '';
    const header = document.createElement('div');
    header.className = 'coins-row header';
    header.innerHTML = `<span>JOUEUR</span><span>CITIZENID</span><span>SOLDE</span>`;
    wrap.appendChild(header);
    const q = search.toLowerCase();
    const filtered = allCoins.filter(c =>
        c.player_name?.toLowerCase().includes(q) || c.citizenid?.toLowerCase().includes(q)
    );
    if (filtered.length === 0) {
        wrap.innerHTML += `<div class="empty-state" style="margin-top:20px"><div class="empty-icon">💰</div><p>AUCUN RÉSULTAT</p></div>`;
        return;
    }
    filtered.forEach(c => {
        const row = document.createElement('div');
        row.className = 'coins-row';
        row.innerHTML = `
            <span class="log-name">${esc(c.player_name)}</span>
            <span class="log-cid">${esc(c.citizenid)}</span>
            <span class="log-amt">${fmt(c.coins)} VC</span>`;
        wrap.appendChild(row);
    });
}

function renderCNpcList() {
    const list = document.getElementById('cnpc-list');
    list.innerHTML = '';
    if (allCNpcs.length === 0) {
        list.innerHTML = `<div class="empty-state"><div class="empty-icon">🔩</div><p>AUCUN NPC — Cliquez PLACER NPC ICI</p></div>`;
        return;
    }
    allCNpcs.forEach(npc => {
        const row = document.createElement('div');
        row.className = 'npc-row';
        row.innerHTML = `
            <div class="npc-id">#${npc.id}</div>
            <div class="npc-info">
                <div class="npc-name">${esc(npc.name || 'Atelier')}</div>
                <div class="npc-coords">${npc.x?.toFixed(1)}, ${npc.y?.toFixed(1)}, ${npc.z?.toFixed(1)}</div>
            </div>
            <div class="npc-actions">
                <button class="btn-npc-del" onclick="deleteCNpc(${npc.id}, this)">✕</button>
            </div>`;
        list.appendChild(row);
    });
}

function deleteCNpc(id, btn) {
    if (delCNpcPending[id]) {
        clearTimeout(delCNpcPending[id]);
        delete delCNpcPending[id];
        nuiFetch('deleteCustomNpc', { id });
        return;
    }
    btn.classList.add('confirm');
    btn.textContent = '!';
    delCNpcPending[id] = setTimeout(() => {
        delete delCNpcPending[id];
        if (btn) { btn.classList.remove('confirm'); btn.textContent = '✕'; }
    }, 2500);
}
window.deleteCNpc = deleteCNpc;

function renderNpcList() {
    const list = document.getElementById('npc-list');
    list.innerHTML = '';
    if (allNpcs.length === 0) {
        list.innerHTML = `<div class="empty-state"><div class="empty-icon">🔧</div><p>AUCUN NPC — Cliquez PLACER NPC ICI</p></div>`;
        return;
    }
    allNpcs.forEach(npc => {
        const hasSpawn = npc.spawn_x != null;
        const row = document.createElement('div');
        row.className = 'npc-row';
        row.innerHTML = `
            <div class="npc-id">#${npc.id}</div>
            <div class="npc-info">
                <div class="npc-name">${esc(npc.name || 'Garage')}</div>
                <div class="npc-coords">
                    ${npc.x?.toFixed(1)}, ${npc.y?.toFixed(1)}, ${npc.z?.toFixed(1)}
                </div>
                <div class="npc-spawn-status ${hasSpawn ? 'npc-spawn-ok' : 'npc-spawn-nok'}">
                    ${hasSpawn
                        ? `✓ Spawn : ${npc.spawn_x?.toFixed(1)}, ${npc.spawn_y?.toFixed(1)}, ${npc.spawn_z?.toFixed(1)}`
                        : '⚠ Aucun point de spawn défini'}
                </div>
            </div>
            <div class="npc-actions">
                <button class="btn-npc-spawn" onclick="setNpcSpawn(${npc.id})">📍 SPAWN ICI</button>
                <button class="btn-npc-del" onclick="deleteNpc(${npc.id}, this)">✕</button>
            </div>`;
        list.appendChild(row);
    });
}

function setNpcSpawn(id) {
    nuiFetch('setGarageNpcSpawn', { id });
}
window.setNpcSpawn = setNpcSpawn;

function deleteNpc(id, btn) {
    if (delNpcPending[id]) {
        clearTimeout(delNpcPending[id]);
        delete delNpcPending[id];
        nuiFetch('deleteGarageNpc', { id });
        return;
    }
    btn.classList.add('confirm');
    btn.textContent = '!';
    delNpcPending[id] = setTimeout(() => {
        delete delNpcPending[id];
        if (btn) { btn.classList.remove('confirm'); btn.textContent = '✕'; }
    }, 2500);
}
window.deleteNpc = deleteNpc;

function renderAdminItems() {
    const cat   = categories.find(c => c.id === activeCat);
    const grid  = document.getElementById('admin-items');
    const title = document.getElementById('admin-cat-title');
    const count = document.getElementById('admin-cat-count');

    const items = allItems.filter(i => i.category === activeCat);
    title.textContent = cat ? cat.label : '';
    count.textContent = items.length > 0 ? items.length + ' article' + (items.length > 1 ? 's' : '') : '';

    grid.innerHTML = '';

    if (items.length === 0) {
        grid.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">⬡</div>
                <p>AUCUN ARTICLE — Cliquez ＋ AJOUTER</p>
            </div>`;
        return;
    }

    items.forEach(item => {
        const card = document.createElement('div');
        card.className = 'item-card';
        card.innerHTML = `
            <div class="admin-card-actions">
                <button class="btn-card-action btn-edit-card"  onclick="editItem(${item.id})"   title="Modifier">✎</button>
                <button class="btn-card-action btn-del-card"   onclick="deleteItem(${item.id},this)" title="Supprimer (2× pour confirmer)" data-del="${item.id}">✕</button>
            </div>
            <div class="card-img-wrap">${makeImgTag(item)}</div>
            <div class="card-info">
                <div class="card-label">${esc(item.label)}</div>
                ${item.description ? `<div class="card-desc">${esc(item.description)}</div>` : ''}
            </div>
            <div class="card-price">${makePriceHtml(item.price)}</div>
            <div class="card-item-name">${esc(item.item_name)}</div>`;
        grid.appendChild(card);
    });
}

// Double-clic pour supprimer (pas de window.confirm — non supporté en NUI)
function deleteItem(id, btn) {
    if (delPending[id]) {
        clearTimeout(delPending[id]);
        delete delPending[id];
        nuiFetch('adminDelete', { id });
        return;
    }
    btn.classList.add('confirm');
    btn.textContent = '!';
    delPending[id] = setTimeout(() => {
        delete delPending[id];
        if (btn) { btn.classList.remove('confirm'); btn.textContent = '✕'; }
    }, 2500);
}
window.deleteItem = deleteItem;

function editItem(id) {
    const item = allItems.find(i => i.id == id);
    if (!item) return;

    document.getElementById('editor-title').textContent       = "MODIFIER L'ARTICLE";
    document.getElementById('edit-id').value                  = id;
    document.getElementById('edit-category').value            = item.category;
    document.getElementById('edit-label').value               = item.label;
    document.getElementById('edit-item-name').value           = item.item_name || '';
    document.getElementById('edit-price').value               = item.price;
    document.getElementById('edit-description').value         = item.description || '';
    document.getElementById('edit-max-qty').value             = item.max_qty || 1;
    document.getElementById('edit-image-url').value           = item.image_url   || '';
    document.getElementById('edit-set-vehicle').value         = item.set_vehicle || '';
    document.getElementById('edit-set-group').value           = item.set_group   || '';
    document.getElementById('edit-unique-buy').checked        = !!item.unique_buy;
    showEditor();
}
window.editItem = editItem;

function showEditor() {
    document.getElementById('admin-editor').classList.remove('hidden');
}

function hideEditor() {
    document.getElementById('admin-editor').classList.add('hidden');
    document.getElementById('edit-id').value          = '';
    document.getElementById('edit-label').value       = '';
    document.getElementById('edit-item-name').value   = '';
    document.getElementById('edit-price').value       = '0';
    document.getElementById('edit-description').value = '';
    document.getElementById('edit-max-qty').value     = '1';
    document.getElementById('edit-image-url').value   = '';
    document.getElementById('edit-set-vehicle').value = '';
    document.getElementById('edit-set-group').value   = '';
    document.getElementById('edit-unique-buy').checked = false;
    document.getElementById('editor-title').textContent = 'NOUVEL ARTICLE';
}

function saveItem() {
    const label       = document.getElementById('edit-label').value.trim();
    const item_name   = document.getElementById('edit-item-name').value.trim();
    const set_group   = document.getElementById('edit-set-group').value.trim();
    const set_vehicle = document.getElementById('edit-set-vehicle').value.trim();
    if (!label) return;

    nuiFetch('adminSave', {
        id:          document.getElementById('edit-id').value || null,
        category:    document.getElementById('edit-category').value,
        label,
        item_name,
        price:       parseInt(document.getElementById('edit-price').value) || 0,
        description: document.getElementById('edit-description').value.trim(),
        max_qty:     parseInt(document.getElementById('edit-max-qty').value) || 1,
        image_url:   document.getElementById('edit-image-url').value.trim(),
        set_vehicle,
        set_group,
        unique_buy:  document.getElementById('edit-unique-buy').checked,
    });
}

function syncItems(items) {
    allItems = items;
    renderCategories('admin-cats');
    renderAdminItems();
    hideEditor();
}

// ═══════════════════════════════════════════════════════════════════════════
// Atelier V.I.P
// ═══════════════════════════════════════════════════════════════════════════
const GTA_COLORS = [
    { i:   0, rgb: '#000000', label: 'Noir' },
    { i: 101, rgb: '#1e1e1e', label: 'Graphite' },
    { i: 104, rgb: '#191919', label: 'Carbone' },
    { i:   1, rgb: '#ffffff', label: 'Blanc pur' },
    { i:   2, rgb: '#f0f0f0', label: 'Blanc brillant' },
    { i:   3, rgb: '#e1e1e1', label: 'Blanc glacier' },
    { i:  93, rgb: '#afafaf', label: 'Argent' },
    { i:  94, rgb: '#8798b0', label: 'Gris acier' },
    { i:  95, rgb: '#949494', label: 'Gris ombre' },
    { i:  98, rgb: '#7a8486', label: 'Gris fonte' },
    { i:  27, rgb: '#ff0000', label: 'Rouge vif' },
    { i:  14, rgb: '#ba1a1a', label: 'Rouge' },
    { i:  11, rgb: '#bb0b0b', label: 'Cramoisi' },
    { i:  12, rgb: '#9a0e0e', label: 'Rouge foncé' },
    { i:  13, rgb: '#ff4d4a', label: 'Rouge délavé' },
    { i:  10, rgb: '#ff0050', label: 'Framboise' },
    { i:   9, rgb: '#ff3ea2', label: 'Rose vif' },
    { i:   8, rgb: '#ff7594', label: 'Rose' },
    { i:  30, rgb: '#ff8200', label: 'Orange vif' },
    { i:  29, rgb: '#c1710b', label: 'Orange' },
    { i:  28, rgb: '#ffa032', label: 'Or orange' },
    { i:  37, rgb: '#fff000', label: 'Jaune vif' },
    { i:  36, rgb: '#ffd800', label: 'Jaune course' },
    { i:  35, rgb: '#f5f014', label: 'Jaune' },
    { i:  62, rgb: '#00ff00', label: 'Vert vif' },
    { i:  61, rgb: '#64f046', label: 'Vert lime' },
    { i:  57, rgb: '#3c8c3c', label: 'Vert mer' },
    { i:  56, rgb: '#005200', label: 'Vert course' },
    { i:  55, rgb: '#145a0a', label: 'Vert foncé' },
    { i:  82, rgb: '#009b9b', label: 'Teal' },
    { i:  81, rgb: '#00cccc', label: 'Turquoise' },
    { i:  79, rgb: '#0082ff', label: 'Bleu vif' },
    { i:  77, rgb: '#239bd7', label: 'Bleu nautique' },
    { i:  76, rgb: '#46c8f0', label: 'Bleu surf' },
    { i:  75, rgb: '#74d2e1', label: 'Bleu diamant' },
    { i:  72, rgb: '#0f69a2', label: 'Bleu' },
    { i:  74, rgb: '#415a91', label: 'Bleu harbor' },
    { i:  83, rgb: '#000f82', label: 'Bleu nuit' },
    { i:  84, rgb: '#6c2f7a', label: 'Violet' },
    { i:  86, rgb: '#876cb2', label: 'Violet clair' },
    { i:  90, rgb: '#a500ff', label: 'Violet chaud' },
    { i:  91, rgb: '#ff00ff', label: 'Magenta' },
    { i:  92, rgb: '#b1942b', label: 'Or' },
];

const XENON_COLORS = [
    { i: 255, rgb: '#ffffff', label: 'Stock' },
    { i:   0, rgb: '#e8e8ff', label: 'Blanc' },
    { i:   1, rgb: '#5599ff', label: 'Bleu' },
    { i:   2, rgb: '#1133ff', label: 'Bleu électrique' },
    { i:   3, rgb: '#55ff88', label: 'Vert menthe' },
    { i:   4, rgb: '#00ff44', label: 'Vert lime' },
    { i:   5, rgb: '#ffff44', label: 'Jaune' },
    { i:   6, rgb: '#ffcc00', label: 'Or' },
    { i:   7, rgb: '#ff9900', label: 'Orange' },
    { i:   8, rgb: '#ff3300', label: 'Rouge' },
    { i:   9, rgb: '#ff44bb', label: 'Rose' },
    { i:  10, rgb: '#cc00ff', label: 'Violet' },
    { i:  11, rgb: '#00ccff', label: 'Cyan' },
    { i:  12, rgb: '#00ffcc', label: 'Turquoise' },
];

const WHEEL_TYPES = [
    { id: 0, label: 'Sport' },
    { id: 1, label: 'Muscle' },
    { id: 2, label: 'Lowrider' },
    { id: 3, label: '4x4' },
    { id: 4, label: 'Offroad' },
    { id: 5, label: 'Tuner' },
    { id: 7, label: 'High End' },
    { id: 12, label: "Benny's Orig." },
    { id: 13, label: "Benny's Besp." },
];

const TINTS = [
    { i: 0, label: 'Aucun' },
    { i: 1, label: 'Noir pur' },
    { i: 2, label: 'Fumé foncé' },
    { i: 3, label: 'Fumé léger' },
    { i: 4, label: 'Standard' },
    { i: 5, label: 'Limousine' },
    { i: 6, label: 'Vert' },
];

let activeWheelType = 0;
let activeWheelMod  = 0;
let neonColor = { r: 0, g: 255, b: 0 };

function buildColorGrid(containerId, slot, palette) {
    const grid = document.getElementById(containerId);
    if (!grid) return;
    grid.innerHTML = '';
    palette.forEach(c => {
        const sw = document.createElement('div');
        sw.className = 'color-swatch';
        sw.style.background = c.rgb;
        sw.title = c.label;
        sw.addEventListener('click', () => {
            grid.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('active'));
            sw.classList.add('active');
            if (slot === 'xenon') {
                nuiFetch('applyXenon', { enabled: true, colorIndex: c.i });
            } else if (slot === 'neon') {
                neonColor = hexToRgb(c.rgb);
                applyNeon();
            } else {
                nuiFetch('applyColor', { slot, index: c.i });
            }
        });
        grid.appendChild(sw);
    });
}

function hexToRgb(hex) {
    const r = parseInt(hex.slice(1,3),16);
    const g = parseInt(hex.slice(3,5),16);
    const b = parseInt(hex.slice(5,7),16);
    return { r, g, b };
}

function applyNeon() {
    nuiFetch('applyNeon', {
        left:  document.getElementById('neon-left').checked,
        right: document.getElementById('neon-right').checked,
        front: document.getElementById('neon-front').checked,
        back:  document.getElementById('neon-back').checked,
        r: neonColor.r,
        g: neonColor.g,
        b: neonColor.b,
    });
}

function buildWheelTypes() {
    const container = document.getElementById('wheel-types');
    if (!container) return;
    container.innerHTML = '';
    WHEEL_TYPES.forEach(wt => {
        const btn = document.createElement('button');
        btn.className = 'wheel-type-btn' + (activeWheelType === wt.id ? ' active' : '');
        btn.textContent = wt.label;
        btn.addEventListener('click', async () => {
            container.querySelectorAll('.wheel-type-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            activeWheelType = wt.id;
            activeWheelMod  = 0;
            const res = await nuiFetch('applyWheelType', { wheelType: wt.id }).then(r => r?.json?.()).catch(() => null);
            const count = res?.count ?? 20;
            buildWheelMods(count);
        });
        container.appendChild(btn);
    });
}

function buildWheelMods(count) {
    const container = document.getElementById('wheel-mods');
    if (!container) return;
    container.innerHTML = '';
    for (let i = 0; i < count; i++) {
        const btn = document.createElement('button');
        btn.className = 'wheel-mod-btn' + (activeWheelMod === i ? ' active' : '');
        btn.textContent = i === 0 ? 'Défaut' : `#${i}`;
        const modIdx = i;
        btn.addEventListener('click', () => {
            container.querySelectorAll('.wheel-mod-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            activeWheelMod = modIdx;
            nuiFetch('applyWheelMod', { modIndex: modIdx });
        });
        container.appendChild(btn);
    }
}

function buildTints() {
    const grid = document.getElementById('tint-grid');
    if (!grid) return;
    grid.innerHTML = '';
    TINTS.forEach(t => {
        const btn = document.createElement('button');
        btn.className = 'tint-btn';
        btn.textContent = t.label;
        btn.addEventListener('click', () => {
            grid.querySelectorAll('.tint-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            nuiFetch('applyTint', { tint: t.i });
        });
        grid.appendChild(btn);
    });
}

const BODY_MOD_LABELS = {
    0: 'AILERON / SPOILER',
    1: 'PARE-CHOC AVANT',
    2: 'PARE-CHOC ARRIÈRE',
    3: 'BAS DE CAISSE',
    4: 'ÉCHAPPEMENT',
    5: 'CHÂSSIS',
    6: 'CALANDRE',
    7: 'CAPOT',
    8: 'AILE GAUCHE',
    9: 'AILE DROITE',
    10: 'TOIT',
};

async function buildBodyMods() {
    const container = document.getElementById('body-mods-container');
    if (!container) return;
    container.innerHTML = '<div class="bm-loading">Chargement des pièces...</div>';
    const resp   = await nuiFetch('getBodyModCounts');
    const counts = resp ? await resp.json() : {};
    container.innerHTML = '';
    let hasAny = false;
    for (let modType = 0; modType <= 10; modType++) {
        const count = counts[String(modType)] || 0;
        if (count === 0) continue;
        hasAny = true;
        const section = document.createElement('div');
        section.className = 'paint-section';
        section.innerHTML = `<div class="paint-section-label">${BODY_MOD_LABELS[modType] || 'MOD ' + modType}</div>`;
        const strip = document.createElement('div');
        strip.className = 'bm-strip';
        // Bouton stock (index -1)
        const stockBtn = document.createElement('button');
        stockBtn.className = 'bm-btn';
        stockBtn.textContent = 'STOCK';
        stockBtn.onclick = () => { nuiFetch('applyBodyMod', { modType, modIndex: -1 }); highlightBmBtn(strip, stockBtn); };
        strip.appendChild(stockBtn);
        for (let i = 0; i < count; i++) {
            const btn = document.createElement('button');
            btn.className = 'bm-btn';
            btn.textContent = String(i + 1).padStart(2, '0');
            const idx = i;
            btn.onclick = () => { nuiFetch('applyBodyMod', { modType, modIndex: idx }); highlightBmBtn(strip, btn); };
            strip.appendChild(btn);
        }
        section.appendChild(strip);
        container.appendChild(section);
    }
    if (!hasAny) {
        container.innerHTML = '<div class="bm-loading">Aucune pièce disponible pour ce véhicule.</div>';
    }
}

function highlightBmBtn(strip, active) {
    strip.querySelectorAll('.bm-btn').forEach(b => b.classList.remove('active'));
    active.classList.add('active');
}

function openCustomShop() {
    // Sidebar indépendante — on n'utilise pas #root ni les overlays boutique/admin
    document.getElementById('custom-panel').classList.remove('hidden');

    buildColorGrid('grid-primary',    'primary',     GTA_COLORS);
    buildColorGrid('grid-secondary',  'secondary',   GTA_COLORS);
    buildColorGrid('grid-pearl',      'pearlescent', GTA_COLORS);
    buildColorGrid('grid-wheelcolor', 'wheelcolor',  GTA_COLORS);
    buildColorGrid('grid-xenon',      'xenon',       XENON_COLORS);
    buildColorGrid('grid-neon',       'neon',        GTA_COLORS);

    buildWheelTypes();
    buildWheelMods(20);
    buildTints();

    // Tab switching — uniquement les tabs du custom panel
    document.querySelectorAll('#custom-panel .custom-tab').forEach(tab => {
        tab.onclick = () => {
            document.querySelectorAll('#custom-panel .custom-tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('#custom-panel .custom-pane').forEach(p => p.classList.add('hidden'));
            tab.classList.add('active');
            const pane = document.getElementById('pane-' + tab.dataset.tab);
            if (pane) pane.classList.remove('hidden');
            if (tab.dataset.tab === 'esthet') buildBodyMods();
        };
    });
    document.querySelectorAll('#custom-panel .custom-tab')[0]?.click();

    const xenonEl = document.getElementById('xenon-enabled');
    if (xenonEl) {
        xenonEl.onchange = () => nuiFetch('applyXenon', { enabled: xenonEl.checked, colorIndex: 255 });
    }
    ['neon-left','neon-right','neon-front','neon-back'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.onchange = applyNeon;
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// Close / Escape
// ═══════════════════════════════════════════════════════════════════════════
function closeAll() {
    document.getElementById('root').classList.add('hidden');
    document.getElementById('player-panel').classList.add('hidden');
    document.getElementById('admin-panel').classList.add('hidden');
    document.getElementById('custom-panel').classList.add('hidden');
    nuiFetch('close');
}

function closeCustomPanel() {
    document.getElementById('custom-panel').classList.add('hidden');
    nuiFetch('close');
}

// ═══════════════════════════════════════════════════════════════════════════
// DOM ready
// ═══════════════════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', () => {
    // Scroll molette sur les grilles (backup pour FiveM CEF)
    document.addEventListener('wheel', e => {
        const grid = e.target.closest('.b-items-grid');
        if (grid) {
            grid.scrollTop += e.deltaY;
            e.preventDefault();
        }
    }, { passive: false });

    document.getElementById('close-player').addEventListener('click', closeAll);
    document.getElementById('close-admin').addEventListener('click', closeAll);
    document.getElementById('close-custom').addEventListener('click', closeCustomPanel);
    document.getElementById('btn-add-item').addEventListener('click', () => {
        document.getElementById('edit-category').value = activeCat || categories[0]?.id || '';
        showEditor();
    });
    document.getElementById('btn-save').addEventListener('click', saveItem);
    document.getElementById('btn-cancel').addEventListener('click', hideEditor);

    document.getElementById('btn-buy-coins').addEventListener('click', () => {
        document.getElementById('modal-store-url').textContent = tebexUrl || '';
        document.getElementById('store-modal').classList.remove('hidden');
    });

    document.getElementById('store-open-btn').addEventListener('click', () => {
        if (tebexUrl) {
            try {
                window.invokeNative('openUrl', tebexUrl);
            } catch(e) {
                window.open(tebexUrl, '_blank');
            }
        }
        document.getElementById('store-modal').classList.add('hidden');
    });

    document.getElementById('store-close-btn').addEventListener('click', () => {
        document.getElementById('store-modal').classList.add('hidden');
    });

    document.getElementById('modal-confirm').addEventListener('click', () => {
        if (pendingBuy) {
            nuiFetch('buy', pendingBuy);
            pendingBuy = null;
        }
        document.getElementById('buy-modal').classList.add('hidden');
    });

    document.getElementById('modal-cancel').addEventListener('click', () => {
        pendingBuy = null;
        document.getElementById('buy-modal').classList.add('hidden');
    });

    document.getElementById('btn-refresh-logs').addEventListener('click', () => {
        nuiFetch('adminGetLogs');
    });

    document.getElementById('btn-refresh-coins').addEventListener('click', () => {
        nuiFetch('adminGetLogs');
    });

    const coinsSearch = document.getElementById('coins-search');
    if (coinsSearch) {
        coinsSearch.addEventListener('input', () => renderCoinsTable(coinsSearch.value));
    }

    // btn-place-npc est rebranché dans renderCategories à chaque render

    document.addEventListener('keydown', e => {
        if (e.key !== 'Escape') return;
        if (!document.getElementById('buy-modal').classList.contains('hidden')) {
            pendingBuy = null;
            document.getElementById('buy-modal').classList.add('hidden');
            return;
        }
        if (!document.getElementById('store-modal').classList.contains('hidden')) {
            document.getElementById('store-modal').classList.add('hidden');
            return;
        }
        const customOpen = !document.getElementById('custom-panel').classList.contains('hidden');
        const rootOpen   = !document.getElementById('root').classList.contains('hidden');
        if (customOpen && !rootOpen) { closeCustomPanel(); }
        else { closeAll(); }
    });
});

// ═══════════════════════════════════════════════════════════════════════════
// NUI messages
// ═══════════════════════════════════════════════════════════════════════════
window.addEventListener('message', e => {
    const d = e.data;
    if (!d?.type) return;

    switch (d.type) {
        case 'openPlayer':        openPlayer(d.items || [], d.coins || 0, d.categories || [], d.tebexUrl || '', d.ownedIds || []);  break;
        case 'openAdmin':         openAdmin(d.items || [], d.categories || [], d.npcs || [], d.customNpcs || []);       break;
        case 'openCustomShop':    openCustomShop();                                                                      break;
        case 'updateCoins':       setCoins(d.coins || 0);                                                               break;
        case 'adminSync':         syncItems(d.items || []);                                                              break;
        case 'adminGarageNpcSync':
            allNpcs = d.npcs || [];
            if (adminTab === 'garage') renderNpcList();
            break;
        case 'adminCustomNpcSync':
            allCNpcs = d.npcs || [];
            if (adminTab === 'custom') renderCNpcList();
            break;
        case 'adminLogsData':
            allLogs  = d.logs  || [];
            allCoins = d.coins || [];
            if (adminTab === 'logs')  renderLogs();
            if (adminTab === 'coins') renderCoinsTable(document.getElementById('coins-search')?.value || '');
            break;
    }
});
