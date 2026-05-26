'use strict';

// ── État ──────────────────────────────────────────────────────────────────────
let queueInterval    = null;
let queueSecs        = 0;
let countdownTimeout = null;

// ── Utilitaires ───────────────────────────────────────────────────────────────
const el = id => document.getElementById(id);

function nuiFetch(name, data = {}) {
    return fetch(`https://viper_ranked/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

// ── Dispatcher principal ──────────────────────────────────────────────────────
window.addEventListener('message', ({ data }) => {
    switch (data.type) {
        case 'showScore':      showScore(data);              break;
        case 'hideScore':      el('score-hud').classList.add('hidden'); break;
        case 'updateScore':    updateScore(data);            break;
        case 'showCountdown':  showCountdown(data.seconds);  break;
        case 'showResult':     showResult(data);             break;
        case 'hideResult':     el('result-overlay').classList.add('hidden'); break;
        case 'openHub':            openHub(data);                break;
        case 'updateLeaderboard':  renderLeaderboard(data.rows); break;
        case 'updateShop':         renderShop(data.shopData);    break;
        case 'itemBought':         onItemBought(data);           break;
        case 'showGroup':        showGroup(data.code, data.mode, data.n, data.max); break;
        case 'updateGroupCount': el('group-members-text').textContent = data.n + ' / ' + data.max + ' joueurs'; break;
        case 'showQueue':        showQueue(data.mode);         break;
        case 'hideQueue':        hideQueue();                  break;
        case 'showRematch':      showRematch(data.seconds);    break;
    }
});

// ═══════════════════════════════════════════════
//  HUD SCORE
// ═══════════════════════════════════════════════
function showScore(d) {
    el('hud-t1-name').textContent  = d.team1Name  ?? 'Team 1';
    el('hud-t2-name').textContent  = d.team2Name  ?? 'Team 2';
    el('hud-t1-score').textContent = d.team1Score ?? 0;
    el('hud-t2-score').textContent = d.team2Score ?? 0;
    el('hud-round').textContent    = 'ROUND ' + (d.round ?? 1);
    el('score-hud').classList.remove('hidden');
}

function updateScore(d) {
    if (d.team1Score !== undefined) {
        const s1 = el('hud-t1-score');
        s1.textContent = d.team1Score;
        s1.classList.remove('bump'); void s1.offsetWidth; s1.classList.add('bump');
    }
    if (d.team2Score !== undefined) {
        const s2 = el('hud-t2-score');
        s2.textContent = d.team2Score;
        s2.classList.remove('bump'); void s2.offsetWidth; s2.classList.add('bump');
    }
    if (d.round !== undefined) el('hud-round').textContent = 'ROUND ' + d.round;
}

// ── Countdown ─────────────────────────────────────────────────────────────────
function showCountdown(seconds) {
    if (countdownTimeout) clearTimeout(countdownTimeout);
    const bar = el('hud-countdown');
    const num = el('hud-countdown-num');
    let count = seconds;
    bar.classList.remove('hidden');
    num.textContent = count;
    const tick = () => {
        count--;
        if (count <= 0) { bar.classList.add('hidden'); return; }
        num.textContent = count;
        countdownTimeout = setTimeout(tick, 1000);
    };
    countdownTimeout = setTimeout(tick, 1000);
}

// ═══════════════════════════════════════════════
//  RÉSULTAT
// ═══════════════════════════════════════════════
function showResult(d) {
    const overlay = el('result-overlay');
    const box     = overlay.querySelector('.result-box');
    const title   = el('result-title');
    const eloChip = el('result-elo');
    const rcChip  = el('result-coins');

    title.textContent    = d.text;
    box.className        = 'result-box ' + (d.win ? 'win' : 'lose');
    eloChip.textContent  = (d.eloChange ?? '') + ' ELO';

    if (d.coins && d.coins > 0) {
        rcChip.textContent   = '+' + d.coins + ' RC';
        rcChip.style.display = '';
    } else {
        rcChip.style.display = 'none';
    }

    overlay.classList.remove('hidden');
}

// ═══════════════════════════════════════════════
//  HUB  (Classement + Boutique)
// ═══════════════════════════════════════════════
function openHub(d) {
    el('hub-overlay').classList.remove('hidden');
    switchTab(d.tab);
    if (d.tab === 'leaderboard' && d.rows)      renderLeaderboard(d.rows);
    if (d.tab === 'shop'        && d.shopData)  renderShop(d.shopData);
}

function closeHub() {
    el('hub-overlay').classList.add('hidden');
    nuiFetch('closeHub');
}

el('btn-close-hub').addEventListener('click', closeHub);
document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && !el('hub-overlay').classList.contains('hidden')) closeHub();
});

// Onglets
document.querySelectorAll('.hub-tab').forEach(btn => {
    btn.addEventListener('click', () => {
        switchTab(btn.dataset.tab);
        if (btn.dataset.tab === 'leaderboard') nuiFetch('refreshLeaderboard');
        if (btn.dataset.tab === 'shop')        nuiFetch('refreshShop');
    });
});

function switchTab(name) {
    document.querySelectorAll('.hub-tab').forEach(b => b.classList.toggle('active', b.dataset.tab === name));
    document.querySelectorAll('.hub-content').forEach(c => c.classList.add('hidden'));
    el('tab-' + name).classList.remove('hidden');
}

// ── Leaderboard ───────────────────────────────────────────────────────────────
function renderLeaderboard(rows) {
    const tbody = el('lb-body');
    tbody.innerHTML = '';
    if (!rows || !rows.length) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:40px;color:var(--text-dim)">Aucun joueur pour l\'instant.</td></tr>';
        return;
    }
    rows.forEach((p, i) => {
        const rank  = i + 1;
        const ratio = p.matches > 0 ? ((p.wins / p.matches) * 100).toFixed(1) + '%' : '–';
        let   badge = rank;
        if (rank === 1) badge = '🥇';
        if (rank === 2) badge = '🥈';
        if (rank === 3) badge = '🥉';
        const tr = document.createElement('tr');
        if (rank <= 3) tr.classList.add('rank-' + rank);
        tr.innerHTML = `
            <td><span class="rank-badge">${badge}</span></td>
            <td class="lb-name">${escHtml(p.name ?? 'Inconnu')}</td>
            <td class="lb-elo">${p.elo ?? 1000}</td>
            <td class="lb-win">${p.wins ?? 0}</td>
            <td class="lb-lose">${p.losses ?? 0}</td>
            <td>${p.matches ?? 0}</td>
            <td>${ratio}</td>
        `;
        tbody.appendChild(tr);
    });
}

// ── Boutique ──────────────────────────────────────────────────────────────────
let _shopCoins = 0;

function renderShop(data) {
    _shopCoins = data.coins ?? 0;
    el('nav-coins').textContent  = _shopCoins;
    el('shop-coins').textContent = _shopCoins;

    // Jours restants
    const rotEnd  = ((data.rotationStart ?? 0) + (data.rotationDays ?? 14) * 86400) * 1000;
    const msLeft  = rotEnd - Date.now();
    const daysLeft = Math.max(0, Math.ceil(msLeft / 86400000));
    el('shop-days').textContent = daysLeft;

    const grid = el('shop-grid');
    grid.innerHTML = '';

    if (!data.items || !data.items.length) {
        grid.innerHTML = '<div class="shop-empty">Aucun article disponible cette rotation.<br>Revenez bientôt!</div>';
        return;
    }

    data.items.forEach(item => {
        const bought     = data.bought && (data.bought[item.id] || data.bought[String(item.id)]);
        const canAfford  = _shopCoins >= item.price;
        const imgName    = item.item_name.toUpperCase() + '.png';
        const card       = document.createElement('div');

        card.className = 'item-card' + (bought ? ' is-bought' : '') + (!canAfford && !bought ? ' no-coins' : '');
        card.innerHTML = `
            ${bought ? '<div class="bought-ribbon">✓ Acheté</div>' : ''}
            <div class="item-img-wrap">
                <img src="img/${imgName}" alt="${escHtml(item.item_label)}"
                     onerror="this.style.display='none';this.nextElementSibling.style.display='block'">
                <div class="item-icon-fallback" style="display:none">${item.item_type === 'weapon' ? '🔫' : '📦'}</div>
            </div>
            <div class="item-info">
                <div class="item-label">${escHtml(item.item_label)}</div>
                <span class="item-type-badge">${item.item_type === 'weapon' ? 'Arme' : 'Item'}</span>
                <div class="item-footer">
                    <div class="item-price">
                        <svg class="coin-svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#FFB800" stroke="#FF8C00" stroke-width="1.5"/><text x="12" y="17" text-anchor="middle" font-size="12" font-weight="700" fill="#3a1f00" font-family="Rajdhani,sans-serif">RC</text></svg>
                        ${item.price}
                    </div>
                    <button class="btn-buy ${bought ? 'bought' : ''}"
                            data-id="${item.id}"
                            ${bought ? 'disabled' : ''}
                            ${!bought && !canAfford ? 'disabled title="Pas assez de RC"' : ''}>
                        ${bought ? '✓ Acheté' : 'Acheter'}
                    </button>
                </div>
            </div>
        `;
        grid.appendChild(card);
    });

    // Boutons d'achat
    grid.querySelectorAll('.btn-buy:not(.bought):not(:disabled)').forEach(btn => {
        btn.addEventListener('click', () => {
            nuiFetch('buyItem', { itemId: parseInt(btn.dataset.id) });
        });
    });
}

function onItemBought(d) {
    _shopCoins = d.newCoins ?? 0;
    el('nav-coins').textContent  = _shopCoins;
    el('shop-coins').textContent = _shopCoins;

    // Mettre à jour la carte
    const btn = el('shop-grid') && el('shop-grid').querySelector(`[data-id="${d.itemId}"]`);
    if (btn) {
        const card = btn.closest('.item-card');
        btn.textContent = '✓ Acheté';
        btn.classList.add('bought');
        btn.disabled = true;
        card.classList.add('is-bought');
        card.classList.remove('no-coins');
        if (!card.querySelector('.bought-ribbon')) {
            const ribbon = document.createElement('div');
            ribbon.className = 'bought-ribbon'; ribbon.textContent = '✓ Acheté';
            card.prepend(ribbon);
        }
    }
}

// ═══════════════════════════════════════════════
//  FILE D'ATTENTE + GROUPE
// ═══════════════════════════════════════════════
function showGroup(code, mode, n, max) {
    el('qw-mode').textContent         = mode.toUpperCase();
    el('qw-status-text').textContent  = 'EN ATTENTE DE MEMBRES';
    el('group-code-text').textContent = code;
    el('group-members-text').textContent = n + ' / ' + max + ' joueurs';
    el('group-code-wrap').classList.remove('hidden');
    el('qw-timer-row').classList.add('hidden');
    el('queue-widget').classList.remove('hidden');
    if (queueInterval) { clearInterval(queueInterval); queueInterval = null; }
    queueSecs = 0;
}

function showQueue(mode) {
    el('qw-mode').textContent        = mode.toUpperCase();
    el('qw-status-text').textContent = 'EN FILE D\'ATTENTE';
    el('group-code-wrap').classList.add('hidden');
    el('qw-timer-row').classList.remove('hidden');
    el('queue-widget').classList.remove('hidden');
    queueSecs = 0; renderTimer();
    if (queueInterval) clearInterval(queueInterval);
    queueInterval = setInterval(() => { queueSecs++; renderTimer(); }, 1000);
}

function hideQueue() {
    el('queue-widget').classList.add('hidden');
    if (queueInterval) { clearInterval(queueInterval); queueInterval = null; }
    queueSecs = 0;
    el('qw-key-hint-text').textContent = 'Quitter';
}

let rematchInterval = null;
function showRematch(totalSeconds) {
    el('qw-mode').textContent        = 'REMATCH';
    el('qw-status-text').textContent = 'PROCHAIN MATCH DANS ' + totalSeconds + 's';
    el('group-code-wrap').classList.add('hidden');
    el('qw-timer-row').classList.remove('hidden');
    el('qw-timer').textContent       = totalSeconds + 's';
    el('qw-key-hint-text').textContent = 'Annuler';
    el('queue-widget').classList.remove('hidden');
    if (queueInterval)   { clearInterval(queueInterval);   queueInterval   = null; }
    if (rematchInterval) { clearInterval(rematchInterval); rematchInterval = null; }
    let secs = totalSeconds;
    rematchInterval = setInterval(() => {
        secs--;
        el('qw-status-text').textContent = 'PROCHAIN MATCH DANS ' + secs + 's';
        el('qw-timer').textContent       = secs + 's';
        if (secs <= 0) { clearInterval(rematchInterval); rematchInterval = null; }
    }, 1000);
}

function renderTimer() {
    const m = String(Math.floor(queueSecs / 60)).padStart(2, '0');
    const s = String(queueSecs % 60).padStart(2, '0');
    el('qw-timer').textContent = m + ':' + s;
}

// Quitter la file via touche X (géré côté client Lua, pas de bouton cliquable)

// ── Sécurité HTML ─────────────────────────────────────────────────────────────
function escHtml(str) {
    return String(str ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
