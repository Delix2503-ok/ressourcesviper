# CLAUDE.md — viper_ranked

Ressource FiveM ranked PvP pour QBCore. Ce fichier permet de reprendre le contexte complet.

---

## Stack technique

- **Framework** : QBCore (`exports['qb-core']:GetCoreObject()`)
- **DB** : oxmysql (`MySQL.query.await`, `MySQL.scalar.await`, `MySQL.insert.await`)
- **UI/menus** : ox_lib (`lib.registerContext`, `lib.showContext`, `lib.inputDialog`, `lib.alertDialog`, `lib.notify`)
- **Inventaire** : ox_inventory (`exports.ox_inventory:AddItem`, `exports.ox_inventory:GetItemsByName`)
- **NUI** : HTML/CSS/JS avec `SendNUIMessage` / `RegisterNUICallback` / `SetNuiFocus`
- **FiveM** : fx_version cerulean, game gta5

---

## Structure des fichiers

```
viper_ranked/
├── fxmanifest.lua
├── config.lua
├── positions.json          ← généré auto (spawns persistants)
├── server/
│   ├── main.lua            ← état global, DB, admin
│   ├── queue.lua           ← file d'attente, groupes, matchmaking
│   ├── match.lua           ← logique match (rounds, mort, fin)
│   └── shop.lua            ← boutique (rotation 2 semaines)
├── client/
│   ├── main.lua            ← NPC, menus, match events, HUD NUI
│   └── admin.lua           ← panel admin /rankedadmin
└── html/
    ├── index.html
    ├── style.css
    ├── script.js
    └── img/                ← 198 PNG d'armes (weapon_pistol.png, etc.)
```

---

## config.lua

```lua
Config = {}
Config.NPCModel          = 'mp_m_shopkeep_01'
Config.RoundsToWin       = 5
Config.RoundCountdown    = 3
Config.RoundDelay        = 2000
Config.InteractDistance  = 2.5
Config.AdminLicenses     = {
    'license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c',  -- Owner
}
Config.EloGain           = 25
Config.EloLoss           = 20
Config.CoinsPerWin       = 10
Config.ShopRotationDays  = 14
```

---

## Base de données (auto-créée au démarrage)

| Table | Description |
|---|---|
| `ranked_stats` | citizenid, name, wins, losses, elo (défaut 1000), matches, ranked_coins |
| `ranked_settings` | shop_rotation_id, shop_rotation_start |
| `ranked_shop` | id, item_name, item_label, item_type (weapon/item), price, rotation_id |
| `ranked_purchases` | id, citizenid, shop_item_id, purchased_at — UNIQUE(citizenid, shop_item_id) |

---

## État global serveur (server/main.lua)

```lua
Positions = {
    npc     = nil,
    ['1v1'] = { arenas = {} },   -- chaque arena : {team1={pos1,...}, team2={pos1,...}}
    ['2v2'] = { arenas = {} },
    ['3v3'] = { arenas = {} },
}
PlayerInMatch = {}   -- [src] = {matchId, team}
Matches       = {}   -- [matchId] = match object
```

**Migration automatique** : si `positions.json` contient l'ancien format plat `{team1={}, team2={}}`, il est migré vers `{arenas=[{team1,team2}]}` au chargement.

---

## Système d'arènes (NOUVEAU — implémenté en dernier)

### Principe
- Chaque mode (1v1/2v2/3v3) peut avoir **N arènes** configurées (l'admin en ajoute autant qu'il veut, minimum 5 recommandé)
- Au démarrage d'un match, une arène valide est **choisie aléatoirement**
- L'arène est stockée dans `match.arenaIdx` et réutilisée pour tous les rounds

### Événements serveur (admin)
| Event | Paramètres | Action |
|---|---|---|
| `viper_ranked:adminGetPositionsData` | — | Envoie toutes les arènes au client |
| `viper_ranked:adminSetNpcPos` | coords | Sauvegarde position PNJ |
| `viper_ranked:adminAddArena` | mode | Ajoute une arène vide |
| `viper_ranked:adminSetArenaSpawn` | mode, arenaIdx, side, playerIdx, coords | Sauvegarde un spawn |
| `viper_ranked:adminDeleteArena` | mode, arenaIdx | Supprime une arène |

### Événement client (retour)
- `viper_ranked:adminReceivePositionsData(data, npcCoords)` → reconstruit le menu positions

---

## Système de file et groupes (server/queue.lua)

- **1v1** : file directe, chaque joueur entre seul
- **2v2/3v3** : système de groupe par code (6 caractères A-Z0-9)
- Quand le groupe est complet → entrée automatique en file
- `CheckMatchmaking(mode)` : dès que 2 entrées dans la file → `StartMatch`
- `RemovePlayerFromQueue(src)` : fonction globale appelée aussi par `playerDropped`

---

## Logique de match (server/match.lua)

- **States** : `countdown` → `active` → `scoring` → `ended`
- **StartMatch** : choisit arène aléatoire, TP les joueurs, lance countdown
- **StartRound** : réinitialise alive[], TP les joueurs à la même arène
- **playerDied** : décrémente alive[], si team morte → score +1, prochain round ou fin
- **EndMatch** : `UpdatePlayerStats`, event `matchEnd` avec ELO+RC, TP au NPC
- **forfeit** : commande `/ff` côté client → event serveur → `EndMatch`

---

## Vérification d'arme obligatoire (✅ implémenté)

Le joueur doit avoir **uniquement** `weapon_pistol50` **ou** `weapon_pistol_mk2` dans son inventaire ox_inventory pour rejoindre la file ou un groupe.

- Vérifié côté serveur dans `joinQueue`, `createGroup` et `joinGroup` (server/queue.lua)
- Fonction `CheckWeaponLoadout(src)` : utilise `exports.ox_inventory:GetPlayerItems(src)`
- Ignore les items qui ne commencent **pas** par `weapon_` (munitions, food, etc. → OK)
- Bloque si : une arme non autorisée est présente OU aucune arme autorisée n'est dans l'inventaire
- `AllowedWeapons = { weapon_pistol50 = true, weapon_pistol_mk2 = true }`

---

## Boutique (server/shop.lua)

- Rotation de 14 jours (`Config.ShopRotationDays`)
- Articles avec `rotation_id` — un joueur ne peut acheter qu'une fois par article par rotation
- `SendShopPanel(src)` : fonction locale qui envoie les données live au client admin
- Reset de rotation : incrémente `shop_rotation_id`, réinitialise `shop_rotation_start`
- Achat via ox_inventory : `exports.ox_inventory:AddItem(src, item_name, 1)`
- `viper_ranked:refreshShop` : rafraîchit la boutique sans rouvrir le hub (pour mise à jour coins/onglet)

---

## Panel admin (/rankedadmin — client/admin.lua)

Menu principal → 6 sections :
1. **Positions** → menu dynamique (fetch serveur → arènes par mode)
   - PNJ : cliquer sur place = sauvegarde coords
   - 1V1/2V2/3V3 : liste des arènes → par arène : spawns J1/J2/J3 par équipe + supprimer
   - Ajouter une arène (bouton en haut de chaque mode)
2. **Boutique** → voir rotation, ajouter/modifier/supprimer articles, reset rotation
3. **Donner RC** → liste joueurs en ligne (nom + ID + solde), inputDialog montant
4. **Reset classement** → remet tout à 0 / 200 ELO (confirmation requise)
5. **Hologramme Classement** → définir position ou supprimer l'hologramme Top 3
6. **Rafraîchir PNJ** → resync coords à tous les clients

## Hologramme Top 3 (client/main.lua + server/main.lua)

- Position stockée dans `positions.json` → `Positions.holo = {x,y,z,w}`
- Render thread séparé : si `HoloPos` défini et joueur dans les 30m → DrawMarker pulsant au sol + 4 lignes de texte 3D
  - "TOP RANKED" (or/jaune)
  - "#1 Nom — ELO" (or)
  - "#2 Nom — ELO" (argent)
  - "#3 Nom — ELO" (bronze)
- `BroadcastHoloData()` : envoie `viper_ranked:syncHoloData` à tous les clients avec position + top 3 DB
- Mis à jour : à chaque fin de match (2s après UpdatePlayerStats) + broadcast périodique toutes les 60s
- Requête joueur à `onClientResourceStart` via `requestHoloData`

---

## NUI (html/)

- **Queue widget** (bas droite) : mode en cours + timer + `[X] Quitter la file`
  - Touche X via `RegisterKeyMapping` (Lua), pas de focus souris capturé
- **Score HUD** (haut centre) : nom équipes, scores, numéro de round
- **Countdown** : barre animée sous le HUD
- **Result overlay** : VICTOIRE/DÉFAITE + chip ELO + chip RC (si > 0)
- **Hub modal** : Leaderboard (top 20) + Boutique (grille d'articles avec images armes)
  - Images armes : `html/img/WEAPON_NAME.png` (198 fichiers copiés depuis Desktop)
  - Format nom fichier : `weapon_pistol.png`, `weapon_ak47.png`, etc. (majuscules → lowercase)

---

## Événements client → serveur (résumé)

| Event | Description |
|---|---|
| `viper_ranked:joinQueue` (mode) | Rejoindre file 1v1 |
| `viper_ranked:createGroup` (mode) | Créer groupe 2v2/3v3 |
| `viper_ranked:joinGroup` (code, mode) | Rejoindre groupe par code |
| `viper_ranked:leaveQueue` | Quitter file/groupe |
| `viper_ranked:playerDied` (matchId) | Signaler sa mort |
| `viper_ranked:forfeit` (matchId) | Abandon (/ff) |
| `viper_ranked:getLeaderboard` | Demander top 20 |
| `viper_ranked:getShop` | Demander boutique (ouvre hub) |
| `viper_ranked:refreshShop` | Rafraîchir boutique (hub déjà ouvert, onglet shop cliqué) |
| `viper_ranked:buyItem` (itemId) | Acheter un article |
| `viper_ranked:checkAdmin` | Ouvrir panel admin |

---

## Événements serveur → client (résumé)

| Event | Description |
|---|---|
| `viper_ranked:matchStart` (d) | TP + HUD + countdown |
| `viper_ranked:roundStart` (d) | TP + reset score |
| `viper_ranked:updateScore` (t1,t2,round) | Mise à jour HUD |
| `viper_ranked:matchEnd` (d) | Overlay résultat + TP NPC |
| `viper_ranked:queueJoined` (mode) | Afficher widget file |
| `viper_ranked:queueLeft` | Cacher widget file |
| `viper_ranked:groupCreated` (code,mode) | Afficher code groupe |
| `viper_ranked:groupJoined` | Notification rejoindre |
| `viper_ranked:groupFull` | Notification groupe complet |
| `viper_ranked:syncNPCCoords` (coords) | Spawner/déplacer PNJ |
| `viper_ranked:receiveLeaderboard` (rows) | Ouvrir hub leaderboard |
| `viper_ranked:receiveShop` (data) | Ouvrir hub boutique |
| `viper_ranked:updateShop` (data) | Rafraîchir boutique (hub déjà ouvert) |
| `viper_ranked:adminReceivePositionsData` (data,npc) | Reconstruire menu positions |
| `viper_ranked:adminReceiveShopPanel` (data) | Reconstruire menu boutique |
| `viper_ranked:adminReceiveOnlinePlayers` (list) | Menu give coins |

---

## Points importants / pièges

- `SendShopPanel` doit être déclarée **avant** les events qui l'appellent dans shop.lua
- `Queue`, `Groups`, `PlayerStatus` sont **locaux** à queue.lua — non accessibles depuis match.lua
- `PlayerInMatch` et `Matches` sont **globaux** (définis dans main.lua)
- L'admin check utilise `GetPlayerIdentifiers(src)` + `Config.AdminLicenses` (pas QBCore groups)
- La mort est détectée côté client (poll 300ms) — `DeadReported` empêche le double-report
- `SetNuiFocus(true,true)` pour hub, `false,false` pour fermer — ne pas oublier le NUI callback `closeHub`
- Résurrection dans `roundStart` : `NetworkResurrectLocalPlayer` si le ped est mort
- Images boutique : nom fichier = `item_name.toUpperCase().replace('WEAPON_','').toLowerCase()` → adapter si besoin

---

## Système d'arènes — périmètre (✅ implémenté)

- Chaque arène peut avoir un périmètre circulaire `{x, y, z, radius}`
- Défini en admin via preview live : marcher au centre → `[E]` pour ancrer → marcher au bord → `[E]` pour confirmer
- Admin : bouton TP par arène (vers center du périmètre ou premier spawn)
- En match : 36 DrawMarker bleus/rouges selon position, texte "HORS ZONE – Xs" à l'écran
- Si hors zone > 3s → `viper_ranked:boundaryViolation` → l'équipe adversaire gagne
- `BoundaryActive` = false pendant le countdown (évite faux positifs au TP)
- Admin: bouton `🏆 Reset du classement` → remet wins/losses/elo/matches/ranked_coins à 0 (ELO → 200)

---

## Groupe 2v2/3v3 — widget persistant (✅ implémenté)

- Créateur du groupe : widget queue widget en bas-droite avec code visible
- Membres qui rejoignent : widget mis à jour avec `n / max joueurs`
- Avant que le groupe soit complet : bouton X (keybind) fonctionne pour quitter
- `groupUpdate` event notifie tous les membres quand quelqu'un rejoint

---

## ELO / Stats

- ELO de départ : 200 (DEFAULT dans CREATE TABLE + migration ALTER TABLE)
- Gain : +15 par win (`Config.EloGain = 15`)
- Perte : -13 par loss (`Config.EloLoss = 13`)

---

## Anti-friendly fire (✅ implémenté)

- Actif uniquement en 2v2 et 3v3 (pas en 1v1)
- Thread `Wait(0)` dans `client/main.lua` : surveille `GetEntityHealth` à chaque frame
- Si la santé baisse → boucle sur `MyTeammates` → `HasEntityBeenDamagedByEntity(ped, tmPed, true)`
- Si un allié est responsable : `SetEntityHealth(ped, prevHealth)` + `ClearEntityLastDamageEntity`
- `MyTeammates` = liste des server IDs des coéquipiers, envoyée dans l'event `matchStart` via le champ `teammates`
- `CurrentMode` stocké au `matchStart`, remis à nil au `matchEnd`
- Inactif si joueur mort (`IsRzdead()` / `IsPedDeadOrDying`) — remet `prevHealth = 200`

---

## Désactivation auto-réanimation E en ranked (✅ implémenté)

Dans `viperpvp_redzone/client/main.lua` :
- Le `SetTimeout(30000, ...)` qui active `CanSelfRevive` vérifie `not LocalPlayer.state.inRankedMatch`
- Le thread de revive E (ligne ~800) vérifie aussi `not LocalPlayer.state.inRankedMatch`
- Le state bag `inRankedMatch` est positionné par `viper_ranked` au `matchStart` / `matchEnd`

---

## viper-hud — images armes ggcweapons (✅ implémenté)

- `client/main.lua` : table `GGCWeaponsByHash` — hash → spawn name pour 25 armes ggcweapons
- Fallback : si arme pas dans `QBCore.Shared.Weapons`, cherche dans `GGCWeaponsByHash`
- `html/script.js` : image en lowercase + fallback `nui://ggcweapons/images/{name}.png` si ox_inventory fail
- `[weapons]/ggcweapons/fxmanifest.lua` : ajout `'images/*.png'` dans `files{}`
- **Action requise** : copier les PNG de `[weapons]/ggcweapons/images/` vers `[ox]/ox_inventory/web/images/` pour éviter le fallback

---

## Tâches restantes

Rien de connu au moment de l'écriture — toutes les fonctionnalités demandées sont implémentées.
