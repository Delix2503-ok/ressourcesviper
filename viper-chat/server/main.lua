-- Licenses qui obtiennent toujours le tag Admin, même s'ils ont un grade VIP
local AdminLicenses = {
    'license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c',
    'license:0d8ffc78a89c6052a1887611461a049cf010b3b6',
}

-- Ordre de priorité : le premier groupe trouvé l'emporte
local Tags = {
    { ace = 'viper.fondateur',   label = 'Fondateur',   color = { 255, 255, 255 } },
    { ace = 'group.responsable', label = 'Responsable', color = { 160, 32, 240  } },
    { ace = 'group.admin',       label = 'Admin',       color = { 255, 60,  60  } },
    { ace = 'group.modo',        label = 'Modérateur',  color = { 70,  130, 255 } },
    { ace = 'group.modo_test',   label = 'Modo-Test',   color = { 130, 180, 255 } },
    { ace = 'group.helper',      label = 'Helper',      color = { 50,  210, 100 } },
    { ace = 'group.vip_plus',    label = 'VIP+',        color = { 255, 215, 0   } },
    { ace = 'group.vip',         label = 'VIP',         color = { 200, 165, 0   } },
}

local AdminTag    = { label = 'Admin',  color = { 255, 60, 60  } }
local DefaultTag  = { label = 'Joueur', color = { 160, 160, 160 } }

local function IsAdminLicense(src)
    local ids = GetPlayerIdentifiers(src)
    for _, id in ipairs(ids) do
        for _, allowed in ipairs(AdminLicenses) do
            if id == allowed then return true end
        end
    end
    return false
end

local function GetTag(src)
    if IsAdminLicense(src) then return AdminTag end
    for _, t in ipairs(Tags) do
        if IsPlayerAceAllowed(src, t.ace) then
            return t
        end
    end
    return DefaultTag
end

AddEventHandler('chatMessage', function(source, name, message)
    if not source or source == 0 then return end
    CancelEvent()
    local tag = GetTag(source)
    TriggerClientEvent('chat:addMessage', -1, {
        color     = tag.color,
        multiline = true,
        args      = { '[' .. tag.label .. '] ' .. name, message },
    })
end)
