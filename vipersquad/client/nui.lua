local isInfinityEnabled = false

function HudLoop()
    if not PersonalSettings.hudVisible then return end
    -- if not isInfinityEnabled then
        Citizen.CreateThread(function()
            while PersonalSettings.hudVisible and #SquadMembers > 0 do
                Citizen.Wait(200)
                for i = 1, #SquadMembers do
                    local ped = GetPlayerPed(SquadMembers[i].player)
                    if ped and ped ~= 0 and DoesEntityExist(ped) then
                        local health = GetEntityHealth(ped)
                        local maxHealth = GetEntityMaxHealth(ped) - 100
                        SquadMembers[i].health = math.floor(health - maxHealth)
                        SquadMembers[i].armor = GetPedArmour(ped)
                    end
                end
                SendReactMessage('setHudMembers', SquadMembers)
            end
        end)
    -- else
    --     Citizen.CreateThread(function()
    --         while PersonalSettings.hudVisible and #SquadMembers > 0 do
    --             Citizen.Wait(Config.HudInterval or 5000)
    --             local result = TriggerCallback('getHudData')
    --             if result then
    --                 SendReactMessage('setHudMembers', result)
    --             end
    --         end
    --     end)
    -- end
end

function SetSquadMembers(members)
    local newMembers = {}
    if not members then return {} end
    for _, v in pairs(members) do
        table.insert(newMembers, {
            id = v.id,
            name = v.name,
            player = GetPlayerFromServerId(v.id),
            image = v.image
        })
    end
    SquadMembers = newMembers
    if (#SquadMembers > 0) then
        HudLoop()
        StartNameLoop()
        AddSquadBlip()
    end
end

function AddSquadMember(data)
    table.insert(SquadMembers, {
        id = data.id,
        name = data.name,
        player = GetPlayerFromServerId(data.id),
        image = data.image
    })
end

function RemoveSquadMember(data)
    for i, v in pairs(SquadMembers) do
        if v.id == data then
            table.remove(SquadMembers, i)
            break
        end
    end
    RemoveGamerTags()
    RemoveSquadBlips(data)
end

RegisterNUICallback("getSquads", function(data, cb)
    local result = TriggerCallback("getSquads")
    cb(result)
end)

RegisterNUICallback("createSquad", function(data, cb)
    local result = TriggerCallback("createSquad", data)
    if not result or type(result) ~= "table" then
        cb(nil)
        return
    end
    cb(result.id)
    SetSquadMembers(result.members)
end)

RegisterNUICallback("getMembers", function(data, cb)
    local result = TriggerCallback("getMembers", data)
    if not result or type(result) ~= "table" then
        cb(nil)
        return
    end
    cb(result.members)
end)

RegisterNUICallback("getPlayers", function(data, cb)
    local result = TriggerCallback("getPlayers", data)
    cb(result)
end)

RegisterNUICallback("sendMessage", function(data, cb)
    local result = TriggerCallback("sendMessage", data)
end)

RegisterNUICallback("getMessages", function(data, cb)
    local result = TriggerCallback("getMessages", data)
    cb(result)
end)

RegisterNUICallback("joinSquad", function(data, cb)
    local result = TriggerCallback("joinSquad", data)
    cb(result)
    SetSquadMembers(result)
end)

RegisterNUICallback("leaveSquad", function(data, cb)
    local result = TriggerCallback("leaveSquad", data)
    cb(result)
    SquadMembers = {}
end)

RegisterNUICallback("checkSquadName", function(data, cb)
    local result = TriggerCallback("checkSquadName", data)
    cb(result)
end)

RegisterNUICallback("deleteSquad", function(data, cb)
    local result = TriggerCallback("deleteSquad", data)
    cb(result)
    SquadMembers = {}
end)

RegisterNUICallback("getInvites", function(data, cb)
    local result = TriggerCallback("getInvites", data)
    cb(result)
end)

RegisterNUICallback("removeInvite", function(data, cb)
    local result = TriggerCallback("removeInvite", data)
    cb(result)
end)

RegisterNUICallback('setPersonalSettings', function(data, cb)
    PersonalSettings = data

    if PersonalSettings.nametagsVisible == false then
        RemoveGamerTags()
    else
        StartNameLoop()
    end

    if PersonalSettings.blipsVisible == false then
        RemoveSquadBlips()
    else
        AddSquadBlip()
    end

    if PersonalSettings.hudVisible then
        HudLoop()
    end

    cb({})
end)

RegisterNUICallback('updateSquadSettings', function(data, cb)
    local result = TriggerCallback('updateSquadSettings', data)
    cb(result)
end)

RegisterNUICallback('getPlayerId', function(data, cb)
    cb(GetPlayerServerId(PlayerId()))
end)

RegisterNUICallback('inviteMember', function(data, cb)
    local result = TriggerCallback('inviteMember', data)
    cb(result)
end)

RegisterNUICallback('kickMember', function(data, cb)
    local result = TriggerCallback('kickMember', data)
    cb(result)
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    SetNewWaypoint(data.x, data.y)
    cb({})
end)

RegisterNUICallback('getSquadSettings', function(data, cb)
    local result = TriggerCallback('getSquadSettings', data)
    cb(result)
end)

RegisterNUICallback('getTheme', function(data, cb)
    cb(Config.Theme)
end)

RegisterNUICallback('getLeaderboard', function(data, cb)
    local result = TriggerCallback('getLeaderboard')
    cb(result)
end)

RegisterNUICallback('getWarTargets', function(data, cb)
    local result = TriggerCallback('getWarTargets')
    cb(result)
end)

RegisterNUICallback('challengeSquad', function(data, cb)
    local result = TriggerCallback('challengeSquad', data)
    cb(result)
end)

RegisterNUICallback('respondWar', function(data, cb)
    local result = TriggerCallback('respondWar', data)
    cb(result)
end)

RegisterNUICallback('getWarStatus', function(data, cb)
    local result = TriggerCallback('getWarStatus')
    cb(result)
end)

RegisterNUICallback('placeBet', function(data, cb)
    local result = TriggerCallback('placeBet', data)
    cb(result)
end)