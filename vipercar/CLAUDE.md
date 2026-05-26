# ViperCar — FiveM Resource

## Vue d'ensemble
Resource QBCore pour le serveur **Viper PVP**. Permet de spawner des PNJs statiques vendeurs de véhicules, gérés via un panel admin NUI.

## Stack technique
- Framework : **QBCore**
- Inventaire : ox_inventory (non utilisé directement mais présent)
- Base de données : **oxmysql**
- UI library : **ox_lib** (menus contextuels)
- Table SQL : `vipercar_npcs`

## Fonctionnalités
- `/admincar` — ouvre le panel admin (accès par licence dans config.lua)
- Panel NUI style Viper PVP (fond noir, vert néon `#39FF14`)
- PNJs immobiles, invincibles, impossibles à pousser (FreezeEntityPosition + SetEntityInvincible)
- Hologramme vert néon **"VÉHICULES"** animé (pulsation) au-dessus de chaque PNJ + anneau au sol
- Touche `[E]` près d'un PNJ → menu ox_lib → choix BF400 ou Revolter (gratuit)
- Véhicule spawné au point de spawn défini pour ce PNJ, joueur mis dedans automatiquement

## Accès admin
**Par licence** (pas par groupe QBCore). Configurer dans `config.lua` :
```lua
Config.AdminLicences = {
    "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}
```
Pour trouver sa licence : `print(GetPlayerIdentifierByType(source, 'license'))` côté serveur.

## Flow ajout PNJ (admin)
1. `/admincar` → panel s'ouvre
2. Clic "Ajouter un PNJ" → panel se ferme, mode placement
3. Marcher à la position du PNJ → `[E]` pour confirmer
4. Marcher au point de spawn des véhicules → `[E]` pour confirmer
5. PNJ créé en DB et broadcasté à tous les clients, panel se rouvre

## Structure fichiers
```
vipercar/
├── fxmanifest.lua
├── config.lua          ← modèles, licences admin, véhicules, couleurs
├── server/main.lua     ← SQL, vérif licence, events réseau
├── client/main.lua     ← spawn PNJs, hologramme, interaction, panel
└── html/               ← NUI admin (index.html, style.css, script.js)
```

## Couleurs Viper PVP
- Vert néon principal : `#39FF14`
- Fond : `#080808`
- Surfaces : `#111111` / `#181818`
- Rouge danger : `#ff3a3a`

## Véhicules configurés
- **BF400** (moto tout-terrain) — `bf400`
- **Revolter** (sport électrique) — `revolter`
Ajout de nouveaux véhicules : dans `Config.Vehicles` (config.lua).

## Installation
1. Copier le dossier `vipercar/` dans `resources/`
2. Ajouter `ensure vipercar` dans `server.cfg`
3. Ajouter la/les licence(s) admin dans `config.lua`
4. Démarrer le serveur — la table SQL est créée automatiquement
