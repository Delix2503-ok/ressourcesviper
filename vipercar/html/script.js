'use strict';

// ─── State ────────────────────────────────────────────────────────────────────
let npcs = [];
let pendingDeleteId = null;

// ─── DOM refs ─────────────────────────────────────────────────────────────────
const overlay   = document.getElementById('overlay');
const npcList   = document.getElementById('npc-list');
const emptyState = document.getElementById('empty-state');
const statCount = document.getElementById('stat-count');
const closeBtn  = document.getElementById('closeBtn');
const addBtn    = document.getElementById('addBtn');

let confirmOverlay = null;

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmt(v) { return parseFloat(v).toFixed(1); }

function buildCard(npc) {
    const card = document.createElement('div');
    card.className = 'npc-card';
    card.dataset.id = npc.id;
    card.innerHTML = `
        <div class="npc-icon"><i class="fa-solid fa-person"></i></div>
        <div class="npc-info">
            <div class="npc-id">PNJ #${npc.id}</div>
            <div class="npc-coords">
                <div class="coord-row">
                    <i class="fa-solid fa-location-dot"></i>
                    <span>PNJ — X: ${fmt(npc.x)} | Y: ${fmt(npc.y)} | Z: ${fmt(npc.z)}</span>
                </div>
                <div class="coord-row spawn-row">
                    <i class="fa-solid fa-car"></i>
                    <span>Spawn 1 — X: ${fmt(npc.spawn_x1)} | Y: ${fmt(npc.spawn_y1)} | Z: ${fmt(npc.spawn_z1)}</span>
                </div>
                <div class="coord-row spawn-row">
                    <i class="fa-solid fa-car"></i>
                    <span>Spawn 2 — X: ${fmt(npc.spawn_x2)} | Y: ${fmt(npc.spawn_y2)} | Z: ${fmt(npc.spawn_z2)}</span>
                </div>
                <div class="coord-row spawn-row">
                    <i class="fa-solid fa-car"></i>
                    <span>Spawn 3 — X: ${fmt(npc.spawn_x3)} | Y: ${fmt(npc.spawn_y3)} | Z: ${fmt(npc.spawn_z3)}</span>
                </div>
                <div class="coord-row spawn-row">
                    <i class="fa-solid fa-car"></i>
                    <span>Spawn 4 — X: ${fmt(npc.spawn_x4)} | Y: ${fmt(npc.spawn_y4)} | Z: ${fmt(npc.spawn_z4)}</span>
                </div>
            </div>
        </div>
        <button class="btn-delete" data-id="${npc.id}">
            <i class="fa-solid fa-trash"></i> Supprimer
        </button>
    `;
    card.querySelector('.btn-delete').addEventListener('click', () => askDelete(npc.id));
    return card;
}

function renderList() {
    Array.from(npcList.children).forEach(el => {
        if (!el.classList.contains('empty-state')) el.remove();
    });
    statCount.textContent = npcs.length;
    if (npcs.length === 0) {
        emptyState.style.display = 'flex';
        return;
    }
    emptyState.style.display = 'none';
    npcs.forEach(npc => npcList.appendChild(buildCard(npc)));
}

// ─── Confirmation suppression ─────────────────────────────────────────────────
function askDelete(id) {
    pendingDeleteId = id;
    if (!confirmOverlay) {
        confirmOverlay = document.createElement('div');
        confirmOverlay.id = 'confirm-overlay';
        confirmOverlay.innerHTML = `
            <div class="confirm-box">
                <h3><i class="fa-solid fa-triangle-exclamation"></i> Supprimer le PNJ ?</h3>
                <p>Cette action est irréversible.<br>Le PNJ et ses points de spawn seront supprimés.</p>
                <div class="confirm-actions">
                    <button class="btn-confirm-yes" id="confirmYes">Supprimer</button>
                    <button class="btn-confirm-no"  id="confirmNo">Annuler</button>
                </div>
            </div>
        `;
        document.body.appendChild(confirmOverlay);
        document.getElementById('confirmYes').addEventListener('click', confirmDelete);
        document.getElementById('confirmNo').addEventListener('click', cancelDelete);
    }
    confirmOverlay.classList.remove('hidden');
}

function confirmDelete() {
    if (pendingDeleteId === null) return;
    sendNUI('deleteNPC', { id: pendingDeleteId });
    npcs = npcs.filter(n => n.id !== pendingDeleteId);
    const card = npcList.querySelector(`[data-id="${pendingDeleteId}"]`);
    if (card) card.remove();
    statCount.textContent = npcs.length;
    if (npcs.length === 0) emptyState.style.display = 'flex';
    pendingDeleteId = null;
    confirmOverlay.classList.add('hidden');
}

function cancelDelete() {
    pendingDeleteId = null;
    if (confirmOverlay) confirmOverlay.classList.add('hidden');
}

// ─── NUI bridge ───────────────────────────────────────────────────────────────
function sendNUI(action, data) {
    // Retourne la promesse pour permettre d'attendre la réponse Lua
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data ?? {}),
    }).catch(() => {});
}

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'vipercar';
}

// ─── Messages NUI (depuis Lua) ────────────────────────────────────────────────
window.addEventListener('message', (e) => {
    const { action, npcs: incomingNPCs, npc } = e.data;

    if (action === 'open') {
        npcs = incomingNPCs || [];
        renderList();
        overlay.classList.remove('hidden');
    }

    if (action === 'npcAdded' && npc) {
        npcs.push(npc);
        emptyState.style.display = 'none';
        npcList.appendChild(buildCard(npc));
        statCount.textContent = npcs.length;
        overlay.classList.remove('hidden');
    }

    if (action === 'cancelPlacement') {
        overlay.classList.remove('hidden');
    }
});

// ─── Boutons ──────────────────────────────────────────────────────────────────
closeBtn.addEventListener('click', () => {
    overlay.classList.add('hidden');
    sendNUI('close');
});

addBtn.addEventListener('click', () => {
    overlay.classList.add('hidden');
    sendNUI('startPlacement');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (confirmOverlay && !confirmOverlay.classList.contains('hidden')) {
            cancelDelete();
        } else {
            overlay.classList.add('hidden');
            sendNUI('close');
        }
    }
});
