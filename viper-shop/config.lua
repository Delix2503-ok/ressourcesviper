Config = {}

Config.AdminLicenses = {
    "license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c",
    "license:0d8ffc78a89c6052a1887611461a049cf010b3b6",
}

Config.Shops = {
    weapons = {
        label     = "Vendeur d'Armes",
        model     = 'g_m_y_lost_01',
        holoText  = 'ARMES',
        holoColor = { r = 57,  g = 255, b = 20  },  -- vert
        blipColor = 2,
    },
    ammo = {
        label     = 'Vendeur de Munitions',
        model     = 's_m_y_dealer_01',
        holoText  = 'MUNITIONS',
        holoColor = { r = 0,   g = 207, b = 255 },  -- cyan
        blipColor = 3,
    },
    illegal = {
        label     = 'Marchand Illégal',
        model     = 'g_m_y_lost_02',
        holoText  = 'MARCHAND ILLÉGAL',
        holoColor = { r = 255, g = 50,  b = 50  },  -- rouge
        blipColor = 1,
    },
}

Config.InteractDist = 2.5
Config.HoloDist     = 20.0
