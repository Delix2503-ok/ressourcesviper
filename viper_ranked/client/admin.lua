-- ═══════════════════════════════════════════════════════════════
--  ADMIN — VIPER RANKED
--  /rankedadmin → menu principal → sous-menus séparés
-- ═══════════════════════════════════════════════════════════════

local function GetCoords()
    local ped = PlayerPedId()
    local c   = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
end

local ModeSize = { ['1v1'] = 1, ['2v2'] = 2, ['3v3'] = 3 }

local BoundaryPreviewCenter = nil   -- {x,y,z,w} centre fixé par l'admin
local BoundaryPreviewArena  = nil   -- {mode, arenaIdx} arène en cours de config
local BoundaryTextUIShown   = false

-- ─── Menu principal ───────────────────────────────────────────
RegisterNetEvent('viper_ranked:openAdminMenu', function()
    lib.registerContext({
        id      = 'ranked_admin_main',
        title   = '⚙️  ADMIN — VIPER RANKED',
        options = {
            {
                title       = '📍  Gestion des positions',
                description = 'Spawns PNJ · 1V1 · 2V2 · 3V3',
                arrow       = true,
                onSelect    = OpenPositionsMenu,
            },
            {
                title       = '🛒  Gestion de la boutique',
                description = 'Articles · Prix · Reset rotation',
                arrow       = true,
                onSelect    = function()
                    TriggerServerEvent('viper_ranked:adminGetShopPanel')
                end,
            },
            {
                title       = '🪙  Donner des RankedCoins',
                description = 'Créditer un joueur en ligne',
                arrow       = true,
                onSelect    = function()
                    TriggerServerEvent('viper_ranked:adminGetOnlinePlayers')
                end,
            },
            {
                title       = '🏆  Reset du classement',
                description = 'Remet tous les joueurs à 200 ELO — irréversible',
                onSelect    = function()
                    CreateThread(function()
                        local r = lib.alertDialog({
                            header   = '⚠️  Réinitialiser le classement ?',
                            content  = 'Tous les joueurs seront remis à **200 ELO**.\nVictoires, défaites, matchs et coins seront remis à zéro.\n\n**Cette action est irréversible.**',
                            centered = true,
                            cancel   = true,
                            labels   = { confirm = 'Réinitialiser', cancel = 'Annuler' },
                        })
                        if r == 'confirm' then
                            TriggerServerEvent('viper_ranked:adminResetLeaderboard')
                        end
                    end)
                end,
            },
            {
                title       = '📺  Hologramme Classement',
                description = 'Définir / supprimer l\'affichage Top 3 en jeu',
                arrow       = true,
                onSelect    = OpenHoloMenu,
            },
            {
                title       = '🔄  Rafraîchir le PNJ',
                description = 'Respawn le PNJ à sa position enregistrée',
                onSelect    = function()
                    TriggerServerEvent('viper_ranked:refreshNPC')
                end,
            },
        },
    })
    lib.showContext('ranked_admin_main')
end)

-- ─── Sous-menu : hologramme Top 3 ────────────────────────────
function OpenHoloMenu()
    lib.registerContext({
        id      = 'ranked_admin_holo',
        title   = '📺  HOLOGRAMME TOP 3',
        menu    = 'ranked_admin_main',
        options = {
            {
                title       = '📍  Définir ici',
                description = 'Place l\'hologramme à ta position actuelle',
                onSelect    = function()
                    TriggerServerEvent('viper_ranked:adminSetHoloPos', GetCoords())
                end,
            },
            {
                title       = '🗑️  Supprimer',
                description = 'Retire l\'hologramme du monde',
                onSelect    = function()
                    CreateThread(function()
                        local r = lib.alertDialog({
                            header  = 'Supprimer l\'hologramme ?',
                            content = 'L\'affichage Top 3 sera retiré pour tous les joueurs.',
                            centered = true, cancel = true,
                            labels  = { confirm = 'Supprimer', cancel = 'Annuler' },
                        })
                        if r == 'confirm' then
                            TriggerServerEvent('viper_ranked:adminDeleteHoloPos')
                        end
                    end)
                end,
            },
        },
    })
    lib.showContext('ranked_admin_holo')
end

-- ─── Sous-menu : Positions (dynamique) ───────────────────────
function OpenPositionsMenu()
    TriggerServerEvent('viper_ranked:adminGetPositionsData')
end

RegisterNetEvent('viper_ranked:adminReceivePositionsData', function(data, npcCoords)
    local opts = {
        {
            title       = 'PNJ — Position' .. (npcCoords and ' ✅' or ' ⚠️'),
            description = npcCoords
                and ('x=' .. math.floor(npcCoords.x) .. '  y=' .. math.floor(npcCoords.y) .. '  — Clique pour mettre à jour')
                or 'Non configuré — Place-toi à l\'endroit voulu et clique',
            onSelect = function()
                TriggerServerEvent('viper_ranked:adminSetNpcPos', GetCoords())
            end,
        },
        { title = '────────────────', disabled = true },
    }

    for _, mode in ipairs({'1v1', '2v2', '3v3'}) do
        local arenas    = data[mode] or {}
        local playerCnt = ModeSize[mode]
        local ready     = 0
        for _, arena in ipairs(arenas) do
            local n1, n2 = 0, 0
            if arena.team1 then for _ in pairs(arena.team1) do n1 = n1 + 1 end end
            if arena.team2 then for _ in pairs(arena.team2) do n2 = n2 + 1 end end
            if n1 >= 1 and n2 >= 1 then ready = ready + 1 end
        end
        table.insert(opts, {
            title       = '⚔️  ' .. mode:upper() .. '  —  ' .. #arenas .. ' arène(s)  (' .. ready .. ' valide(s))',
            description = ready == 0 and '⚠️ Aucune arène prête — ajoutes-en une' or '✅ ' .. ready .. ' arène(s) utilisable(s) en match',
            arrow       = true,
            onSelect    = function()
                OpenModeArenaMenu(mode, arenas, playerCnt)
            end,
        })
    end

    lib.registerContext({
        id      = 'ranked_admin_positions',
        title   = '📍  POSITIONS',
        menu    = 'ranked_admin_main',
        options = opts,
    })
    lib.showContext('ranked_admin_positions')
end)

-- ─── Sous-menu : Arènes d'un mode ─────────────────────────────
function OpenModeArenaMenu(mode, arenas, playerCnt)
    local opts = {
        {
            title       = '➕  Ajouter une arène',
            description = 'Crée une nouvelle arène vide pour ' .. mode:upper(),
            onSelect    = function()
                TriggerServerEvent('viper_ranked:adminAddArena', mode)
            end,
        },
    }

    if #arenas == 0 then
        table.insert(opts, { title = 'Aucune arène — clique sur Ajouter', disabled = true })
    else
        table.insert(opts, { title = '────────────────', disabled = true })
        for i, arena in ipairs(arenas) do
            local n1, n2 = 0, 0
            if arena.team1 then for _ in pairs(arena.team1) do n1 = n1 + 1 end end
            if arena.team2 then for _ in pairs(arena.team2) do n2 = n2 + 1 end end
            local valid  = n1 >= 1 and n2 >= 1
            local status = valid and '✅' or '⚠️'
            local bicon  = arena.boundary and ' 🔵' or ''
            local bdesc  = arena.boundary and ('  ·  Rayon : ' .. math.floor(arena.boundary.radius) .. 'm') or '  ·  Pas de périmètre'
            table.insert(opts, {
                title       = status .. '  Arène #' .. i .. bicon,
                description = 'Éq.1 : ' .. n1 .. '/' .. playerCnt .. '  ·  Éq.2 : ' .. n2 .. '/' .. playerCnt .. bdesc,
                arrow       = true,
                onSelect    = function()
                    OpenArenaMenu(mode, i, arena, playerCnt)
                end,
            })
        end
    end

    lib.registerContext({
        id      = 'ranked_admin_mode_arenas',
        title   = '⚔️  ' .. mode:upper() .. ' — ARÈNES',
        menu    = 'ranked_admin_positions',
        options = opts,
    })
    lib.showContext('ranked_admin_mode_arenas')
end

-- ─── Sous-menu : Spawns d'une arène ───────────────────────────
function OpenArenaMenu(mode, arenaIdx, arena, playerCnt)
    local opts = {}

    -- Téléportation vers l'arène
    local tpDest = nil
    if arena.boundary then
        tpDest = arena.boundary
    elseif arena.team1 and arena.team1[1] then
        tpDest = arena.team1[1]
    elseif arena.team2 and arena.team2[1] then
        tpDest = arena.team2[1]
    end
    table.insert(opts, {
        title       = '🚀  Se téléporter ici',
        description = tpDest
            and ('x=' .. math.floor(tpDest.x) .. '  y=' .. math.floor(tpDest.y) .. '  z=' .. math.floor(tpDest.z))
            or  'Aucune position configurée pour cette arène',
        disabled    = tpDest == nil,
        onSelect    = tpDest and function()
            SetEntityCoords(PlayerPedId(), tpDest.x, tpDest.y, tpDest.z + 1.0, false, false, false, false)
            lib.notify({ title='🚀 Arène #' .. arenaIdx, description=mode:upper() .. ' — TP effectué', type='info' })
        end or nil,
    })
    table.insert(opts, { title = '────────────────', disabled = true })

    for ti, side in ipairs({'team1', 'team2'}) do
        local sideLabel = 'Équipe ' .. ti
        for pi = 1, playerCnt do
            local hasCoord = arena[side] and arena[side][pi]
            local desc
            if hasCoord then
                desc = 'x=' .. math.floor(arena[side][pi].x) .. '  y=' .. math.floor(arena[side][pi].y) .. '  — Clique pour mettre à jour'
            else
                desc = 'Non configuré — Place-toi au spawn et clique'
            end
            table.insert(opts, {
                title    = (hasCoord and '✅' or '⬜') .. '  ' .. sideLabel .. ' · J' .. pi,
                description = desc,
                onSelect = function()
                    TriggerServerEvent('viper_ranked:adminSetArenaSpawn', mode, arenaIdx, side, pi, GetCoords())
                end,
            })
        end
    end

    -- Périmètre (mode visuel)
    local b = arena.boundary
    local prevActive = BoundaryPreviewArena
        and BoundaryPreviewArena.mode == mode
        and BoundaryPreviewArena.arenaIdx == arenaIdx

    if prevActive then
        local pc  = GetCoords()
        local dx  = pc.x - BoundaryPreviewCenter.x
        local dy  = pc.y - BoundaryPreviewCenter.y
        local liveR = math.floor(math.sqrt(dx*dx + dy*dy))
        table.insert(opts, {
            title       = '🔴  Préview active — Rayon actuel : ' .. liveR .. ' m',
            description = 'Marche jusqu\'au bord · [E] confirme · [Suppr] annule · ou clique ci-dessous',
            disabled    = true,
        })
        table.insert(opts, {
            title       = '✅  Confirmer (' .. liveR .. ' m)',
            description = 'Sauvegarde le périmètre depuis ta position actuelle',
            onSelect    = function()
                local c   = GetCoords()
                local dx2 = c.x - BoundaryPreviewCenter.x
                local dy2 = c.y - BoundaryPreviewCenter.y
                local r   = math.sqrt(dx2*dx2 + dy2*dy2)
                TriggerServerEvent('viper_ranked:adminSetArenaBoundary', mode, arenaIdx,
                    { x=BoundaryPreviewCenter.x, y=BoundaryPreviewCenter.y, z=BoundaryPreviewCenter.z, radius=r })
                BoundaryPreviewCenter = nil; BoundaryPreviewArena = nil
                lib.hideTextUI(); BoundaryTextUIShown = false
            end,
        })
        table.insert(opts, {
            title       = '↩️  Annuler la prévisualisation',
            description = 'Arrête sans sauvegarder',
            onSelect    = function()
                BoundaryPreviewCenter = nil; BoundaryPreviewArena = nil
                lib.hideTextUI(); BoundaryTextUIShown = false
                lib.notify({ title='Périmètre', description='Configuration annulée.', type='warning' })
            end,
        })
    else
        table.insert(opts, {
            title       = b and ('🔴  Modifier le périmètre — ' .. math.floor(b.radius) .. ' m') or '⬜  Définir le périmètre',
            description = 'Place-toi au centre → clique → marche au bord → [E] pour valider',
            onSelect    = function()
                BoundaryPreviewCenter = GetCoords()
                BoundaryPreviewArena  = { mode=mode, arenaIdx=arenaIdx }
                lib.notify({
                    title       = '📍 Centre fixé!',
                    description = 'Marche jusqu\'au bord de l\'arène — le cercle rouge s\'ajuste en temps réel.\n[E] pour confirmer · [Suppr] pour annuler.',
                    type        = 'info',
                    duration    = 6000,
                })
            end,
        })
        if b then
            table.insert(opts, {
                title       = '🗑️  Supprimer le périmètre',
                description = 'Rayon actuel : ' .. math.floor(b.radius) .. ' m',
                onSelect    = function()
                    TriggerServerEvent('viper_ranked:adminSetArenaBoundary', mode, arenaIdx, nil)
                end,
            })
        end
    end
    table.insert(opts, { title = '────────────────', disabled = true })
    table.insert(opts, {
        title       = '🗑️  Supprimer cette arène',
        description = 'Supprime définitivement l\'arène #' .. arenaIdx .. ' de ' .. mode:upper(),
        onSelect    = function()
            CreateThread(function()
                local r = lib.alertDialog({
                    header   = 'Supprimer l\'arène #' .. arenaIdx .. ' (' .. mode:upper() .. ') ?',
                    content  = 'Cette arène sera supprimée définitivement.\nToutes les positions associées seront perdues.',
                    centered = true,
                    cancel   = true,
                    labels   = { confirm = 'Supprimer', cancel = 'Annuler' },
                })
                if r == 'confirm' then
                    TriggerServerEvent('viper_ranked:adminDeleteArena', mode, arenaIdx)
                end
            end)
        end,
    })

    lib.registerContext({
        id      = 'ranked_admin_arena',
        title   = mode:upper() .. ' — Arène #' .. arenaIdx,
        menu    = 'ranked_admin_mode_arenas',
        options = opts,
    })
    lib.showContext('ranked_admin_arena')
end

-- ─── Sous-menu : Boutique (reçu du serveur avec données live) ─
RegisterNetEvent('viper_ranked:adminReceiveShopPanel', function(data)
    local rotLabel   = 'Rotation #' .. data.rotId
    local timeLabel  = data.daysLeft .. 'j ' .. data.hrsLeft .. 'h restants'
    local itemsLabel = #data.items .. ' article(s) · ' .. data.totalBuys .. ' achat(s)'

    lib.registerContext({
        id      = 'ranked_admin_shop',
        title   = '🛒  GESTION BOUTIQUE',
        menu    = 'ranked_admin_main',
        options = {
            {
                title       = rotLabel,
                description = timeLabel .. '  ·  ' .. itemsLabel,
                disabled    = true,
            },
            { title = '────────────────', disabled = true },
            {
                title       = '➕  Ajouter un article',
                description = 'Arme ou item, prix en RC',
                onSelect    = AdminAddShopItem,
            },
            {
                title       = '📋  Gérer les articles (' .. #data.items .. ')',
                description = #data.items > 0 and 'Modifier prix · Supprimer' or 'Aucun article cette rotation',
                disabled    = #data.items == 0,
                arrow       = #data.items > 0,
                onSelect    = function()
                    OpenManageItemsMenu(data.items)
                end,
            },
            { title = '────────────────', disabled = true },
            {
                title       = '🔄  Réinitialiser la rotation maintenant',
                description = 'Démarre une nouvelle rotation · les achats sont remis à zéro',
                onSelect    = function()
                    CreateThread(function()
                        local r = lib.alertDialog({
                            header   = '⚠️  Réinitialiser la boutique ?',
                            content  = 'Une nouvelle rotation (#' .. (data.rotId + 1) .. ') démarrera immédiatement.\n\n**Tous les achats de la rotation courante seront supprimés.** Les articles ajoutés ne seront plus visibles (ils appartiennent à l\'ancienne rotation).',
                            centered = true,
                            cancel   = true,
                            labels   = { confirm = 'Réinitialiser', cancel = 'Annuler' },
                        })
                        if r == 'confirm' then
                            TriggerServerEvent('viper_ranked:adminRefreshShop')
                        end
                    end)
                end,
            },
        },
    })
    lib.showContext('ranked_admin_shop')
end)

-- ─── Sous-menu : Gérer les articles existants ─────────────────
function OpenManageItemsMenu(items)
    local opts = {}
    for _, item in ipairs(items) do
        local buys = item.buy_count or 0
        table.insert(opts, {
            title       = item.item_label,
            description = item.item_name .. '  ·  ' .. item.price .. ' RC  ·  ' .. buys .. ' achat(s)',
            arrow       = true,
            onSelect    = function()
                OpenItemActionMenu(item)
            end,
        })
    end
    lib.registerContext({
        id      = 'ranked_admin_items_list',
        title   = '📋  ARTICLES — ROTATION COURANTE',
        menu    = 'ranked_admin_shop',
        options = opts,
    })
    lib.showContext('ranked_admin_items_list')
end

-- ─── Actions sur un article (modifier prix / supprimer) ────────
function OpenItemActionMenu(item)
    lib.registerContext({
        id      = 'ranked_admin_item_action',
        title   = item.item_label,
        menu    = 'ranked_admin_items_list',
        options = {
            {
                title       = 'ℹ️  Informations',
                description = 'Nom : ' .. item.item_name .. '\nType : ' .. item.item_type .. '\nPrix : ' .. item.price .. ' RC\nAchats : ' .. (item.buy_count or 0),
                disabled    = true,
            },
            {
                title       = '✏️  Modifier le prix',
                description = 'Prix actuel : ' .. item.price .. ' RC',
                onSelect    = function()
                    CreateThread(function()
                        local input = lib.inputDialog('Modifier le prix de ' .. item.item_label, {
                            {
                                type     = 'number',
                                label    = 'Nouveau prix (RC)',
                                default  = item.price,
                                min      = 1,
                                max      = 99999,
                                required = true,
                            },
                        })
                        if input and input[1] then
                            TriggerServerEvent('viper_ranked:adminEditShopItem', item.id, tonumber(input[1]))
                        end
                    end)
                end,
            },
            {
                title       = '🗑️  Supprimer cet article',
                description = 'Retire l\'article et supprime les achats associés',
                onSelect    = function()
                    CreateThread(function()
                        local r = lib.alertDialog({
                            header   = 'Supprimer ' .. item.item_label .. ' ?',
                            content  = 'Cet article sera retiré de la boutique.\nLes ' .. (item.buy_count or 0) .. ' achat(s) associé(s) seront supprimés.',
                            centered = true,
                            cancel   = true,
                            labels   = { confirm = 'Supprimer', cancel = 'Annuler' },
                        })
                        if r == 'confirm' then
                            TriggerServerEvent('viper_ranked:adminDeleteShopItem', item.id)
                        end
                    end)
                end,
            },
        },
    })
    lib.showContext('ranked_admin_item_action')
end

-- ─── Ajouter un article (dialogue) ────────────────────────────
function AdminAddShopItem()
    CreateThread(function()
        local input = lib.inputDialog('Ajouter un article à la boutique', {
            { type = 'input',  label = 'Nom interne', placeholder = 'weapon_pistol50', required = true },
            { type = 'input',  label = 'Nom affiché',  placeholder = 'Cal .50',         required = true },
            { type = 'select', label = 'Type',         required = true,
              options = { { value = 'weapon', label = 'Arme' }, { value = 'item', label = 'Item' } } },
            { type = 'number', label = 'Prix (RC)',    default = 50, min = 1, max = 99999, required = true },
        })
        if not input or not input[1] then return end
        TriggerServerEvent('viper_ranked:adminAddShopItem', {
            name  = input[1]:lower(),
            label = input[2],
            itype = input[3],
            price = tonumber(input[4]) or 50,
        })
    end)
end

RegisterNetEvent('viper_ranked:adminItemAdded', function()
    TriggerServerEvent('viper_ranked:adminGetShopPanel')
end)

-- ─── Give Coins : réception liste joueurs ─────────────────────
RegisterNetEvent('viper_ranked:adminReceiveOnlinePlayers', function(players)
    if not players or #players == 0 then
        lib.notify({ title='Admin', description='Aucun joueur en ligne.', type='info' })
        return
    end

    local opts = {}
    for _, p in ipairs(players) do
        table.insert(opts, {
            title       = p.name,
            description = 'ID serveur : ' .. p.src .. '  ·  ' .. p.coins .. ' RC',
            icon        = 'user',
            arrow       = true,
            onSelect    = function()
                CreateThread(function()
                    local input = lib.inputDialog('Donner des RC à ' .. p.name, {
                        {
                            type     = 'number',
                            label    = 'Montant à créditer (RC)',
                            min      = 1,
                            max      = 999999,
                            default  = 100,
                            required = true,
                        },
                    })
                    if input and input[1] then
                        TriggerServerEvent('viper_ranked:adminGiveCoins', p.src, tonumber(input[1]))
                    end
                end)
            end,
        })
    end

    lib.registerContext({
        id      = 'ranked_admin_give_coins',
        title   = '🪙  DONNER DES RANKEDCOINS',
        menu    = 'ranked_admin_main',
        options = opts,
    })
    lib.showContext('ranked_admin_give_coins')
end)

-- ─── Commande ─────────────────────────────────────────────────
RegisterCommand('rankedadmin', function()
    TriggerServerEvent('viper_ranked:checkAdmin')
end, false)

-- ─── Prévisualisation périmètre — rendu + touches (frame par frame) ──────────
-- IsControlJustPressed ne dure qu'une frame : DOIT être dans un Wait(0)
CreateThread(function()
    while true do
        if BoundaryPreviewCenter then
            local pc  = GetEntityCoords(PlayerPedId())
            local dx  = pc.x - BoundaryPreviewCenter.x
            local dy  = pc.y - BoundaryPreviewCenter.y
            local r   = math.sqrt(dx*dx + dy*dy)

            -- 36 marqueurs rouges = cercle du périmètre
            for i = 0, 35 do
                local angle = (i / 36.0) * math.pi * 2.0
                DrawMarker(1,
                    BoundaryPreviewCenter.x + math.cos(angle) * r,
                    BoundaryPreviewCenter.y + math.sin(angle) * r,
                    BoundaryPreviewCenter.z,
                    0.0,0.0,0.0, 0.0,0.0,0.0, 0.5,0.5,1.8,
                    255, 55, 55, 220,
                    false, false, 2, false, nil, nil, false)
            end

            -- Marqueur central (étoile jaune)
            DrawMarker(21,
                BoundaryPreviewCenter.x, BoundaryPreviewCenter.y, BoundaryPreviewCenter.z + 0.05,
                0.0,0.0,0.0, 0.0,0.0,0.0, 1.0,1.0,1.0,
                255, 200, 50, 200,
                false, false, 2, false, nil, nil, false)

            -- Rayon affiché au-dessus du joueur
            local onScr, sx, sy = World3dToScreen2d(pc.x, pc.y, pc.z + 1.8)
            if onScr then
                SetTextScale(0.0, 0.5); SetTextFont(4); SetTextProportional(1)
                SetTextColour(255, 255, 255, 255)
                SetTextDropShadow(); SetTextOutline()
                SetTextEntry('STRING'); SetTextCentre(true)
                AddTextComponentString(math.floor(r) .. ' m')
                DrawText(sx, sy)
            end

            -- Touches détectées ici (Wait(0) = chaque frame, aucune pression ratée)
            if IsControlJustPressed(0, 38) then      -- E = confirmer
                local c   = GetCoords()
                local dx2 = c.x - BoundaryPreviewCenter.x
                local dy2 = c.y - BoundaryPreviewCenter.y
                local finalR = math.sqrt(dx2*dx2 + dy2*dy2)
                TriggerServerEvent('viper_ranked:adminSetArenaBoundary',
                    BoundaryPreviewArena.mode, BoundaryPreviewArena.arenaIdx,
                    { x=BoundaryPreviewCenter.x, y=BoundaryPreviewCenter.y, z=BoundaryPreviewCenter.z, radius=finalR })
                BoundaryPreviewCenter = nil; BoundaryPreviewArena = nil
                lib.hideTextUI(); BoundaryTextUIShown = false
                lib.notify({ title='✅ Périmètre sauvegardé', description='Rayon : ' .. math.floor(finalR) .. ' m', type='success' })
            elseif IsControlJustPressed(0, 177) then -- Suppr = annuler
                BoundaryPreviewCenter = nil; BoundaryPreviewArena = nil
                lib.hideTextUI(); BoundaryTextUIShown = false
                lib.notify({ title='Périmètre', description='Configuration annulée.', type='warning' })
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ─── Prévisualisation périmètre — textUI (500ms, pas besoin d'être frame-rate) ─
CreateThread(function()
    while true do
        if BoundaryPreviewCenter then
            local pc = GetEntityCoords(PlayerPedId())
            local dx = pc.x - BoundaryPreviewCenter.x
            local dy = pc.y - BoundaryPreviewCenter.y
            local r  = math.floor(math.sqrt(dx*dx + dy*dy))
            lib.showTextUI('[E]  Confirmer (' .. r .. ' m)     [Suppr]  Annuler', {
                position = 'top-center',
                icon     = 'circle-dot',
            })
            BoundaryTextUIShown = true
            Wait(500)
        else
            if BoundaryTextUIShown then
                lib.hideTextUI()
                BoundaryTextUIShown = false
            end
            Wait(500)
        end
    end
end)
