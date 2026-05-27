# ressourcesviper — Serveur FiveM PVP (QBCore)

Serveur FiveM PVP-only basé sur QBCore. Pas de roleplay, pas de métiers actifs.

---

## Structure des dossiers

| Dossier | Contenu |
|---|---|
| `[qb]/` | Framework QBCore (core, multicharacter, smallresources…) |
| `[ox]/` | ox_inventory, ox_lib, ox_target |
| `[libs]/` | Librairies partagées |
| `[cars]/` | Véhicules custom streamés |
| `[clothes]/` | Vêtements custom |
| `[voice]/` | Système vocal |
| `[weapons]/` | Armes custom |
| `[standalone]/` | Resources indépendantes du framework |

---

## Resources custom Viper

| Resource | Rôle |
|---|---|
| `viperpvp_redzone` | Redzone/safezone, kills, leaderboard, TP NPC, revive |
| `viper-weapon-patches` | Dégâts custom par arme (damage/headshot/range) + désactivation drive-by |
| `vipergun` | Coffres/armes via PNJ avec spawn au sol |
| `vipercar` | Garage véhicules via PNJ |
| `viper-boutique` | Boutique V.I.P : garage véhicules custom + Atelier (paint/roues/vitres/néons) |
| `viper_ranked` | PvP ranked 1v1/2v2/3v3, ELO, arènes, boutique ranked |
| `vipersquad` | Système de squad : HUD HP/armor, blips, nametags, chat, anti-FF |
| `viper-hud` | HUD PVP + sons ambiants PNJ (mutable) |
| `viper-chat` | Chat custom |
| `viper-emote` | Emotes |
| `viper-id` | Carte d'identité |
| `viper-salary` | Système de salaire (grades VIP/Modo/Admin) |
| `viper-shop` | Boutique en jeu |
| `viper-blanchiment` | Blanchiment d'argent |
| `viper-coca` | Système coca |
| `vipermapping1` | Mapping custom |
| `viperlogs` | Logs serveur |
| `viperjail` | Système de prison |
| `viperloading` | Écran de chargement |
| `viperboost` | Boost de véhicule |
| `viperramp` | Rampes custom |
| `vipertpramp` | TP ramp |
| `viper_kit` | Kits de départ |
| `viper-dv` | Delete vehicle |
| `gfx-redzone` | Interface graphique redzone |
| `thug-killfeeds` | Killfeed |
| `illenium-appearance` | Apparence personnage (vêtements, coiffeur) |
| `ft_adminmenu` | Menu admin |
| `Rup-ReportMenu` | Système de reports joueurs |
| `xeroshieldv3` | Anti-cheat |

---

## Points critiques

### ox_inventory + qb-weapons = INCOMPATIBLE
Ne jamais activer `qb-weapons`. ox_inventory gère tout l'inventaire.

### Durabilité désactivée
ox_inventory modifié : durabilité bloquée à 100 — les armes ne se dégradent pas.

### Drive-by désactivé
`viper-weapon-patches/client/weapons.lua` : `SetPlayerCanDoDriveBy(false)` chaque frame.

### Mort / résurrection
`NetworkResurrectLocalPlayer` sur place puis `SetEntityCoords` — évite le crash "Pool Full, Size == 256".

### Spawn NPC (physique sol)
Ordre obligatoire : `CreatePed` → flags → `TaskStandStill` → boucle collision → snap sol → `FreezeEntityPosition` → `SetEntityCollision(false)` → boucle de maintien permanente.

---

## Base de données — tables principales

| Table | Resource |
|---|---|
| `redzone_stats` | viperpvp_redzone — kills/deaths par joueur |
| `redzone_safezones` | viperpvp_redzone — zones configurées |
| `redzone_tp_npcs` | viperpvp_redzone — NPCs de téléportation |
| `boutique_vehicles` | viper-boutique — catalogue véhicules |
| `boutique_owned` | viper-boutique — achats par citizenid |
| `boutique_vehicle_mods` | viper-boutique — mods sauvegardés |
| `boutique_custom_npcs` | viper-boutique — NPCs Atelier |

---

## Documentation détaillée

Voir `CLAUDE.md` à la racine et `viper_ranked/CLAUDE.md` pour l'architecture complète.
