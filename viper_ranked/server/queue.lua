-- ─── Groupes et file d'attente ───────────────────────────────────────────────

local Groups = {}   -- [code] = { leader, members={}, mode, maxSize }
local Queue   = { ['1v1'] = {}, ['2v2'] = {}, ['3v3'] = {} }
local PlayerStatus = {}  -- [src] = { status='queue'|'group', mode, groupCode }

local ModeSize = { ['1v1'] = 1, ['2v2'] = 2, ['3v3'] = 3 }

local AllowedWeapons = { ['weapon_pistol50'] = true }

-- Vérifie le loadout via ox_inventory.
-- Règles : weapon_pistol50 obligatoire, aucune autre arme autorisée.
local function CheckWeaponLoadout(src)
    -- Récupérer les items de l'inventaire (pcall = pas de crash si l'API change)
    local items = nil
    local ok
    ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
    if not ok or not items then
        ok, items = pcall(function()
            local inv = exports.ox_inventory:GetInventory(src)
            return inv and inv.items
        end)
    end
    if not ok or not items then return true end  -- API introuvable → laisser passer

    local allowedCount = 0
    local otherWeapon  = nil

    for _, item in pairs(items) do
        local name = tostring(item.name):lower()
        if name:find('^weapon_') then
            if AllowedWeapons[name] then
                allowedCount = allowedCount + 1
            else
                otherWeapon = item.label or item.name
            end
        end
    end

    if otherWeapon then
        return false, 'Retire **' .. otherWeapon .. '** de ton inventaire.'
    end
    if allowedCount == 0 then
        return false, 'Tu dois avoir un **Cal .50** dans ton inventaire pour jouer en Ranked.'
    end
    return true
end

local function NotifyBadLoadout(src, reason)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = '🔫  Loadout invalide',
        description = reason,
        type        = 'error',
        duration    = 6000,
    })
end

local function GenerateCode()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local code  = ''
    for i = 1, 6 do
        local idx = math.random(1, #chars)
        code = code .. chars:sub(idx, idx)
    end
    if Groups[code] then return GenerateCode() end
    return code
end

-- Exposée pour main.lua (playerDropped)
function RemovePlayerFromQueue(src)
    local status = PlayerStatus[src]
    if not status then return end

    if status.status == 'queue' then
        local queue = Queue[status.mode]
        for i, entry in ipairs(queue) do
            for j, s in ipairs(entry.players) do
                if s == src then
                    if #entry.players == 1 then
                        table.remove(queue, i)
                    else
                        table.remove(entry.players, j)
                    end
                    break
                end
            end
        end

    elseif status.status == 'group' then
        local code  = status.groupCode
        local group = Groups[code]
        if group then
            for i, s in ipairs(group.members) do
                if s == src then table.remove(group.members, i); break end
            end
            if #group.members == 0 then
                Groups[code] = nil
            else
                if group.leader == src then group.leader = group.members[1] end
                for _, s in ipairs(group.members) do
                    TriggerClientEvent('ox_lib:notify', s, {
                        title       = 'Groupe',
                        description = GetPlayerName(src) .. ' a quitté le groupe.',
                        type        = 'warning',
                    })
                end
            end
        end
    end

    PlayerStatus[src] = nil
    TriggerClientEvent('viper_ranked:queueLeft', src)
end

-- ─── Rejoindre la file (1v1 direct, 2v2/3v3 via groupe) ─────────────────────
RegisterNetEvent('viper_ranked:joinQueue', function(mode)
    local src = source
    if PlayerStatus[src] or PlayerInMatch[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ranked', description = 'Tu es déjà en file ou en match!', type = 'error',
        })
        return
    end

    if mode ~= '1v1' then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Ranked',
            description = 'Utilise le système de groupe pour ' .. mode,
            type        = 'error',
        })
        return
    end

    local ok, reason = CheckWeaponLoadout(src)
    if not ok then NotifyBadLoadout(src, reason); return end

    PlayerStatus[src] = { status = 'queue', mode = mode }
    table.insert(Queue['1v1'], { players = { src } })
    TriggerClientEvent('viper_ranked:queueJoined', src, mode)
    CheckMatchmaking('1v1')
end)

-- ─── Créer un groupe ─────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:createGroup', function(mode)
    local src = source
    if PlayerStatus[src] or PlayerInMatch[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ranked', description = 'Tu es déjà en file ou en match!', type = 'error',
        })
        return
    end

    if not ModeSize[mode] or mode == '1v1' then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ranked', description = 'Mode invalide pour un groupe.', type = 'error',
        })
        return
    end

    local ok, reason = CheckWeaponLoadout(src)
    if not ok then NotifyBadLoadout(src, reason); return end

    local code = GenerateCode()
    Groups[code] = {
        leader  = src,
        members = { src },
        mode    = mode,
        maxSize = ModeSize[mode],
    }
    PlayerStatus[src] = { status = 'group', mode = mode, groupCode = code }
    TriggerClientEvent('viper_ranked:groupCreated', src, code, mode, ModeSize[mode])
end)

-- ─── Rejoindre un groupe par code ────────────────────────────────────────────
RegisterNetEvent('viper_ranked:joinGroup', function(code, mode)
    local src = source
    if PlayerStatus[src] or PlayerInMatch[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ranked', description = 'Tu es déjà en file ou en match!', type = 'error',
        })
        return
    end

    local okW, reasonW = CheckWeaponLoadout(src)
    if not okW then NotifyBadLoadout(src, reasonW); return end

    local group = Groups[code]
    if not group then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ranked', description = 'Code de groupe invalide!', type = 'error',
        })
        return
    end

    if group.mode ~= mode then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Ranked',
            description = 'Ce groupe est pour le mode ' .. group.mode .. '.',
            type        = 'error',
        })
        return
    end

    if #group.members >= group.maxSize then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Ranked', description = 'Le groupe est complet!', type = 'error',
        })
        return
    end

    table.insert(group.members, src)
    PlayerStatus[src] = { status = 'group', mode = mode, groupCode = code }

    -- Notifier les membres existants
    local joinerName = GetPlayerName(src)
    for _, s in ipairs(group.members) do
        if s ~= src then
            TriggerClientEvent('ox_lib:notify', s, {
                title       = 'Groupe',
                description = joinerName .. ' a rejoint le groupe! (' .. #group.members .. '/' .. group.maxSize .. ')',
                type        = 'info',
            })
            TriggerClientEvent('viper_ranked:groupUpdate', s, #group.members, group.maxSize)
        end
    end

    TriggerClientEvent('viper_ranked:groupJoined', src, code, mode, #group.members, group.maxSize)

    -- Groupe complet → mise en file
    if #group.members >= group.maxSize then
        local members = group.members
        Groups[code]  = nil
        for _, s in ipairs(members) do
            PlayerStatus[s] = { status = 'queue', mode = mode }
            TriggerClientEvent('viper_ranked:groupFull', s)
            TriggerClientEvent('viper_ranked:queueJoined', s, mode)
        end
        table.insert(Queue[mode], { players = members })
        CheckMatchmaking(mode)
    end
end)

-- ─── Quitter la file ─────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:leaveQueue', function()
    RemovePlayerFromQueue(source)
end)

-- ─── Restauration de groupe après match (2v2/3v3) ───────────────────────────
function RestoreGroup(players, mode)
    if mode == '1v1' or #players < 2 then return end
    local online = {}
    for _, s in ipairs(players) do
        if GetPlayerName(s) then table.insert(online, s) end
    end
    if #online < 2 then return end
    -- Remettre directement en file pour relancer le match automatiquement
    table.insert(Queue[mode], { players = online })
    for _, s in ipairs(online) do
        PlayerStatus[s] = { status = 'queue', mode = mode }
        TriggerClientEvent('viper_ranked:queueJoined', s, mode)
    end
    CheckMatchmaking(mode)
end

-- ─── Matchmaking ─────────────────────────────────────────────────────────────
function CheckMatchmaking(mode)
    local queue = Queue[mode]
    print('^5[viper_ranked] ^7Matchmaking ' .. mode .. ' — file : ' .. #queue .. ' entrée(s)')

    if #queue < 2 then return end

    local entry1 = table.remove(queue, 1)
    local entry2 = table.remove(queue, 1)

    -- Retirer du PlayerStatus avant de lancer le match
    for _, s in ipairs(entry1.players) do PlayerStatus[s] = nil end
    for _, s in ipairs(entry2.players) do PlayerStatus[s] = nil end

    print('^2[viper_ranked] ^7Match ' .. mode .. ' trouvé : '
        .. table.concat(entry1.players, ',') .. ' vs ' .. table.concat(entry2.players, ','))

    StartMatch(entry1.players, entry2.players, mode)
end
