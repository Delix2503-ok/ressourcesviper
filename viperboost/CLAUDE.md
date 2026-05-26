# Speedboost - Two Hand Hold | Documentation de reprise

## Contexte

Script FiveM QBCore qui reproduit le **speedboost arme** de manière scriptée.
Le but : quand le joueur lâche la visée avec une arme à une main, le personnage garde
l'arme tenue à **deux mains, baissée, en position de combat** pendant 1.5s avant de
repasser à la tenue normale à une main.

---

## Comportement exact voulu

1. Joueur vise avec une arme à une main (pistolet, revolver, etc.)
2. Il lâche la visée
3. Pendant **1.5s** → le perso reste en position **deux mains sur l'arme, arme pointée vers le bas** (comme la position native de GTA en sortie de visée / combat idle deux mains)
4. Après 1.5s → repasse à la tenue normale à une main
5. Si le joueur **re-vise pendant le hold** → annulation instantanée, il vise normalement

---

## Ce qui a été essayé et pourquoi ça n'a pas marché

| Tentative | Problème |
|---|---|
| `TaskPlayAnim` avec `reaction@intimidation@1h` / `intro` | Anim trop courte, se coupe avant la durée |
| `TaskPlayAnim` avec `weapons@pistol@` / `walk_idle` | Arme baissée mais tenue à une main, pas deux |
| `SetPedKeepTask` + `SetPedCurrentWeaponVisible` | Arme baissée mais pas la bonne tenue deux mains |

---

## Solution retenue (version actuelle)

**`TaskAimGunAtCoord`** — native GTA qui force le ped à viser un point précis.
En lui donnant un point au sol **2m devant lui à la même hauteur** → le ped adopte
naturellement la position deux mains sur l'arme, arme baissée, prête à viser.

```lua
local pos     = GetEntityCoords(ped)
local heading = GetEntityHeading(ped)
local rad     = math.rad(heading)
local tx      = pos.x + (-math.sin(rad) * 2.0)
local ty      = pos.y + (math.cos(rad) * 2.0)
local tz      = pos.z -- même hauteur = arme baissée

TaskAimGunAtCoord(ped, tx, ty, tz, HOLD_DURATION, false, false)
```

---

## Fichiers

```
speedboost/
├── fxmanifest.lua     — manifest FiveM standard, charge uniquement client/main.lua
└── client/
    └── main.lua       — toute la logique, script client uniquement
```

---

## Paramètre modifiable

Dans `client/main.lua` ligne 8 :

```lua
local HOLD_DURATION = 1500 -- ms de tenue deux mains après visée
```

Exemples : `500` = 0.5s / `1000` = 1s / `1500` = 1.5s (défaut) / `2000` = 2s

---

## Armes concernées

Toutes les armes à une main : pistolets, revolvers, mêlée une main (couteau, batte, hachette, etc.)
Liste complète des hashes dans `client/main.lua` à partir de la ligne 11.

---

## Installation

```
resources/
└── speedboost/
    ├── fxmanifest.lua
    └── client/
        └── main.lua
```

Dans `server.cfg` :
```
ensure speedboost
```

---

## État actuel

- ✅ Détection lâcher de visée fonctionnelle
- ✅ Annulation si re-visée pendant le hold
- ⚠️ À tester en jeu : vérifier que `TaskAimGunAtCoord` donne bien la tenue deux mains baissée attendue visuellement
- ⚠️ Si le rendu visuel n'est pas bon → essayer de baisser le point Z (`tz = pos.z - 1.0`) pour forcer l'arme encore plus vers le bas
