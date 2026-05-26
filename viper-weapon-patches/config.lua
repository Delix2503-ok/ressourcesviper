Config = {}

-- ============================================================
-- SYSTÈME DE DÉGÂTS DES ARMES
-- damage      : dégâts dans le corps (en HP, max 200)
-- headDamage  : dégâts en tête (200 = one shot kill)
-- range       : portée effective en mètres (annule les dégâts au-delà)
-- enabled     : active/désactive la gestion custom de cette arme
-- ============================================================
Config.Weapons = {
    -- PISTOLETS
    ['weapon_snspistol'] = {
        damage = 15, headDamage = 200, range = 40.0, enabled = true,
    },
    ['weapon_pistol'] = {
        damage = 20, headDamage = 200, range = 50.0, enabled = true,
    },
    ['weapon_pistol_mk2'] = {
        damage = 13, headDamage = 200, range = 120.0, enabled = true,
    },
    ['weapon_combatpistol'] = {
        damage = 22, headDamage = 200, range = 50.0, enabled = true,
    },
    ['weapon_appistol'] = {
        damage = 18, headDamage = 200, range = 75.0, enabled = true,
    },
    ['weapon_heavypistol'] = {
        damage = 188, headDamage = 200, range = 70.0, enabled = true,
    },
    ['weapon_vintagepistol'] = {
        damage = 20, headDamage = 200, range = 45.0, enabled = true,
    },
    ['weapon_navyrevolver'] = {
        damage = 50, headDamage = 200, range = 60.0, enabled = true,
    },
    ['weapon_revolver'] = {
        damage = 45, headDamage = 200, range = 60.0, enabled = true,
    },
    ['weapon_revolver_mk2'] = {
        damage = 100, headDamage = 200, range = 65.0, enabled = true,
    },
    ['weapon_doubleaction'] = {
        damage = 13, headDamage = 200, range = 75.0, enabled = true,
    },
    ['weapon_ceramicpistol'] = {
        damage = 18, headDamage = 200, range = 40.0, enabled = true,
    },
    ['weapon_gadgetpistol'] = {
        damage = 22, headDamage = 200, range = 45.0, enabled = true,
    },
    ['weapon_pistol50'] = {
        damage = 17, headDamage = 200, range = 150.0, enabled = true,
    },
    
    ['weapon_g67'] = {
        damage = 25, headDamage = 200, range = 1000.0, enabled = true,
    },

    -- MITRAILLETTES (SMG)
    ['weapon_microsmg'] = {
        damage = 14, headDamage = 200, range = 140.0, enabled = true,
    },
    ['weapon_minismg'] = {
        damage = 14, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_smg'] = {
        damage = 18, headDamage = 200, range = 125.0, enabled = true,
    },
    ['weapon_smg_mk2'] = {
        damage = 20, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_assaultsmg'] = {
        damage = 20, headDamage = 200, range = 130.0, enabled = true,
    },
    ['weapon_combatpdw'] = {
        damage = 18, headDamage = 200, range = 120.0, enabled = true,
    },
    ['weapon_machinepistol'] = {
        damage = 14, headDamage = 200, range = 105.0, enabled = true,
    },

    -- FUSILS D'ASSAUT
    ['weapon_assaultrifle'] = {
        damage = 18, headDamage = 200, range = 100.0, enabled = true,
    },
    ['weapon_assaultrifle_mk2'] = {
        damage = 20, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_carbinerifle'] = {
        damage = 20, headDamage = 200, range = 100.0, enabled = true,
    },
    ['weapon_carbinerifle_mk2'] = {
        damage = 22, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_specialcarbine'] = {
        damage = 30, headDamage = 200, range = 100.0, enabled = true,
    },
    ['weapon_specialcarbine_mk2'] = {
        damage = 32, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_bullpuprifle'] = {
        damage = 28, headDamage = 200, range = 90.0, enabled = true,
    },
    ['weapon_bullpuprifle_mk2'] = {
        damage = 30, headDamage = 200, range = 100.0, enabled = true,
    },
    ['weapon_compactrifle'] = {
        damage = 26, headDamage = 200, range = 75.0, enabled = true,
    },
    ['weapon_militaryrifle'] = {
        damage = 34, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_heavyrifle'] = {
        damage = 38, headDamage = 200, range = 120.0, enabled = true,
    },

    -- FUSILS DE PRÉCISION / SNIPERS
    ['weapon_sniperrifle'] = {
        damage = 100, headDamage = 200, range = 500.0, enabled = true,
    },
    ['weapon_heavysniper'] = {
        damage = 120, headDamage = 200, range = 600.0, enabled = true,
    },
    ['weapon_heavysniper_mk2'] = {
        damage = 130, headDamage = 200, range = 700.0, enabled = true,
    },
    ['weapon_marksmanrifle'] = {
        damage = 70, headDamage = 200, range = 300.0, enabled = true,
    },
    ['weapon_marksmanrifle_mk2'] = {
        damage = 80, headDamage = 200, range = 350.0, enabled = true,
    },

    -- FUSILS À POMPE
    ['weapon_pumpshotgun'] = {
        damage = 30, headDamage = 200, range = 25.0, enabled = true,
    },
    ['weapon_pumpshotgun_mk2'] = {
        damage = 32, headDamage = 200, range = 28.0, enabled = true,
    },
    ['weapon_sawnoffshotgun'] = {
        damage = 32, headDamage = 200, range = 15.0, enabled = true,
    },
    ['weapon_bullpupshotgun'] = {
        damage = 28, headDamage = 200, range = 20.0, enabled = true,
    },
    ['weapon_heavyshotgun'] = {
        damage = 35, headDamage = 200, range = 20.0, enabled = true,
    },
    ['weapon_dbshotgun'] = {
        damage = 40, headDamage = 200, range = 18.0, enabled = true,
    },
    ['weapon_autoshotgun'] = {
        damage = 25, headDamage = 200, range = 22.0, enabled = true,
    },

    -- MITRAILLEUSES / LOURDES
    ['weapon_mg'] = {
        damage = 28, headDamage = 200, range = 120.0, enabled = true,
    },
    ['weapon_combatmg'] = {
        damage = 30, headDamage = 200, range = 130.0, enabled = true,
    },
    ['weapon_combatmg_mk2'] = {
        damage = 32, headDamage = 200, range = 140.0, enabled = true,
    },
    ['weapon_gusenberg'] = {
        damage = 22, headDamage = 200, range = 70.0, enabled = true,
    },

    -- ARMES CUSTOM [weapons] / ggcweapons
    ['weapon_glock20'] = {
        damage = 22, headDamage = 200, range = 50.0, enabled = true,
    },
    ['weapon_deagle'] = {
        damage = 40, headDamage = 200, range = 60.0, enabled = true,
    },
    ['weapon_karambit'] = {
        damage = 45, headDamage = 200, range = 2.0, enabled = true,
    },
    ['weapon_pmxfm'] = {
        damage = 16, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_ak47'] = {
        damage = 22, headDamage = 200, range = 100.0, enabled = true,
    },
    ['weapon_groza'] = {
        damage = 26, headDamage = 200, range = 90.0, enabled = true,
    },
    ['weapon_glock18c'] = {
        damage = 18, headDamage = 200, range = 45.0, enabled = true,
    },
    ['weapon_aks74'] = {
        damage = 20, headDamage = 200, range = 95.0, enabled = true,
    },
    ['weapon_ak74'] = {
        damage = 20, headDamage = 200, range = 100.0, enabled = true,
    },
    ['weapon_scarsc'] = {
        damage = 28, headDamage = 200, range = 110.0, enabled = true,
    },
    ['weapon_m4'] = {
        damage = 22, headDamage = 200, range = 100.0, enabled = true,
    },
    ['weapon_keyboard'] = {
        damage = 40, headDamage = 200, range = 2.0, enabled = true,
    },
}

-- ============================================================
-- HITMARKERS
-- ============================================================
Config.Hitmarkers = {
    enabled   = true,
    duration  = 1500,
    fontSize  = 0.45,
    headColor = { r = 255, g = 60,  b = 60,  a = 255 },
    bodyColor = { r = 255, g = 255, b = 255, a = 255 },
}
