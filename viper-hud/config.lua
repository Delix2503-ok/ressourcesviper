Config = {}

-- Licences FiveM autorisees a ouvrir /viperadmin
-- Format : 'license:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
-- Trouve ta licence dans txAdmin > Players > clique sur toi > Identifiers
Config.AdminLicenses = {
    'license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c',
}

Config.MaxArmorValue = 100  -- Valeur max armure (100 = standard GTA, peut aller jusqu'a 200 avec SetPedMaxArmour)

Config.Weather = {
    locked   = true,
    type     = 'EXTRASUNNY',
    hour     = 14,
    minute   = 0,
    blackout = false
}

Config.World = {
    noPeds      = true,
    noTraffic   = true,
    noBlips     = true,
    muteAmbient = true  -- Coupe sirenes/klaxons/moteurs des vehicules PNJ residuels
}

Config.Hunger = {
    disabled     = true,
    frozenValue  = 100
}

Config.HUD = {
    healthColor     = '#39FF14',
    armorColor      = '#00CFFF',
    bgColor         = 'rgba(0,0,0,0.55)',
    showLogo        = true
}

Config.SafeZone = {
    -- Coords de teleportation pour /safe
    -- Modifiable depuis le panel admin (/viperadmin > Serveur > SafeZone)
    x = -1298.48,
    y = 272.6,
    z = 64.14,
    h = 151.41
}
