local function GenerateMatchId()
    return tostring(GetGameTimer()) .. tostring(math.random(1000, 9999))
end

local MatchBucketCounter = 0   -- compteur de bucket (entier, incrémenté à chaque match)

local function AllPlayers(match)
    local all = {}
    for _, s in ipairs(match.team1.players) do table.insert(all, s) end
    for _, s in ipairs(match.team2.players) do table.insert(all, s) end
    return all
end

local function CountAlive(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function CountSpawns(t)
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ─── Démarrer un match ───────────────────────────────────────────────────────
function StartMatch(team1Players, team2Players, mode)
    local pos    = GetPositions()
    local arenas = pos[mode] and pos[mode].arenas or {}

    local validArenas = {}
    for i, arena in ipairs(arenas) do
        if CountSpawns(arena.team1) >= 1 and CountSpawns(arena.team2) >= 1 then
            table.insert(validArenas, i)
        end
    end

    if #validArenas == 0 then
        print('^1[viper_ranked] ^7ERREUR : aucune arène valide pour ' .. mode .. '! Lance /rankedadmin pour les définir.')
        local msg = {
            title       = '⚠️  Ranked',
            description = 'Aucune arène configurée pour le mode ' .. mode .. '.\nContacte un administrateur.',
            type        = 'error',
            duration    = 8000,
        }
        for _, s in ipairs(team1Players) do TriggerClientEvent('ox_lib:notify', s, msg) end
        for _, s in ipairs(team2Players) do TriggerClientEvent('ox_lib:notify', s, msg) end
        return
    end

    local arenaIdx = validArenas[math.random(1, #validArenas)]
    local arena    = arenas[arenaIdx]

    local matchId   = GenerateMatchId()
    local team1Name = mode == '1v1' and (GetPlayerName(team1Players[1]) or 'Joueur 1') or 'Équipe 1'
    local team2Name = mode == '1v1' and (GetPlayerName(team2Players[1]) or 'Joueur 2') or 'Équipe 2'

    MatchBucketCounter = MatchBucketCounter + 1
    local bucket = MatchBucketCounter

    local playerCache = {}
    for _, s in ipairs(team1Players) do
        local p = QBCore.Functions.GetPlayer(s)
        if p then playerCache[s] = { cid = p.PlayerData.citizenid, name = p.PlayerData.charinfo.firstname } end
    end
    for _, s in ipairs(team2Players) do
        local p = QBCore.Functions.GetPlayer(s)
        if p then playerCache[s] = { cid = p.PlayerData.citizenid, name = p.PlayerData.charinfo.firstname } end
    end

    local match = {
        id          = matchId,
        mode        = mode,
        round       = 1,
        state       = 'countdown',
        arenaIdx    = arenaIdx,
        bucket      = bucket,
        playerCache = playerCache,
        team1 = { players=team1Players, score=0, alive={}, name=team1Name },
        team2 = { players=team2Players, score=0, alive={}, name=team2Name },
    }
    Matches[matchId] = match

    for _, s in ipairs(team1Players) do
        PlayerInMatch[s] = { matchId=matchId, team='team1' }
        match.team1.alive[s] = true
        SetPlayerRoutingBucket(s, bucket)
    end
    for _, s in ipairs(team2Players) do
        PlayerInMatch[s] = { matchId=matchId, team='team2' }
        match.team2.alive[s] = true
        SetPlayerRoutingBucket(s, bucket)
    end

    for i, s in ipairs(team1Players) do
        local mates = {}
        for _, ts in ipairs(team1Players) do if ts ~= s then mates[#mates+1] = ts end end
        TriggerClientEvent('viper_ranked:matchStart', s, {
            matchId     = matchId,
            mode        = mode,
            team1Name   = team1Name,
            team2Name   = team2Name,
            spawnCoords = arena.team1[i] or arena.team1[1],
            myTeam      = 'team1',
            teammates   = mates,
            countdown   = Config.RoundCountdown,
            boundary    = arena.boundary,
        })
    end
    for i, s in ipairs(team2Players) do
        local mates = {}
        for _, ts in ipairs(team2Players) do if ts ~= s then mates[#mates+1] = ts end end
        TriggerClientEvent('viper_ranked:matchStart', s, {
            matchId     = matchId,
            mode        = mode,
            team1Name   = team1Name,
            team2Name   = team2Name,
            spawnCoords = arena.team2[i] or arena.team2[1],
            myTeam      = 'team2',
            teammates   = mates,
            countdown   = Config.RoundCountdown,
            boundary    = arena.boundary,
        })
    end

    SetTimeout((Config.RoundCountdown * 1000) + 500, function()
        if Matches[matchId] then Matches[matchId].state = 'active' end
    end)
end

-- ─── Nouvelle manche ─────────────────────────────────────────────────────────
function StartRound(matchId)
    local match = Matches[matchId]
    if not match or match.state == 'ended' then return end

    local pos   = GetPositions()
    local arena = pos[match.mode].arenas[match.arenaIdx]

    match.team1.alive = {}
    match.team2.alive = {}
    for _, s in ipairs(match.team1.players) do match.team1.alive[s] = true end
    for _, s in ipairs(match.team2.players) do match.team2.alive[s] = true end
    match.state = 'countdown'

    for i, s in ipairs(match.team1.players) do
        TriggerClientEvent('viper_ranked:roundStart', s, {
            round       = match.round,
            spawnCoords = arena.team1[i] or arena.team1[1],
            team1Score  = match.team1.score,
            team2Score  = match.team2.score,
            countdown   = Config.RoundCountdown,
            boundary    = arena.boundary,
        })
    end
    for i, s in ipairs(match.team2.players) do
        TriggerClientEvent('viper_ranked:roundStart', s, {
            round       = match.round,
            spawnCoords = arena.team2[i] or arena.team2[1],
            team1Score  = match.team1.score,
            team2Score  = match.team2.score,
            countdown   = Config.RoundCountdown,
            boundary    = arena.boundary,
        })
    end

    SetTimeout((Config.RoundCountdown * 1000) + 500, function()
        if Matches[matchId] then Matches[matchId].state = 'active' end
    end)
end

-- ─── Mort d'un joueur ────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:playerDied', function(matchId)
    local src   = source
    local match = Matches[matchId]
    if not match or match.state ~= 'active' then return end

    local deadTeam, otherTeam
    if match.team1.alive[src] then
        deadTeam, otherTeam = 'team1', 'team2'
        match.team1.alive[src] = nil
    elseif match.team2.alive[src] then
        deadTeam, otherTeam = 'team2', 'team1'
        match.team2.alive[src] = nil
    else
        return
    end

    if CountAlive(match[deadTeam].alive) == 0 then
        match.state = 'scoring'
        match[otherTeam].score = match[otherTeam].score + 1

        for _, s in ipairs(AllPlayers(match)) do
            TriggerClientEvent('viper_ranked:updateScore', s, match.team1.score, match.team2.score, match.round)
        end

        if match.team1.score >= Config.RoundsToWin or match.team2.score >= Config.RoundsToWin then
            local winner = match.team1.score >= Config.RoundsToWin and 'team1' or 'team2'
            SetTimeout(Config.RoundDelay, function() EndMatch(matchId, winner) end)
        else
            match.round = match.round + 1
            SetTimeout(Config.RoundDelay, function()
                if Matches[matchId] then StartRound(matchId) end
            end)
        end
    end
end)

-- ─── Headshot instantané (détection côté attaquant) ──────────────────────────
RegisterNetEvent('viper_ranked:headshot', function(matchId, victimSrc)
    local src   = source
    local match = Matches[matchId]
    if not match or match.state ~= 'active' then return end

    local pdata = PlayerInMatch[src]
    local vdata = PlayerInMatch[victimSrc]
    if not pdata or pdata.matchId ~= matchId then return end
    if not vdata or vdata.matchId ~= matchId then return end
    if pdata.team == vdata.team then return end  -- anti-exploit : même équipe

    TriggerClientEvent('viper_ranked:forceKill', victimSrc)
end)

-- ─── Fin de match ────────────────────────────────────────────────────────────
function EndMatch(matchId, winnerTeam)
    local match = Matches[matchId]
    if not match or match.state == 'ended' then return end
    match.state = 'ended'

    -- Remettre tous les joueurs dans le monde principal avant d'envoyer matchEnd
    for _, s in ipairs(AllPlayers(match)) do
        SetPlayerRoutingBucket(s, 0)
    end

    for _, s in ipairs(match.team1.players) do
        local win = winnerTeam == 'team1'
        TriggerClientEvent('viper_ranked:matchEnd', s, {
            win        = win,
            eloGain    = Config.EloGain,
            eloLoss    = Config.EloLoss,
            coinsGain  = win and Config.CoinsPerWin or 0,
            npcCoords  = Positions.npc,
        })
        UpdatePlayerStats(s, win, match.playerCache)
        PlayerInMatch[s] = nil
    end
    for _, s in ipairs(match.team2.players) do
        local win = winnerTeam == 'team2'
        TriggerClientEvent('viper_ranked:matchEnd', s, {
            win        = win,
            eloGain    = Config.EloGain,
            eloLoss    = Config.EloLoss,
            coinsGain  = win and Config.CoinsPerWin or 0,
            npcCoords  = Positions.npc,
        })
        UpdatePlayerStats(s, win, match.playerCache)
        PlayerInMatch[s] = nil
    end

    -- Met à jour l'hologramme top 3 après stats recalculées
    SetTimeout(2000, function() BroadcastHoloData() end)

    -- Rematch automatique après délai (2v2/3v3)
    if match.mode ~= '1v1' then
        local t1        = {}
        local t2        = {}
        local matchMode = match.mode
        for _, s in ipairs(match.team1.players) do t1[#t1+1] = s end
        for _, s in ipairs(match.team2.players) do t2[#t2+1] = s end

        local pendingPlayers = {}
        for _, s in ipairs(t1) do pendingPlayers[s] = true end
        for _, s in ipairs(t2) do pendingPlayers[s] = true end
        PendingRematch[matchId] = { players = pendingPlayers, t1 = t1, t2 = t2, mode = matchMode }

        for s in pairs(pendingPlayers) do
            TriggerClientEvent('viper_ranked:rematchCountdown', s, 15)
        end

        CreateThread(function()
            Wait(15000)
            local pending = PendingRematch[matchId]
            if not pending then return end
            PendingRematch[matchId] = nil
            local newT1, newT2 = {}, {}
            for _, s in ipairs(pending.t1) do if pending.players[s] then newT1[#newT1+1] = s end end
            for _, s in ipairs(pending.t2) do if pending.players[s] then newT2[#newT2+1] = s end end
            RestoreGroup(newT1, pending.mode)
            RestoreGroup(newT2, pending.mode)
        end)
    end

    SetTimeout(10000, function() Matches[matchId] = nil end)
end

-- ─── Sortie de zone ──────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:boundaryViolation', function(matchId)
    local src   = source
    local match = Matches[matchId]
    if not match or match.state ~= 'active' then return end

    local pdata = PlayerInMatch[src]
    if not pdata or pdata.matchId ~= matchId then return end

    local violatorTeam = pdata.team
    local winnerTeam   = violatorTeam == 'team1' and 'team2' or 'team1'

    match.state = 'scoring'
    match[winnerTeam].score = match[winnerTeam].score + 1

    for _, s in ipairs(AllPlayers(match)) do
        TriggerClientEvent('ox_lib:notify', s, {
            title       = '⚠️ Hors zone',
            description = GetPlayerName(src) .. ' a quitté la zone — son équipe perd la manche !',
            type        = 'error',
            duration    = 4000,
        })
        TriggerClientEvent('viper_ranked:updateScore', s, match.team1.score, match.team2.score, match.round)
    end

    if match.team1.score >= Config.RoundsToWin or match.team2.score >= Config.RoundsToWin then
        local winner = match.team1.score >= Config.RoundsToWin and 'team1' or 'team2'
        SetTimeout(Config.RoundDelay, function() EndMatch(matchId, winner) end)
    else
        match.round = match.round + 1
        SetTimeout(Config.RoundDelay, function()
            if Matches[matchId] then StartRound(matchId) end
        end)
    end
end)

-- ─── Forfait /ff ─────────────────────────────────────────────────────────────
RegisterNetEvent('viper_ranked:forfeit', function(matchId)
    local src   = source
    local match = Matches[matchId]
    if not match or match.state == 'ended' then return end

    local forfeitTeam
    for _, s in ipairs(match.team1.players) do
        if s == src then forfeitTeam = 'team1'; break end
    end
    if not forfeitTeam then
        for _, s in ipairs(match.team2.players) do
            if s == src then forfeitTeam = 'team2'; break end
        end
    end

    if forfeitTeam then
        local winner = forfeitTeam == 'team1' and 'team2' or 'team1'
        for _, s in ipairs(AllPlayers(match)) do
            TriggerClientEvent('ox_lib:notify', s, {
                title='Ranked', description=GetPlayerName(src)..' a abandonné le match!', type='warning',
            })
        end
        EndMatch(matchId, winner)
    end
end)
