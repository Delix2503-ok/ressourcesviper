# ViperPVP RedZone — Contexte du projet

## Stack
- FiveM resource, QBCore framework
- oxmysql (`@oxmysql/lib/MySQL.lua`) pour la base de données
- ox_inventory pour les items (argent sale = item, pas compte QBCore)
- qb-target pour le ciblage de joueurs
- Lua 5.4 (`lua54 'yes'`)
- NUI (HTML/CSS/JS) pour les panels UI

## Fichiers principaux
- `config.lua` — config partagée (zones, récompenses, armes, licences admin)
- `server/main.lua` — toute la logique serveur
- `client/main.lua` — toute la logique client
- `html/index.html` + `html/style.css` + `html/script.js` — panel NUI
- `fxmanifest.lua` — manifest resource

## Tables DB
- `redzone_zones` — zones PVP (id, name, x, y, z, radius, active, kill_count, kill_threshold, money_reward, win_reward)
- `redzone_safezones` — safe zones (id, name, x, y, z, radius, active)
- `redzone_stats` — leaderboard (citizenid, player_name, kills_total, kills_month, deaths_total)
- `redzone_tp_npcs` — NPC de téléportation (id, x, y, z, heading)

## Patterns importants
- **Argent sale** : `exports['ox_inventory']:AddItem(src, 'black_money', amount)` — PAS `player.Functions.AddMoney`
- **Check admin** : `IsAdmin(src)` — vérifie `Config.AdminLicenses` (strings de licence) ET `Config.AdminGroups`
- **NUI → Lua** : `RegisterNUICallback('xxx', function(data, cb) ... cb({}) end)` + `nuiFetch('xxx', data)` côté JS
- **Lua → NUI** : `SendNUIMessage({ type = 'xxx', ... })` dans client + `window.addEventListener('message', ...)` dans JS
- **Sync serveur** : snapshot envoyé via `TriggerClientEvent`, clients reçoivent et mettent à jour l'état local
- **Nettoyage monde** : uniquement les entités avec `GetEntityPopulationType` 1-3 (ambient) — JAMAIS 4+ (mission/resources comme ox_inventory)

## Onglets du panel admin
- **RedZones** — créer/modifier/supprimer/activer zones PVP
- **SafeZones** — créer/modifier/supprimer/toggle safe zones
- **NPC TP** — spawner/supprimer des NPC TP (invincibles, figés, texte "TP" en hologramme, touche E → liste safezones pour TP)
- **Leaderboard** — voir/supprimer/reset les stats joueurs

## Système carry (porter)
- **F** = porter / poser
- Côté porteur : reçoit `redzone:carry:doCarry`, serveur track dans `Carriers[src] = targetId`
- Côté cible : `redzone:carry:attachSelf` — thread avec `SetEntityCoordsNoOffset` à chaque frame + copie velocité porteur
- Utiliser `GetPlayerPed(carrierLocalId)` (jamais `NetworkGetEntityFromNetId` — coords ne se mettent pas à jour)
- **X** = se libérer du porteur (si vivant), déclenche `redzone:carry:escape`
- Mort = ne peut pas se libérer avec X

## Système mort / coma
- IsDead = coma jusqu'à 15 min
- **G** = /revive (5s animation CPR, validation serveur sur position)
- Après 30s : **E** disponible pour auto-relèvement vers la safezone la plus proche
- State bag `Player(pid).state.rzDead` pour détecter mort côté autres clients
- **En ranked** : auto-relèvement E complètement désactivé — le `SetTimeout(30000, ...)` et le thread de revive vérifient `not LocalPlayer.state.inRankedMatch` avant d'activer `CanSelfRevive`

## Nettoyage monde
- Vehicles + peds AMBIENT (popType 1-3) supprimés toutes les secondes
- Entités mission (popType 4+) préservées — OBLIGATOIRE pour les NPCs ox_inventory (shops, stash)
