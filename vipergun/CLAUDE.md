# CLAUDE.md — vipergun (Script Armes & Coffres)

## Stack
- **Serveur** : FiveM / QBCore, oxmysql (utilise `MySQL.execute` pour INSERT/UPDATE, `MySQL.query` pour SELECT, `MySQL.query.await` pour les CREATE TABLE)
- **Inventaire** : ox_inventory (stash via `exports.ox_inventory:RegisterStash`)
- **UI lib** : ox_lib (`lib.notify`, `lib.showTextUI`, `lib.hideTextUI`)
- **BDD** : MariaDB via oxmysql

## Architecture des fichiers

```
config.lua              — Toute la config (armes, coffres, accessoires, ComponentLabels)
client/
  weapons.lua           — Interception des dégâts (gameEventTriggered, args[4] = weapon hash)
  attachments.lua       — Menu F6 accessoires + refresh live toutes les 200ms
  ped.lua               — Spawn/freeze des PNJ coffres (SetEntityCollision + re-freeze 1s)
  coffres.lua           — UI menu coffres (ox_inventory stash)
  admin.lua             — Panel admin (/admingun) + TP vers PNJ
  movement.lua          — Bloque accroupissement (ClearPedTasks) + furtivité
  hitmarkers.lua        — Hitmarkers visuels
  quickdraw.lua         — Quickdraw system
server/
  weapons.lua           — Config armes en mémoire + broadcast clients
  coffres.lua           — Création tables BDD + gestion stashes
  admin.lua             — Sauvegarde armes, gestion PNJ, coffres joueurs
html/
  index.html            — NUI (admin panel + menu accessoires)
  css/style.css         — Thème noir/vert néon #39ff14
  js/app.js             — Logique NUI
  images/               — Images armes (WEAPON_XXX.png) + accessoires (at_xxx.png)
```

## Tables BDD
- `vipergun_coffres` — citizenid, coffre_count
- `vipergun_weapon_overrides` — weapon_name, body_damage, head_damage, range_val, enabled
- `vipergun_peds` — id AUTO_INCREMENT, model, x, y, z, heading
- `vipergun_ped_config` — ancienne table (remplacée par vipergun_peds)

## Points critiques connus

### Dégâts armes
- `gameEventTriggered` → `CEventNetworkEntityDamage` : **args[4]** = weapon hash (PAS args[5])
- Le système intercepte les dégâts côté VICTIME et les remplace par les valeurs custom
- Après save admin → `MySQL.execute` pour INSERT/UPDATE + broadcast `-1` immédiat
- Après chargement DB (`vipergun:dbReady`) → re-broadcast à tous les clients

### Snipers — overlay scope
- **Cause du bug** : ox_inventory appelle `GiveWeaponToPed` (sans scope) puis `SetCurrentPedWeapon`. GTA initialise l'overlay visuel du scope au moment de `SetCurrentPedWeapon` uniquement — ajouter le composant après n'a aucun effet visuel.
- **Fix** : `AddEventHandler('ox_inventory:currentWeapon', ...)` dans `client/attachments.lua` — donne le composant scope IMMÉDIATEMENT, puis force un cycle arme (`→ weapon_unarmed → sniper`, `true` = instantané) pour forcer GTA à réinitialiser le rendu avec le composant présent.
- **Garde-fou** : thread `Wait(500)` dans `client/weapons.lua` redonne le composant si retiré entre deux cycles.
- **Composants** : `weapon_sniperrifle/marksmanrifle/marksmanrifle_mk2 → COMPONENT_AT_SCOPE_LARGE`, `weapon_heavysniper/heavysniper_mk2 → COMPONENT_AT_SCOPE_MAX`
- **Hash** : normalisation `toUnsigned()` dans les deux fichiers (GetHashKey retourne signé, GetSelectedPedWeapon retourne non-signé)

### Accroupissement
- Bloqué via `DisableControlAction(0, 36)` + `DisableControlAction(0, 44)`
- Si `IsPedDucking` → `ClearPedTasks(ped)` (ClearPedSecondaryTask était insuffisant)

### PNJ Coffres
- `SetEntityCollision(ped, false, false)` — empêche d'être poussé
- `FreezeEntityPosition(ped, true)` re-appliqué toutes les 1 seconde dans un thread dédié
- Invincible + CanBeDamaged(false) + CanRagdoll(false)

### Menu accessoires F6
- Refresh live : boucle 300ms dans `client/attachments.lua` compare l'état réel des composants et pousse un `openAttachments` si changement détecté
- **Persistance session** : `SavedComponents[weaponName][componentName] = bool` mis à jour à chaque toggle — restauré via `restoreComponents()` à chaque changement d'arme
- Le scope sniper est géré séparément via l'event handler ox_inventory (pas via SavedComponents) afin de forcer le cycle de rendu

### Panel admin (/admingun)
- Onglet Armes : images WEAPON_XXX.png + dégâts corps/tête/portée/activé
- Onglet PNJ : bouton TP (se téléporte aux coordonnées du PNJ sélectionné)
- Onglet Coffres : modifier le nombre de coffres d'un joueur (4–8)

## Config accessoires
- `Config.ComponentLabels` dans config.lua → label, category, icon (FA)
- Mapping composant → image PNG dans app.js (`COMP_IMAGES` + `getCompImage()`)
- Images copiées depuis Desktop/images vers html/images/

## Commandes
- `/admingun` — ouvre le panel admin (vérifié par license dans Config.AdminLicenses)
- `F6` — menu accessoires arme en main

## Dépendances
`qb-core`, `ox_inventory`, `ox_lib`, `oxmysql`
