Squads = {}
MySquad = {}
Invites = {}
SquadStats = {}
Wars = {}
WarRequests = {}
SquadWar = {}
WarBets = {}
local warIdCounter = 0
local debug = false
local playerPhotos = {}
local modules = exports["gfx-lib"]:getModules()

function SetWarBucketForSquad(squad, bucketId)
    if not Config.WarBucketEnabled then return end
    for i = 1, #squad.members do
        local memberId = squad.members[i].id
        if GetPlayerName(memberId) then
            SetPlayerRoutingBucket(memberId, bucketId)
        end
    end
end

local defaultPhoto = "https://avatar.iran.liara.run/public/1"

function GetPhoto(src)
    return playerPhotos[src] or defaultPhoto
end

RegisterNetEvent("gfx-squad:playerLoaded",function()
    local source = source
    if not playerPhotos[source] then
        local ok, photo = pcall(modules.GetPlayerPhoto, source)
        playerPhotos[source] = (ok and photo) or defaultPhoto
    end

    -- If player's squad is in an active war, set their routing bucket
    local squadId = MySquad[source]
    if squadId and Config.WarBucketEnabled then
        local warId = SquadWar[squadId]
        if warId and Wars[warId] and Wars[warId].status == 'active' then
            SetPlayerRoutingBucket(source, warId)
        end
    end
end)


AddEventHandler("playerDropped", function(reason)
    playerPhotos[source] = nil
end)
    

if debug then
    table.insert(Squads, {
        id = 123456,
        name = "Test Squad",
        owner = 4,
        image = "https://j.gifs.com/5y86p8.gif",
        privacy = "public",
        memberLimit = 12,
        members = {
            {
                id = 4, 
                name = "Test",
                image = "https://j.gifs.com/5y86p8.gif",
                distance = 0,
                coords = {
                    x = 0,
                    y = 0,
                }
            }
        },
        chat = {
            {
                id = 1,
                name = "Test",
                image = "https://j.gifs.com/5y86p8.gif",
                message = "Hello",
                time = "12:00"
            }
        }
    })

    Invites[1] = {
        {
            id = 123456,
            image = "https://j.gifs.com/5y86p8.gif",
            name = "Test Squad",
            members = 1,
            maxMembers = 10
        }
    }
end

RegisterCallback('removeInvite', function(source, id)
    if Invites[source] == nil then
        return Notify(source, "You have no invites")
    end

    for i = 1, #Invites[source] do
        if Invites[source][i].id == id then
            table.remove(Invites[source], i)
            return true
        end
    end

    return false
end)

RegisterCallback('gfx-crew:getMemberCoords', function(source, member)
    local player = GetPlayerPed(member)
    local playerCoords = GetEntityCoords(player)
    return playerCoords
end)

RegisterCallback('getInvites', function(source, data)
    if Invites[source] == nil then
        return {}
    end
    return Invites[source]
end)

RegisterCallback('inviteMember', function(source, data)
    if not IsMemberOwner(source) then
        return Notify(source, "You are not the owner of the squad")
    end

    local squad = GetSquadById(MySquad[source])
    local target = tonumber(data)
    local inviteData = {
        id = squad.id,
        image = squad.image,
        name = squad.name,
        members = #squad.members,
        maxMembers = squad.memberLimit
    }

    if target == nil then
        return Notify(source, "Player not found")
    end

    if IsPlayerInASquad(target) then
        return Notify(source, "Player is already in a squad")
    end

    if Invites[target] ~= nil then
        table.insert(Invites[target], inviteData)
    else
        Invites[target] = { inviteData }
    end

    -- buraya memberın invite sayısının gönderilmesi gelicek

    TriggerClientEvent("setInviteCount", target, #Invites[target])

    Notify(target, "You have been invited to " .. squad.name)
    return true
end)

RegisterCallback("checkSquadName", function(source, data)
    local squadId = MySquad[source]
    
    if squadId then
        local squad = GetSquadById(MySquad[source])
        if squad and squad.name:lower() == data:lower() then
            return true
        end
    end

    for i = 1, #Squads do
        if Squads[i].name:lower() == data:lower() then
            return false
        end
    end
    return true
end)

RegisterCallback("getSquads", function(source, data)
    local squads = {}
    for i = 1, #Squads do
        if Squads[i].privacy == "public" then
            table.insert(squads, {
                id = Squads[i].id,
                name = Squads[i].name,
                image = Squads[i].image,
                maxMembers = Squads[i].memberLimit,
                members = #Squads[i].members,
            })
        end
    end
    return squads
end)

RegisterCallback("createSquad", function(source, data)
    if IsPlayerInASquad(source) then 
        Notify(source, _L("in_crew"))
        return
    end

    local id = RandomId()
    MySquad[source] = id
    local coords = GetEntityCoords(GetPlayerPed(source))
    table.insert(Squads, {
        id = id,
        name = data.name,
        owner = source,
        image = data.image,
        privacy = data.privacy,
        memberLimit = data.memberLimit,
        members = {
            {
                id = source, 
                name = GetPlayerNameBySource(source),
                image = GetPhoto(source),
                distance = 0,
                coords = {
                    x = coords.x,
                    y = coords.y,
                }
            }
        },
        chat = {}
    })
    TriggerClientEvent("gfx-squad:AddRelationShip", source, id)

    local identifier = GetIdentifier(source)
    if identifier then
        SquadStats[id] = {}
        SquadStats[id][identifier] = { kills = 0, deaths = 0, name = GetPlayerNameBySource(source), image = GetPhoto(source) }
    end

    return { id = id, members = Squads[#Squads].members }
end)

function GetSquadMember(squad, source)
    for i = 1, #squad.members do
        if squad.members[i].id == source then
            return squad.members[i]
        end
    end
    return nil
end

RegisterCallback('sendMessage', function(source, data)
    sendMessage(source, data)
end)

RegisterServerEvent("gfx-squad:sendMessage")
AddEventHandler("gfx-squad:sendMessage", function(data)
    sendMessage(source, data)
end)

function sendMessage(source, data)
    if not IsPlayerInASquad(source) then 
        Notify(source, _L("not_in_crew"))
        return
    end

    local squad = GetSquadById(MySquad[source])
    local member = GetSquadMember(squad, source)
    if not member then return end
    table.insert(squad.chat, {
        id = source,
        name = member.name,
        image = member.image,
        message = data,
        time = os.date("%H:%M", os.time())
    })

    TriggerEventForMembers(squad, "newMessage", squad.chat[#squad.chat])
    TriggerEventForMembers(squad, "gfx-squad:updateUnseenCount")
end

RegisterCallback('getMessages', function(source, data)
    if not IsPlayerInASquad(source) then 
        Notify(source, _L("not_in_crew"))
        return
    end

    local squad = GetSquadById(MySquad[source])
    return squad.chat
end)

function GetSquadById(id)
    for i = 1, #Squads do
        if Squads[i].id == id then
            return Squads[i]
        end
    end
    return nil
end

RegisterCallback("getMembers", function(source, data)
    if not IsPlayerInASquad(source) then 
        Notify(source, _L("not_in_crew"))
        return
    end
    local squad = GetSquadById(MySquad[source])
    return { members = squad.members}
end)

RegisterCallback("joinSquad", function(source, data)
    if IsPlayerInASquad(source) then 
        Notify(source, _L("in_crew"))
        return
    end

    local squad = GetSquadById(data)

    if squad == nil then
        Notify(source, "Squad not found")
        return
    end

    if #squad.members >= squad.memberLimit then
        Notify(source, "Squad is full")
        return
    end

    MySquad[source] = squad.id
    local coords = GetEntityCoords(GetPlayerPed(source))
    table.insert(squad.members, {
        id = source, 
        name = GetPlayerNameBySource(source),
        image = GetPhoto(source),
        distance = 0,
        coords = {
            x = coords.x,
            y = coords.y,
        }
    })

    TriggerClientEvent("gfx-squad:AddRelationShip", source, squad.id)
    TriggerEventForMembers(squad, "updateMembers", squad.members[#squad.members])

    local identifier = GetIdentifier(source)
    if identifier then
        if not SquadStats[squad.id] then
            SquadStats[squad.id] = {}
        end
        if not SquadStats[squad.id][identifier] then
            SquadStats[squad.id][identifier] = { kills = 0, deaths = 0, name = GetPlayerNameBySource(source), image = GetPhoto(source) }
        else
            SquadStats[squad.id][identifier].name = GetPlayerNameBySource(source)
            SquadStats[squad.id][identifier].image = GetPhoto(source)
        end
    end

    return squad.members
end)

RegisterCallback("leaveSquad", function(source, data)
   return LeaveSquad(source)
end)

function LeaveSquad(source)
    local squad = GetSquadById(MySquad[source])
    if squad == nil then
        Notify(source, "Squad not found")
        return
    end

    if IsMemberOwner(source) then
        return Notify(source, "You are the owner of the squad")
    end

    for i = 1, #squad.members do
        if squad.members[i].id == source then
            table.remove(squad.members, i)
            break
        end
    end

    MySquad[source] = nil

    TriggerClientEvent("gfx-squad:RemoveRelationShip", source)
    TriggerEventForMembers(squad, "memberGone", source)
    return true
end

RegisterCallback("deleteSquad", function(source, data)
    return DeleteSquad(source)
end)

function DeleteSquad(source)
    local squad = GetSquadById(MySquad[source])
    if squad == nil then
        Notify(source, "Squad not found")
        return
    end

    if not IsMemberOwner(source) then
        return Notify(source, "You are not the owner of the squad")
    end

    local warId = SquadWar[squad.id]
    if warId then
        EndWar(warId, squad.id)
    end

    if SquadStats[squad.id] then
        SquadStats[squad.id] = nil
    end

    TriggerEventForMembers(squad, "squadDeleted", true)

    for i = 1, #Squads do
        if Squads[i].id == squad.id then
            table.remove(Squads, i)
            break
        end
    end

    for i = 1, #squad.members do
        MySquad[squad.members[i].id] = nil
    end

    return true
end

AddEventHandler("playerDropped", function(reason)
    local squadId = MySquad[source]
    if squadId == nil then return end
    if IsMemberOwner(source) then
        DeleteSquad(source)
    else
        LeaveSquad(source)
    end
end)


function IsMemberOwner(source)
    local squad = GetSquadById(MySquad[source])
    return squad and squad.owner == source
end

function IsPlayerInASquad(source)
    return MySquad[source] ~= nil
end


function RandomId()
    local id = math.random(100000, 999999)
    for i = 1, #Squads do
        if Squads[i].id == id then
            return RandomId()
        end
    end
    return id
end

function TriggerEventForMembers(squad, event, data)
    for i = 1, #squad.members do
        TriggerClientEvent(event, squad.members[i].id, data)
    end
end

RegisterCallback("getSquadSettings", function(source)
    if not IsPlayerInASquad(source) then 
        Notify(source, _L("not_in_crew"))
        return
    end

    local squad = GetSquadById(MySquad[source])
    if squad == nil then
        return Notify(source, "Squad not found")
    end

    return squad
end)

RegisterCallback("updateSquadSettings", function(source, data)
    if not IsPlayerInASquad(source) then 
        Notify(source, _L("not_in_crew"))
        return
    end

    local squad = GetSquadById(MySquad[source])
    if squad == nil then
        return Notify(source, "Squad not found")
    end

    squad.name = data.name
    squad.image = data.image
    squad.privacy = data.privacy
    squad.memberLimit = data.memberLimit
    
    return true
end)

RegisterCallback("getPlayers", function(source)
    local players = GetPlayers()
    local result = {}

    for i = 1, #players do
        local src = tonumber(players[i])
        if MySquad[src] == nil then
            table.insert(result, {
                id = players[i],
                name = GetPlayerNameBySource(src),
                image = GetPhoto(src),
                distance = 0,
                coords = {
                    x = 0,
                    y = 0,
                }
            })
        end
    end

    return result
end)

RegisterCallback('kickMember', function(source, data)
    if not IsMemberOwner(source) then
        return Notify(source, "You are not the owner of the squad")
    end

    local squad = GetSquadById(MySquad[source])
    local target = data

    if target == nil then
        return Notify(source, "Player not found")
    end

    for i = 1, #squad.members do
        if squad.members[i].id == target then
            table.remove(squad.members, i)
            MySquad[target] = nil
            TriggerEventForMembers(squad, "memberGone", target)
            TriggerClientEvent("kicked", target)
            return true
        end
    end

    return false
end)

RegisterCallback('getSquadSettings', function(source)
    if not IsPlayerInASquad(source) then
        Notify(source, _L("not_in_crew"))
        return
    end

    local squad = GetSquadById(MySquad[source])
    if squad == nil then
        return Notify(source, "Squad not found")
    end

    return squad

end)

-- =============================================
-- LEADERBOARD
-- =============================================

RegisterNetEvent('gfx-squad:onPlayerKill', function(victimId)
    local src = source
    local killerSquadId = MySquad[src]
    local victimSquadId = MySquad[victimId]

    if killerSquadId then
        local killerIdentifier = GetIdentifier(src)
        if killerIdentifier and SquadStats[killerSquadId] and SquadStats[killerSquadId][killerIdentifier] then
            SquadStats[killerSquadId][killerIdentifier].kills = SquadStats[killerSquadId][killerIdentifier].kills + 1
        end
        local killerSquad = GetSquadById(killerSquadId)
        if killerSquad then
            TriggerEventForMembers(killerSquad, "leaderboardUpdate", true)
        end
    end

    if victimSquadId then
        local victimIdentifier = GetIdentifier(victimId)
        if victimIdentifier and SquadStats[victimSquadId] and SquadStats[victimSquadId][victimIdentifier] then
            SquadStats[victimSquadId][victimIdentifier].deaths = SquadStats[victimSquadId][victimIdentifier].deaths + 1
        end
        local victimSquad = GetSquadById(victimSquadId)
        if victimSquad then
            TriggerEventForMembers(victimSquad, "leaderboardUpdate", true)
        end
    end

    if killerSquadId and victimSquadId and killerSquadId ~= victimSquadId then
        local warId = SquadWar[killerSquadId]
        if warId then
            local war = Wars[warId]
            if war and war.status == 'active' then
                if (war.squad1.id == killerSquadId and war.squad2.id == victimSquadId) or
                   (war.squad2.id == killerSquadId and war.squad1.id == victimSquadId) then
                    if war.squad1.id == killerSquadId then
                        war.squad1.score = war.squad1.score + 1
                    else
                        war.squad2.score = war.squad2.score + 1
                    end
                    local squad1 = GetSquadById(war.squad1.id)
                    local squad2 = GetSquadById(war.squad2.id)
                    local scoreData = {
                        squad1 = { id = war.squad1.id, name = war.squad1.name, score = war.squad1.score },
                        squad2 = { id = war.squad2.id, name = war.squad2.name, score = war.squad2.score },
                        timeLeft = war.duration - (os.time() - war.startTime)
                    }
                    if squad1 then TriggerEventForMembers(squad1, "warScoreUpdate", scoreData) end
                    if squad2 then TriggerEventForMembers(squad2, "warScoreUpdate", scoreData) end
                end
            end
        end
    end
end)

RegisterCallback('getLeaderboard', function(source)
    local squadId = MySquad[source]
    if not squadId then return {} end

    local stats = SquadStats[squadId]
    if not stats then return {} end

    local leaderboard = {}
    for _, data in pairs(stats) do
        local kd = data.deaths > 0 and string.format("%.2f", data.kills / data.deaths) or string.format("%.2f", data.kills * 1.0)
        table.insert(leaderboard, {
            name = data.name,
            image = data.image,
            kills = data.kills,
            deaths = data.deaths,
            kd = kd
        })
    end

    table.sort(leaderboard, function(a, b) return a.kills > b.kills end)
    return leaderboard
end)

-- =============================================
-- SQUAD WAR
-- =============================================

function StartWarTimer(warId)
    CreateThread(function()
        local war = Wars[warId]
        if not war then return end
        Wait(war.duration * 1000)
        if Wars[warId] and Wars[warId].status == 'active' then
            EndWar(warId)
        end
    end)
end

function EndWar(warId, forfeitSquadId)
    local war = Wars[warId]
    if not war or war.status == 'ended' then return end
    war.status = 'ended'

    local result = {}
    if forfeitSquadId then
        if war.squad1.id == forfeitSquadId then
            result = { winner = war.squad2, loser = war.squad1, isDraw = false, forfeit = true }
        else
            result = { winner = war.squad1, loser = war.squad2, isDraw = false, forfeit = true }
        end
    elseif war.squad1.score == war.squad2.score then
        result = { isDraw = true, squad1 = war.squad1, squad2 = war.squad2 }
    elseif war.squad1.score > war.squad2.score then
        result = { winner = war.squad1, loser = war.squad2, isDraw = false }
    else
        result = { winner = war.squad2, loser = war.squad1, isDraw = false }
    end

    local squad1 = GetSquadById(war.squad1.id)
    local squad2 = GetSquadById(war.squad2.id)

    -- Reset routing buckets
    if squad1 then SetWarBucketForSquad(squad1, 0) end
    if squad2 then SetWarBucketForSquad(squad2, 0) end

    -- Process bets
    if Config.BetEnabled and WarBets[warId] then
        for identifier, bet in pairs(WarBets[warId]) do
            -- Find current source by identifier (handles reconnects)
            local payoutSource = nil
            if squad1 then
                for i = 1, #squad1.members do
                    if GetPlayerName(squad1.members[i].id) and GetIdentifier(squad1.members[i].id) == identifier then
                        payoutSource = squad1.members[i].id
                        break
                    end
                end
            end
            if not payoutSource and squad2 then
                for i = 1, #squad2.members do
                    if GetPlayerName(squad2.members[i].id) and GetIdentifier(squad2.members[i].id) == identifier then
                        payoutSource = squad2.members[i].id
                        break
                    end
                end
            end

            if payoutSource then
                if result.isDraw then
                    AddMoney(payoutSource, bet.amount)
                elseif result.winner and bet.squadId == result.winner.id then
                    AddMoney(payoutSource, bet.amount * (Config.BetMultiplier or 2))
                end
                -- Losers: money already taken, nothing to do
            end
        end
        WarBets[warId] = nil
    end

    -- Chat announcement
    local systemMsg = {
        id = 0,
        name = "System",
        image = "",
        message = result.isDraw
            and string.format("War ended in a draw! %s %d - %d %s", result.squad1.name, result.squad1.score, result.squad2.score, result.squad2.name)
            or string.format("%s won the war! %d - %d vs %s", result.winner.name, result.winner.score, result.loser.score, result.loser.name),
        time = os.date("%H:%M", os.time()),
        system = true
    }

    if squad1 then
        table.insert(squad1.chat, systemMsg)
        TriggerEventForMembers(squad1, "newMessage", systemMsg)
    end
    if squad2 then
        table.insert(squad2.chat, systemMsg)
        TriggerEventForMembers(squad2, "newMessage", systemMsg)
    end

    if squad1 then TriggerEventForMembers(squad1, "warEnded", result) end
    if squad2 then TriggerEventForMembers(squad2, "warEnded", result) end

    SquadWar[war.squad1.id] = nil
    SquadWar[war.squad2.id] = nil
    Wars[warId] = nil
end

RegisterCallback('getWarTargets', function(source)
    local mySquadId = MySquad[source]
    if not mySquadId then return {} end

    local targets = {}
    for i = 1, #Squads do
        local squad = Squads[i]
        if squad.id ~= mySquadId and not SquadWar[squad.id] then
            table.insert(targets, {
                id = squad.id,
                name = squad.name,
                image = squad.image,
                members = #squad.members
            })
        end
    end
    return targets
end)

RegisterCallback('challengeSquad', function(source, targetSquadId)
    if not IsMemberOwner(source) then return false end

    local mySquadId = MySquad[source]
    if SquadWar[mySquadId] then return false end
    if SquadWar[targetSquadId] then return false end

    local targetSquad = GetSquadById(targetSquadId)
    if not targetSquad then return false end

    local mySquad = GetSquadById(mySquadId)
    if not mySquad then return false end

    WarRequests[targetSquadId] = {
        from = mySquadId,
        timestamp = os.time()
    }

    TriggerClientEvent("warChallenge", targetSquad.owner, {
        squadId = mySquadId,
        name = mySquad.name,
        image = mySquad.image,
        members = #mySquad.members
    })

    SetTimeout(30000, function()
        if WarRequests[targetSquadId] and WarRequests[targetSquadId].from == mySquadId then
            WarRequests[targetSquadId] = nil
            TriggerClientEvent("warDeclined", source, true)
        end
    end)

    return true
end)

RegisterCallback('respondWar', function(source, accept)
    local mySquadId = MySquad[source]
    if not mySquadId then return false end
    if not IsMemberOwner(source) then return false end

    local request = WarRequests[mySquadId]
    if not request then return false end

    WarRequests[mySquadId] = nil

    if not accept then
        local challengerSquad = GetSquadById(request.from)
        if challengerSquad then
            TriggerClientEvent("warDeclined", challengerSquad.owner, true)
        end
        return false
    end

    warIdCounter = warIdCounter + 1
    local warId = warIdCounter
    local mySquad = GetSquadById(mySquadId)
    local challengerSquad = GetSquadById(request.from)

    if not mySquad or not challengerSquad then return false end

    local betWaitTime = Config.BetEnabled and (Config.BetWaitTime or 15) or 0

    Wars[warId] = {
        id = warId,
        squad1 = { id = request.from, name = challengerSquad.name, score = 0 },
        squad2 = { id = mySquadId, name = mySquad.name, score = 0 },
        startTime = os.time(),
        duration = Config.WarDuration or 300,
        status = betWaitTime > 0 and 'betting' or 'active'
    }

    SquadWar[request.from] = warId
    SquadWar[mySquadId] = warId

    if Config.BetEnabled then
        WarBets[warId] = {}
    end

    -- Set routing buckets immediately
    SetWarBucketForSquad(challengerSquad, warId)
    SetWarBucketForSquad(mySquad, warId)

    local warData = {
        squad1 = { id = request.from, name = challengerSquad.name, score = 0 },
        squad2 = { id = mySquadId, name = mySquad.name, score = 0 },
        duration = Wars[warId].duration,
        startTime = Wars[warId].startTime
    }

    if betWaitTime > 0 then
        -- Betting phase: send betting event first
        local bettingData = {
            squad1 = warData.squad1,
            squad2 = warData.squad2,
            duration = warData.duration,
            betWaitTime = betWaitTime,
            minBet = Config.MinBet or 100,
            maxBet = Config.MaxBet or 10000,
        }
        TriggerEventForMembers(challengerSquad, "warBettingPhase", bettingData)
        TriggerEventForMembers(mySquad, "warBettingPhase", bettingData)

        -- After betting time, start the actual war
        SetTimeout(betWaitTime * 1000, function()
            if Wars[warId] and Wars[warId].status == 'betting' then
                Wars[warId].status = 'active'
                Wars[warId].startTime = os.time()
                warData.startTime = Wars[warId].startTime
                local s1 = GetSquadById(request.from)
                local s2 = GetSquadById(mySquadId)
                if s1 then TriggerEventForMembers(s1, "warStarted", warData) end
                if s2 then TriggerEventForMembers(s2, "warStarted", warData) end
                StartWarTimer(warId)
            end
        end)
    else
        TriggerEventForMembers(challengerSquad, "warStarted", warData)
        TriggerEventForMembers(mySquad, "warStarted", warData)
        StartWarTimer(warId)
    end

    return true
end)

RegisterCallback('getWarStatus', function(source)
    local squadId = MySquad[source]
    if not squadId then return nil end

    local warId = SquadWar[squadId]
    if not warId then return nil end

    local war = Wars[warId]
    if not war then return nil end

    return {
        squad1 = war.squad1,
        squad2 = war.squad2,
        timeLeft = war.duration - (os.time() - war.startTime),
        duration = war.duration
    }
end)

RegisterCallback('getWarEnemyCoords', function(source)
    local squadId = MySquad[source]
    if not squadId then return {} end

    local warId = SquadWar[squadId]
    if not warId then return {} end

    local war = Wars[warId]
    if not war or war.status ~= 'active' then return {} end

    local enemySquadId = war.squad1.id == squadId and war.squad2.id or war.squad1.id
    local enemySquad = GetSquadById(enemySquadId)
    if not enemySquad then return {} end

    local enemies = {}
    for i = 1, #enemySquad.members do
        local member = enemySquad.members[i]
        local ped = GetPlayerPed(member.id)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            table.insert(enemies, {
                id = member.id,
                name = member.name,
                x = coords.x,
                y = coords.y,
                z = coords.z
            })
        end
    end

    return enemies
end)

-- =============================================
-- BETTING
-- =============================================

RegisterCallback('placeBet', function(source, amount)
    if not Config.BetEnabled then return false end

    amount = tonumber(amount)
    if not amount then return false end

    local squadId = MySquad[source]
    if not squadId then return false end

    local warId = SquadWar[squadId]
    if not warId then return false end

    local war = Wars[warId]
    if not war or war.status ~= 'betting' then return false end

    local identifier = GetIdentifier(source)
    if not identifier then return false end

    if WarBets[warId] and WarBets[warId][identifier] then return false end

    local minBet = Config.MinBet or 100
    local maxBet = Config.MaxBet or 10000
    if amount < minBet or amount > maxBet then return false end

    if not HasMoney(source, amount) then return false end

    RemoveMoney(source, amount)

    if not WarBets[warId] then WarBets[warId] = {} end
    WarBets[warId][identifier] = {
        amount = amount,
        squadId = squadId,
        source = source
    }

    return true
end)