Config = {}

-- ─── Accès admin ──────────────────────────────────────────────────────────────
-- Ajoutez ici les licences des admins (format : "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
-- Trouvez votre licence avec : print(GetPlayerIdentifierByType(source, 'license')) côté serveur
Config.AdminLicences = {
    'license:0d8ffc78a89c6052a1887611461a049cf010b3b6',
    'license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c',
}

-- ─── PNJ ──────────────────────────────────────────────────────────────────────
Config.NpcModel = 'a_m_m_skater_01'  -- modèle de base GTA V garanti (tester d'abord)

-- ─── Véhicules disponibles ────────────────────────────────────────────────────
Config.Vehicles = {
    {
        label = 'BF400',
        model = 'bf400',
        icon  = 'fa-solid fa-motorcycle',
        desc  = 'Moto tout-terrain',
    },
    {
        label = 'Revolter',
        model = 'revolter',
        icon  = 'fa-solid fa-car',
        desc  = 'Voiture de sport électrique',
    },
}

-- ─── Interaction ──────────────────────────────────────────────────────────────
Config.InteractionDistance = 3.0   -- distance en mètres pour l'interaction [E]

-- ─── Hologramme ───────────────────────────────────────────────────────────────
Config.HologramColor = { r = 57, g = 255, b = 20 }  -- vert néon Viper
