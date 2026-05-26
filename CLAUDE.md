# Projet FiveM — Serveur PVP (QBCore)

Serveur FiveM PVP-only basé sur QBCore. Pas de roleplay, pas de métiers actifs. Les ressources sont dans `C:\Users\Admin\Documents\Projet FiveM\resources`.

---

## Architecture générale

| Ressource | Rôle |
|---|---|
| `[qb]/qb-core` | Framework principal QBCore |
| `[qb]/qb-multicharacter` | Création/sélection de personnage |
| `[qb]/qb-smallresources` | Utilitaires divers (HUD, consumables, vehiclepush) |
| `viperpvp_redzone` | Système PVP : redzone, safezone, kills, leaderboard, TP NPC |
| `viper-weapon-patches` | Override des dégâts d'armes (damage custom + headshot + range) + désactivation drive-by |
| `vipergun` | Coffres/armes via PNJ avec spawn au sol |
| `viper-boutique` | Boutique V.I.P : garage véhicules custom + Atelier V.I.P (paint/roues/vitres/néons) |
| `viper_ranked` | PvP ranked : 1v1/2v2/3v3, ELO, arènes, boutique ranked |
| `viper-squad` | Système de squad : HUD HP/armor, blips, nametags, chat, anti-FF |
| `[ox]/ox_inventory` | Inventaire (incompatible avec qb-weapons — ne pas activer qb-weapons) |

---

## Règles importantes

### ox_inventory + qb-weapons = INCOMPATIBLE
`qb-weapons` appelle `Player.Functions.SetInventory` que ox_inventory ne supporte pas → 6 erreurs au démarrage. **Ne jamais activer qb-weapons.** Les metas d'armes personnalisées sont dans `viper-weapon-patches/metas/`.

### Lua : `do return end` pas juste `return`
Dans un fichier Lua, `return` doit être le dernier statement du bloc. Pour désactiver un fichier entier tout en gardant le code lisible, utiliser `do return end` en ligne 1.

### FiveM hash signé/non-signé
`GetHashKey()` retourne un int64 signé (négatif si bit de poids fort = 1). Les fonctions natives FiveM attendent un uint32. Toujours normaliser avec :
```lua
local function toUnsigned(h)
    if h < 0 then return h + 4294967296 end
    return h
end
```
Les armes affectées : `weapon_pistol_mk2` (hash `0x99AAEB3B` → négatif en signé).

---

## viper-weapon-patches

### Fonctionnement
- Config dans `config.lua` : `damage`, `headDamage`, `range` par arme
- Client `client/weapons.lua` : monitoring de santé + `HasEntityBeenDamagedByWeapon` (plus fiable que `gameEventTriggered`)
- Metas dans `metas/` : fichiers `.meta` déclarés comme `WEAPONINFO_FILE_PATCH` dans `fxmanifest.lua`

### Armes configurées
- `weapon_pistol_mk2` : damage=5, headDamage=200, range=55.0
- `weapon_snspistol` : damage=15, headDamage=200, range=40.0
- + toutes les autres armes QBCore standard

### Ajouter une arme
1. Ajouter l'entrée dans `config.lua`
2. Si besoin d'un meta custom : créer `metas/weapon_xxx.meta` + déclarer dans `fxmanifest.lua`

### Drive-by désactivé (✅ implémenté)
- `client/weapons.lua` : thread `Wait(0)` → `SetPlayerCanDoDriveBy(PlayerId(), false)` à chaque frame
- Couvre **tous** les véhicules (base GTA V + custom) — les flags meta `.meta` ne fonctionnent que pour des véhicules spécifiques

---

## viperpvp_redzone

### Tables DB
- `redzone_stats` : `citizenid, player_name, kills_total, kills_month, deaths_total`
- `redzone_safezones` : `id, name, x, y, z, radius, active`
- `redzone_tp_npcs` : `id, name, x, y, z, heading` (colonne `name` ajoutée via ALTER TABLE migration)

### Système TP via NPC
- Les NPCs TP sont spawnés dans chaque safezone via le panel admin (`/rzadmin` → onglet NPC TP)
- Champ nom obligatoire dans le panel admin pour identifier les NPCs
- Quand le joueur presse E près d'un NPC → menu de sélection safezone
- **Destination = coords du NPC dans la safezone cible** (pas le centre de la zone)
- Algorithme : pour chaque safezone, cherche le TpNpc dont la distance au centre ≤ radius
- Fallback : centre de la safezone si aucun NPC trouvé
- Bouton TP admin dans le panel pour téléporter directement à un NPC

### Sync NPC TP — déduplication
- Serveur envoie `syncTpNpcs` uniquement via `requestSync` (PAS dans `playerJoining` → évite le double spawn)
- Client utilise `TpNpcSyncGen` (compteur de génération) pour annuler les threads de spawn obsolètes
- Déduplication par proximité (< 2m) côté client pour éviter les doublons résiduels

### Spawn NPC — physique sol (vipergun style)
Appliqué à vipercar ET viperpvp_redzone. Ordre obligatoire :
1. `CreatePed(...)` — collision ON par défaut
2. Appliquer flags (invincible, no ragdoll, etc.) — **sans** désactiver la collision
3. `TaskStandStill(ped, -1)`
4. Boucle `HasCollisionLoadedAroundEntity` (max 50×200ms)
5. Boucle snap : `GetGroundZFor_3dCoord(x, y, z+10, false)` — accepter seulement si `gz <= z + 1.0`
6. `FreezeEntityPosition(ped, true)`
7. `SetEntityCollision(ped, false, false)` — **après** le freeze (inverse = tombe dans le sol)
8. `TaskStandStill(ped, -1)` à nouveau
9. **Boucle de maintien permanente** dans un thread séparé : re-applique `FreezeEntityPosition` + `SetEntityCollision(false)` toutes les 100ms — GTA peut override le freeze sans ça

**NE PAS utiliser `RequestCollisionAtCoord`** — sature le pool de streaming (256 slots) et cause le crash "Pool Full" lors des téléportations/résurrections.

### Mort / résurrection — crash Pool Full
`NetworkResurrectLocalPlayer(x, y, z)` avec des coords distantes cause "Pool Full, Size == 256" car GTA tente de streamer la nouvelle zone en une seule native. Fix obligatoire :
```lua
local c = GetEntityCoords(ped)
NetworkResurrectLocalPlayer(c.x, c.y, c.z, heading, false, false)  -- sur place
Wait(200)
SetEntityCoords(ped, x, y, z, false, false, false, false)           -- TP ensuite
```

### Safezone — tir bloqué, visée autorisée
- `DisablePlayerFiring(pid, true)` + bloquer INPUT_ATTACK (24) et INPUT_ATTACK2 (257)
- INPUT_AIM (25) **non bloqué** — le joueur peut viser librement

### Portage (carry) — safezones et revive
- Impossible de porter dans une safezone : vérifié côté **client** (`InSafeZone`) ET **serveur** (distance aux zones en mémoire)
- Si portage actif lors de l'entrée en safezone → stop automatique + notification
- **Revive au bon endroit** : le joueur revivé se relève aux coords physiques actuelles (`GetEntityCoords(PlayerPedId())` après `IsBeingCarried = false`), pas aux coords de mort
- Bug résolu : `local Carriers = {}` doit être déclaré **avant** le handler `redzone:revive:attempt`, sinon `pairs(nil)` → crash Lua → le client ne reçoit jamais `redzone:revived`

### Exports qb-target désactivés
`AddGlobalPlayer` et `AddTargetBone` n'existent pas dans la version de qb-target installée → ces blocs sont commentés.

---

## qb-multicharacter

### Comportement modifié
- **0 personnage** → formulaire de création affiché directement (skip la sélection)
- **1 personnage** → spawn automatique sans afficher la sélection
- **2+ personnages** → comportement normal (écran de sélection)
- `Config.EnableDeleteButton = false` — les joueurs ne peuvent pas supprimer leur perso
- `Config.DefaultNumberOfCharacters = 1` — max 1 perso par joueur

### Spawn point
- `vector4(-1302.25, 265.1, 63.46, 183.25)` — défini dans `Config.DefaultSpawn` (config.lua) et dans le handler `spawnLastLocation` (client/main.lua)
- `apartments:GetOwnedApartment` callback retiré de `spawnLastLocation` — il n'existe pas sur ce serveur PVP (pas de qb-apartments) et causait un freeze de l'écran noir au reconnect

### Fichiers modifiés
- `client/main.lua` — callback `setupCharacters` (auto-spawn + message NUI `autoSpawn`) + handler `spawnLastLocation` simplifié
- `html/app.js` — flags `autoSpawned` et `autoShowCreation` pour contrôler l'affichage

---

## qb-smallresources

### Fichiers désactivés (do return end ligne 1)
- `client/hudcomponents.lua` — HUD natif GTA désactivé pour serveur PVP
- `client/consumables.lua` — consommables désactivés

### vehiclepush
Le bloc `AddTargetBone` commenté (qb-target incompatible).

### pvputils.lua (client) — comportements PVP globaux
- **Zéro spawn ambiant** : thread `Wait(0)` → `SetPedDensityMultiplierThisFrame(0.0)` + `SetVehicleDensityMultiplierThisFrame(0.0)` etc. chaque frame
- **Nettoyage entités résiduelles** : boucle `Wait(1000)` → supprime peds `popType 1-3` + leur véhicule associé (avec check joueur) + `DeleteAllTrains()` + suppression hélicos/avions ambiants (class 15/16 sans joueur). Les trains ignorent le density=0 et doivent être supprimés explicitement.
- **Anti-collision véhicule** : `SetEntityNoCollisionEntity(ped, veh, true)` et `SetEntityNoCollisionEntity(myVeh, otherVeh, true)` à **chaque frame** (Wait(0)). `thisFrame=true` OBLIGATOIRE — le flag permanent (`false`) est overridé par le réseau GTA dès la frame suivante
- **Anti-ragdoll + crash protection** : `SetPedCanRagdoll(false)` etc. chaque frame + `SetEntityProofs(ped, false, true, true, true, false, ...)` — `fireProof+explosionProof+collisionProof=true`, `bulletProof=false` → seules les balles joueurs font des dégâts
- **Zéro dégâts de chute** : `SetEntityInvincible(true)` + `SetEntityCanBeDamaged(false)` pendant la chute, retiré 300ms après l'atterrissage
- **Filet de sécurité mort crash** : thread `Wait(0)` → si `IsEntityDead(ped)` et aucun joueur ne nous a tiré dessus (`HasEntityBeenDamagedByEntity`), `NetworkResurrectLocalPlayer` sur place immédiatement

---

## vipercar (garage)

### PNJ garage
- Spawn avec la même physique que vipergun (voir "Spawn NPC — physique sol" dans viperpvp_redzone)
- Guard `NPCSpawning[npc.id]` pour éviter les spawns en double lors du `LoadNPCs`
- Modèle : `s_m_y_airworker`

---

## vipergun (coffres/armes)

### PNJ coffres
- Spawn via `GetGroundZFor_3dCoord(x, y, z+10, false)` avec vérification `gz <= z + 1.0`
- **Référence de physique** — c'est cet approach qui est copié dans vipercar et viperpvp_redzone
- Interaction via touche E + `lib.showTextUI`

---

## ox_inventory — durabilité désactivée

- `client.lua` : condition `durability <= 0` retirée du bloc `DisablePlayerFiring` → armes jamais bloquées par durabilité
- `client.lua` : décrémentation `currentWeapon.metadata.durability - durabilityDrain * ...` supprimée → la valeur reste à 100 en session
- `modules/inventory/server.lua` (fonction `updateWeapon`) : décrémentation serveur retirée pour action `ammo` et `melee` → la valeur en DB reste à 100
- **Exception préservée** : WEAPON_FIREEXTINGUISHER / WEAPON_PETROLCAN / WEAPON_HAZARDCAN / WEAPON_FERTILIZERCAN gardent leur logique (durability = ammo restant, fonctionnel)
- Valeur initiale `metadata.durability = 100` conservée (pas de régression sur items existants)

---

## illenium-appearance

### Modifications
- `client/target/target.lua` — label `'DRESSING'` (majuscules) dans le ciblage du PNJ vêtements
- `client/client.lua` — option "Coiffeur" ajoutée dans le menu clothing (OpenMenu type=outfit) → appelle `OpenBarberShop` via event
- `client/common.lua` — `OpenBarberShop` : `isPedMenu=true` (pas de vérification de prix)
- `shared/config.lua` — blip coiffeur masqué (`Show = false`)

---

## Salaire (pas encore implémenté)

### Plan prévu
- Désactiver le salaire `unemployed` par défaut (mettre `payment = 0` dans `qb-core/shared/jobs.lua`)
- Ajouter des grades à `unemployed` : VIP=grade1, VIP+=grade2, Modérateur=grade3, Admin=grade4
- Commande `/setrank [id] [grade]` pour attribuer
- Timer : `QBConfig.Money.PayCheckTimeOut` dans `qb-core/config.lua` (actuellement 10 min)

---

## viper-boutique

### Rôle
Boutique V.I.P : garage de véhicules personnalisés + atelier de customisation (peinture, roues, vitres, néons).

### Tables DB
- `boutique_vehicles` : liste des véhicules disponibles (model, label, price, category)
- `boutique_owned` : véhicules achetés par citizenid
- `boutique_vehicle_mods` : sauvegarde des modifs par (citizenid, vehicle_model) — persist entre spawns
- `boutique_custom_npcs` : NPCs Atelier placés en admin (id, name, x, y, z, heading)

### Customisation véhicule (Atelier V.I.P)
- **Avant tout mod** : `SetVehicleModKit(veh, 0)` obligatoire (sinon vitres/couleurs ne s'appliquent pas)
- Peinture : `SetVehicleColours` + `SetVehiclePearlescentColour`
- Roues : `SetVehicleWheelType` + `SetVehicleMod(veh, 23, idx, false)`
- Vitres : `SetVehicleWindowTint`
- Néons : `SetVehicleNeonLightsEnabled` + `SetVehicleNeonEnabled` + couleur RGB
- Tout changement → `SaveCurrentMods()` → `TriggerServerEvent('boutique:saveVehicleMods', ...)`
- Mods chargés au spawn via `boutique:doSpawnVehicle` (server fetch DB → passe mods au client)

### Hologrammes NPC
- Style identique à vipergun : texte vert fixe `(57,255,20,230)`, FOV-scaled, `DrawMarker 28` pulsant
- Garage NPC : `'GARAGE V.I.P'` (pas de nom affiché)
- Atelier NPC : `'ATELIER V.I.P'` (pas de nom affiché)

### Sidebar customisation
- `#custom-panel` placé **hors** du `#root` div — `position: fixed; left: 0; width: 290px; height: 100vh`
- Pas de backdrop/overlay — le joueur voit son véhicule pendant la customisation
- Animation `slideInLeft` à l'ouverture

---

## viper_ranked

Voir [viper_ranked/CLAUDE.md](viper_ranked/CLAUDE.md) pour le détail complet.

### Points cross-ressources
- State bag `LocalPlayer.state.inRankedMatch` positionné par `viper_ranked` au `matchStart`/`matchEnd`
- `viperpvp_redzone` lit ce state bag pour bloquer le revive automatique E en ranked
- Anti-friendly fire 2v2/3v3 : thread client `Wait(0)` + `HasEntityBeenDamagedByEntity`

---

## viper-hud — sons ambiants PNJ

### Système de mute (`Config.World.muteAmbient = true` par défaut)
- Thread toutes les 2s : `SetAudioFlag('WantedMusicDisabled')` + `SetAudioFlag('PoliceScannerDisabled')` + `SetAudioFlag('DisableFlightMusic')` + `SetVehicleEngineOn(false)` sur tous les véhicules sans joueur
- `SetAmbientZoneStatePersistent(zone, false, true)` au démarrage sur une liste de zones (musique de quartier, bars, clubs)
- Toggle `/rzadmin` → onglet **⚙ Monde** → bouton "Sons PNJ" → broadcast `viper-hud:client:updateConfig('ambient', bool)` via `redzone:admin:toggleAmbientSounds`
- **Actif par défaut** (config.lua) — revient à "coupé" après chaque reboot serveur
- Véhicules joueurs non affectés (check `hasPlayer` avant mute moteur)

### Nettoyage entités sonores (pvputils.lua)
- Trains supprimés : `DeleteAllTrains()` toutes les secondes
- Véhicules NPC supprimés avec leur ped (stop klaxon/sirène)
- Hélicos/avions ambiants supprimés (class 15/16 sans joueur)

---

## viperpvp_redzone — fonctionnalités supplémentaires

### /safe bloqué en redzone active
- Serveur : export `IsPlayerInActiveRedzone(src)` vérifie coords du joueur vs zone active
- `viper-hud/server/main.lua` : handler `/safe` appelle l'export avec pcall (viperpvp_redzone doit être en premier dans server.cfg)
- Client : event `viperpvp_redzone:zoneChanged` (local) → variable `InRedzone` dans viper-hud → annule la barre de progression si joueur entre en zone pendant le cast

### Carry (/porter) bloqué en ranked
- `redzone:carry:start` serveur : check `exports['viper_ranked']:IsPlayerInMatch(src)` avant d'autoriser
- Client : `/porter` command + handlers `doCarry` et `attachSelf` vérifient `exports['viper_ranked']:IsInRankedMatch()`

### Loot (ox_inventory canSteal)
- ox_inventory pose `canSteal=true` automatiquement sur les peds en animation `dead_a` → bypass le système /loot
- Fix : dans le thread IsDead, forcer `LocalPlayer.state:set('canSteal', false, true)` chaque frame

---

## Erreurs connues / non résolues

- `ox_lib/init.lua:89` — `isContextOpen` export manquant : version mismatch interne à ox_lib, nécessite une mise à jour d'ox_lib
