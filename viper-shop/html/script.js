'use strict';

let currentMode     = null;
let currentShopType = 'weapons';
let allItems        = { weapons: [], ammo: [], illegal: [] };
let editingId       = null;
let sellItemsData   = [];

function esc(str) {
    if (str == null) return '';
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function imgFallback(img) {
    try {
        const list = JSON.parse(img.dataset.fallbacks || '[]');
        if (list.length > 0) {
            img.dataset.fallbacks = JSON.stringify(list.slice(1));
            img.src = list[0];
        } else {
            img.parentElement.classList.add('img-missing');
        }
    } catch(e) {
        img.parentElement.classList.add('img-missing');
    }
}

function nuiFetch(cb, data) {
    fetch('https://viper-shop/' + cb, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    });
}

// ── Messages NUI ───────────────────────────────────────────────────────────────
window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.type === 'openAdmin') openAdmin(d.items);
    if (d.type === 'openShop')  openShop(d.shopType, d.shopLabel, d.items, d.sellItems);
});

document.querySelectorAll('.ptab-btn').forEach(btn => {
    btn.addEventListener('click', () => switchPlayerTab(btn.dataset.ptab));
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

function openAdmin(items) {
    const alreadyOpen = currentMode === 'admin';
    allItems = { weapons: [], ammo: [], illegal: [] };
    (items || []).forEach(item => {
        if (allItems[item.shop_type] !== undefined) allItems[item.shop_type].push(item);
    });

    currentMode = 'admin';
    document.getElementById('root').classList.remove('hidden');
    document.getElementById('admin-panel').classList.remove('hidden');
    document.getElementById('player-panel').classList.add('hidden');

    renderItemList();
    if (!alreadyOpen) {
        showEmpty();
    } else if (editingId && !allItems[currentShopType].find(i => i.id === editingId)) {
        showEmpty();
    }
}

function switchTab(shopType) {
    currentShopType = shopType;
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('tab-active', btn.dataset.shop === shopType);
    });
    const spawnBtn = document.getElementById('btn-spawn-npc');
    spawnBtn.classList.remove('ammo-spawn', 'illegal-spawn');
    if (shopType === 'ammo')    spawnBtn.classList.add('ammo-spawn');
    if (shopType === 'illegal') spawnBtn.classList.add('illegal-spawn');
    renderItemList();
    showEmpty();
}

function renderItemList() {
    const list  = document.getElementById('admin-items-list');
    const items = allItems[currentShopType] || [];
    document.getElementById('item-count').textContent = items.length;

    if (!items.length) {
        list.innerHTML = '<div class="list-empty">Aucun article</div>';
        return;
    }
    list.innerHTML = items.map(item => `
        <div class="item-row${editingId === item.id ? ' active' : ''}" data-id="${item.id}" onclick="selectItem(${item.id})">
            <span class="item-row-name">${esc(item.label)}</span>
            <span class="item-row-price">$${item.price}</span>
            <button class="item-del-btn" onclick="event.stopPropagation();deleteItem(${item.id})" title="Supprimer">✕</button>
        </div>
    `).join('');
}

function selectItem(id) {
    const item = (allItems[currentShopType] || []).find(i => i.id === id);
    if (!item) return;
    editingId = id;
    document.getElementById('form-title').textContent  = 'MODIFIER L\'ARTICLE';
    document.getElementById('edit-id').value           = id;
    document.getElementById('field-label').value       = item.label     || '';
    document.getElementById('field-item').value        = item.item_name || '';
    document.getElementById('field-price').value       = item.price     ?? 0;
    document.getElementById('editor-empty').classList.add('hidden');
    document.getElementById('editor-form').classList.remove('hidden');
    renderItemList();
}

function showEmpty() {
    editingId = null;
    document.getElementById('editor-empty').classList.remove('hidden');
    document.getElementById('editor-form').classList.add('hidden');
    renderItemList();
}

document.getElementById('btn-new-item').addEventListener('click', () => {
    editingId = null;
    document.getElementById('form-title').textContent  = 'NOUVEL ARTICLE';
    document.getElementById('edit-id').value           = '';
    document.getElementById('field-label').value       = '';
    document.getElementById('field-item').value        = '';
    document.getElementById('field-price').value       = 0;
    document.getElementById('editor-empty').classList.add('hidden');
    document.getElementById('editor-form').classList.remove('hidden');
    document.getElementById('field-label').focus();
    renderItemList();
});

document.getElementById('btn-save').addEventListener('click', () => {
    const label    = document.getElementById('field-label').value.trim();
    const itemName = document.getElementById('field-item').value.trim();
    const price    = parseInt(document.getElementById('field-price').value) || 0;

    if (!label)    { document.getElementById('field-label').focus(); return; }
    if (!itemName) { document.getElementById('field-item').focus();  return; }

    const data = { label, item_name: itemName, price, shop_type: currentShopType };
    if (editingId) { data.id = editingId; nuiFetch('adminEdit', data); }
    else           { nuiFetch('adminCreate', data); }
});

document.getElementById('btn-cancel').addEventListener('click', showEmpty);

function deleteItem(id) {
    nuiFetch('adminDelete', { id });
    if (editingId === id) showEmpty();
}

document.getElementById('btn-spawn-npc').addEventListener('click', () => {
    const btn = document.getElementById('btn-spawn-npc');
    nuiFetch('spawnNpcHere', { shopType: currentShopType });
    btn.textContent = '✔ SPAWNÉ';
    btn.classList.add('spawned');
    setTimeout(() => {
        btn.textContent = '📍 SPAWN ICI';
        btn.classList.remove('spawned');
    }, 2500);
});

document.getElementById('btn-tp-npc').addEventListener('click', () => {
    nuiFetch('tpToNpc', { shopType: currentShopType });
});

document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.shop));
});

// ══ PANEL JOUEUR ═══════════════════════════════════════════════════════════════

function openShop(shopType, shopLabel, items, sellItems) {
    currentMode = 'shop';
    document.getElementById('root').classList.remove('hidden');
    document.getElementById('player-panel').classList.remove('hidden');
    document.getElementById('admin-panel').classList.add('hidden');

    document.getElementById('shop-title').textContent = (shopLabel || '').toUpperCase();

    const win = document.getElementById('player-window');
    win.classList.remove('ammo-theme', 'illegal-theme');
    if (shopType === 'ammo')    win.classList.add('ammo-theme');
    if (shopType === 'illegal') win.classList.add('illegal-theme');

    // Onglets ACHETER / REVENDRE — uniquement pour weapons
    sellItemsData = sellItems || [];
    const tabs = document.getElementById('player-tabs');
    if (shopType === 'weapons') {
        tabs.classList.remove('hidden');
        switchPlayerTab('buy');
    } else {
        tabs.classList.add('hidden');
        document.getElementById('shop-grid').classList.remove('hidden');
        document.getElementById('sell-grid').classList.add('hidden');
    }

    renderBuyGrid(items);
    renderSellGrid(sellItemsData);
}

function switchPlayerTab(tab) {
    document.querySelectorAll('.ptab-btn').forEach(btn => {
        btn.classList.toggle('ptab-active', btn.dataset.ptab === tab);
    });
    document.getElementById('shop-grid').classList.toggle('hidden', tab !== 'buy');
    document.getElementById('sell-grid').classList.toggle('hidden', tab !== 'sell');
    const subtitle = document.getElementById('player-subtitle');
    if (tab === 'sell') {
        subtitle.innerHTML = 'Revends tes armes — paiement en <span style="color:#FFB800;font-weight:700;font-family:\'Share Tech Mono\',monospace">argent sale</span>';
    } else {
        subtitle.innerHTML = 'Choisis tes articles — paiement en <span class="money-tag">$</span>';
    }
}

function renderBuyGrid(items) {
    const grid = document.getElementById('shop-grid');
    if (!items || !items.length) {
        grid.innerHTML = '<div class="shop-empty">Aucun article disponible pour le moment</div>';
        return;
    }
    items = [...items].sort((a, b) => a.price - b.price);
    grid.innerHTML = items.map(item => `
        <div class="shop-card">
            <div class="shop-card-img">
                <img src="nui://ox_inventory/web/images/${item.item_name.toUpperCase()}.png"
                     data-fallbacks='["nui://ox_inventory/web/images/${esc(item.item_name)}.png","nui://ggcweapons/images/${esc(item.item_name)}.png","nui://vipergun/html/images/${item.item_name.toUpperCase()}.png","nui://vipergun/html/images/${esc(item.item_name)}.png"]'
                     onerror="imgFallback(this)"
                     alt="" />
            </div>
            <div class="shop-card-header">
                <span class="shop-card-name">${esc(item.label)}</span>
            </div>
            <div class="shop-card-price" data-unit="${item.price}">$${item.price}</div>
            <div class="shop-card-qty">
                <button class="qty-btn" onclick="adjQty(this,-1)">−</button>
                <input class="qty-input" type="number" value="1" min="1" max="10000"
                       oninput="updatePrice(this)" />
                <button class="qty-btn" onclick="adjQty(this,1)">+</button>
            </div>
            <button class="shop-card-buy" onclick="buyItem(${item.id},this)">ACHETER</button>
        </div>
    `).join('');
}

function renderSellGrid(sellItems) {
    const grid = document.getElementById('sell-grid');
    if (!sellItems || !sellItems.length) {
        grid.innerHTML = '<div class="shop-empty">Aucune arme à revendre dans votre inventaire</div>';
        return;
    }
    grid.innerHTML = sellItems.map(item => `
        <div class="shop-card sell-card">
            <div class="shop-card-img">
                <img src="nui://ox_inventory/web/images/${item.name.toUpperCase()}.png"
                     data-fallbacks='["nui://ox_inventory/web/images/${esc(item.name)}.png","nui://ggcweapons/images/${esc(item.name)}.png","nui://vipergun/html/images/${item.name.toUpperCase()}.png"]'
                     onerror="imgFallback(this)" alt="" />
            </div>
            <div class="shop-card-header">
                <span class="shop-card-name">${esc(item.label)}</span>
                <span class="owned-badge">En stock : ${item.owned}</span>
            </div>
            <div class="shop-card-price" data-unit="${item.sell_price}">${item.sell_price}</div>
            <div class="sell-price-label">argent sale / unité</div>
            <div class="shop-card-qty">
                <button class="qty-btn" onclick="adjQty(this,-1)">−</button>
                <input class="qty-input" type="number" value="1" min="1" max="${item.owned}"
                       oninput="updatePrice(this)" />
                <button class="qty-btn" onclick="adjQty(this,1)">+</button>
            </div>
            <button class="shop-card-buy" onclick="sellItem('${esc(item.name)}',this)">VENDRE</button>
        </div>
    `).join('');
}

function sellItem(name, btn) {
    const card = btn.closest('.shop-card');
    const qty  = Math.max(1, parseInt(card.querySelector('.qty-input').value) || 1);
    nuiFetch('sell', { name, qty });
    document.getElementById('root').classList.add('hidden');
    document.getElementById('player-panel').classList.add('hidden');
}

function adjQty(btn, delta) {
    const input = btn.parentElement.querySelector('.qty-input');
    const max = parseInt(input.max) || 10000;
    const val = Math.max(1, Math.min(max, (parseInt(input.value) || 1) + delta));
    input.value = val;
    updatePrice(input);
}

function updatePrice(input) {
    const card  = input.closest('.shop-card');
    const el    = card.querySelector('.shop-card-price');
    const unit  = parseInt(el.dataset.unit) || 0;
    const qty   = Math.max(1, parseInt(input.value) || 1);
    el.textContent = '$' + (unit * qty);
}

function buyItem(id, btn) {
    const card = btn.closest('.shop-card');
    const qty  = Math.max(1, Math.min(10000, parseInt(card.querySelector('.qty-input').value) || 1));
    nuiFetch('buy', { id, qty });
    // Masquer les panneaux HTML (SetNuiFocus géré côté client)
    document.getElementById('root').classList.add('hidden');
    document.getElementById('player-panel').classList.add('hidden');
}
