Config = {}

-- Licences Steam des administrateurs (même format que viper-blanchiment)
Config.AdminLicenses = {
    "license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c", -- Delix76 (Fondateur)
    "license:0d8ffc78a89c6052a1887611461a049cf010b3b6",  -- Pio (Admin)
}

-- Groupes QBCore qui ont aussi accès admin (optionnel)
Config.AdminGroups = { 'admin', 'god' }

-- Modèle du PNJ garage (modèle de base GTA V garanti — même que vipercar)
Config.GarageNpcModel = 'a_m_m_skater_01'

-- Modèle du PNJ atelier (mécanicien)
Config.CustomNpcModel = 'a_m_m_skater_01'

-- Groupes ACE vendables dans la boutique (mutuellement exclusifs)
-- L'achat d'un nouveau grade retire automatiquement tous les autres
Config.GradeGroups = {
    'group.vip',
    'group.vip_plus',
}

-- URL du store Tebex (affiché au clic sur le bouton "+" dans la boutique joueur)
Config.TebexUrl = 'https://viperpvp.tebex.io/'

-- Catégories affichées dans la boutique (ordre + icône)
Config.Categories = {
    { id = 'grades',    label = 'GRADES',    icon = '⭐' },
    { id = 'vehicules', label = 'VÉHICULES', icon = '🚗' },
    { id = 'armes',     label = 'ARMES',     icon = '🔫' },
    { id = 'autres',    label = 'AUTRES',    icon = '📦' },
}
