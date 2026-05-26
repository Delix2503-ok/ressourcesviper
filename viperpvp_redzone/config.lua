Config = {}

-- Paramètres de jeu
Config.KillThreshold = 20        -- Kills pour changer de zone (modifiable dans le panel)
Config.MoneyReward   = 300       -- Argent sale par kill (modifiable dans le panel)
Config.ZoneWinReward = 15000     -- Récompense pour le gagnant de la zone (modifiable dans le panel)
Config.DefaultRadius = 150.0     -- Rayon par défaut en mètres

-- Type de compte argent sale QBCore ('black_money', 'cash', 'bank')
Config.MoneyAccount  = 'black_money'

-- Groupes autorisés à accéder au panel admin
Config.AdminGroups = { 'admin', 'superadmin', 'god', 'qbcore.admin' }

-- Admins directs par identifiant license (contourne le système ACE/QBCore)
Config.AdminLicenses = {
    'license:0d8ffc78a89c6052a1887611461a049cf010b3b6',
}

-- Loadout joueur — jusqu'à 5 slots (touches 1 à 5)
-- Laisser name = '' pour un slot vide
Config.WeaponSlots = {
    { name = 'WEAPON_HEAVYSNIPER_MK2',   ammo = 60  },  -- touche 1
    { name = 'WEAPON_PISTOL_MK2',        ammo = 250 },  -- touche 2
    { name = '',                         ammo = 0   },  -- touche 3 (vide)
    { name = '',                         ammo = 0   },  -- touche 4 (vide)
    { name = '',                         ammo = 0   },  -- touche 5 (vide)
}

-- Zones insérées en base si aucune zone n'existe
Config.DefaultZones = {
    { name = "Sandy Shores",  x = 1204.0,  y = -3228.0, z = 6.0,  radius = 150.0 },
    { name = "Fort Zancudo",  x = -2119.0, y = 3133.0,  z = 32.0, radius = 150.0 },
    { name = "Alamo Sea",     x = 866.0,   y = 3593.0,  z = 34.0, radius = 150.0 },
}

-- Messages affichés aux joueurs
Config.Locale = {
    kill_reward  = "+%s$ argent sale",
    zone_changed = "Nouvelle RedZone active : %s",
    entered_zone = "Vous entrez dans la RedZone : %s",
    left_zone    = "Vous avez quitté la RedZone",
    not_admin    = "Permission refusée.",
    zone_created = "Zone '%s' créée avec succès.",
    zone_deleted = "Zone '%s' supprimée.",
    zone_updated = "Zone '%s' mise à jour.",
}
