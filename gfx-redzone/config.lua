Config = {
    Framework = "qb", -- "esx", "qb", "gfx-inventory"

    -- Licences autorisées à utiliser /rzzone (même liste que viper-hud)
    AdminLicenses = {
        'license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c',
    },
    ChangeZonesInterval = 20, -- minutes
    CombatModeTimer = 3, --seconds
    ZoneCount = 1,
    ZoneLocations = {
        {name = "BOUCHERIE",      coords = vector3(891.8,   -2216.9,  30.5),  radius = 215.0},
        {name = "BALLAS",         coords = vector3(53.9,    -1898.8,  21.6),  radius = 185.0},
        {name = "UNICORN",        coords = vector3(136.8,   -1305.9,  29.0),  radius = 210.0},
        {name = "WEAZEL NEWS",    coords = vector3(-603.4,  -865.5,   25.6),  radius = 170.0},
        {name = "LAS COLINAS",    coords = vector3(-1031.1, -1072.0,  4.0),   radius = 170.0},
        {name = "PLAGE",          coords = vector3(-1176.9, -1420.8,  4.5),   radius = 200.0},
        {name = "FETE FORAINE",   coords = vector3(-1637.8, -1060.2,  13.1),  radius = 190.0},
        {name = "LIFE INVADER",   coords = vector3(-1100.1, -275.3,   37.6),  radius = 230.0},
        {name = "PACIFIC BANK",   coords = vector3(263.0,   176.1,    104.7), radius = 180.0},
        {name = "PALETO",         coords = vector3(-120.8,  6211.7,   31.2),  radius = 230.0},
        {name = "MIRROR PARK",    coords = vector3(1179.2,  -456.0,   66.3),  radius = 200.0},
        {name = "CARGO",          coords = vector3(977.3,   -3080.9,  5.9),   radius = 180.0},
        {name = "SANDY SHORE",    coords = vector3(1619.9,  3646.3,   34.9),  radius = 200.0},
        {name = "CHANTIER",       coords = vector3(23.5,    -309.8,   46.5),  radius = 200.0},
        {name = "ARENA",          coords = vector3(-320.5,  -1970.1,  32.5),  radius = 200.0},
        {name = "POSTE POLICE",   coords = vector3(314.2,   -1052.3,  29.2),  radius = 250.0},
    },
    RewardOnFinish = {
        gfx_points    = false,
        giveAllItems  = true,
        money         = 50000,
        items         = {
            { name = "weapon_pistol50", count = 5, label = "Pistolet .50" },
        }
    },
    IdentifierType = "license", -- "steam", "license", "xbl", "live", "discord", "fivem"

    -- Zone où /r fonctionne immédiatement (sans attendre 30s)
    FastReviveZone = { x = 3753.28, y = 7404.95, z = 526.13, radius = 500.0 },

    -- Safezones — coords hardcodées, blips verts créés au démarrage sans dépendance externe
    SafeZoneLocations = {
        { coords = vector3(371.9,    -2129.9,  16.2), radius = 55.0,  name = "VAGOS" },
        { coords = vector3(-304.8,   -921.5,   31.0), radius = 40.0,  name = "PARKING CENTRAL" },
        { coords = vector3(-1145.0,  -744.6,   19.7), radius = 50.0,  name = "BINCO" },
        { coords = vector3(-1862.6,  -356.7,   49.2), radius = 50.0,  name = "HOPITAL" },
        { coords = vector3(138.9,    6603.9,   31.8), radius = 45.0,  name = "PALETO" },
        { coords = vector3(869.5,    -40.1,    78.7), radius = 60.0,  name = "CASINO" },
        { coords = vector3(1732.3,   3309.3,   41.2), radius = 40.0,  name = "SANDY SHORE" },
        { coords = vector3(-1304.0,  275.0,    64.0), radius = 80.0,  name = "ZONE PRINCIPALE" },
        { coords = vector3(-365.3,   -128.3,   38.6), radius = 60.0,  name = "LS CUSTOMS" },
    },
}

Locales = {
    ["zones_changed"] = "La zone Redzone a changé !",
    ["got_reward"]    = "Vous avez gagné %s %s pour avoir dominé la Redzone !",
    ["points"]        = "Points",
    ["money"]         = "Black Money"
}
