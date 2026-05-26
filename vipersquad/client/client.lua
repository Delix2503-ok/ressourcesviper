PersonalSettings = {
  hudVisible = true,
  nametagsVisible = true,
  blipsVisible = true,
  hudAlignment = "left"
}

SquadMembers = {}
IsInWar = false

local function toggleNuiFrame(shouldShow)
  SetNuiFocus(shouldShow, shouldShow)
  SendReactMessage('setVisible', shouldShow)
end

CreateThread(function()
  TriggerServerEvent("gfx-squad:playerLoaded")
end)
RegisterCommand('squad', function()
  
  toggleNuiFrame(true)
  debugPrint('Show NUI frame')
end)

RegisterNUICallback('hideFrame', function(_, cb)
  toggleNuiFrame(false)
  debugPrint('Hide NUI frame')
  cb({})
end)

RegisterNUICallback("getSquadSettings", function(data, cb)
  local result = TriggerCallback("getSquadSettings", data)
  cb(result)
end)

RegisterNetEvent('newMessage', function(data)
  data.me = data.id == GetPlayerServerId(PlayerId())
  SendReactMessage('sendMessage', data)
end)

RegisterNetEvent('updateMembers', function(data)
  if data.id == GetPlayerServerId(PlayerId()) then
    return
  end
  SendReactMessage('updateMembers', data)
  AddSquadMember(data)
  RemoveSquadBlips()
  AddSquadBlip()
end)

RegisterNetEvent('memberGone', function(data)
  if data == GetPlayerServerId(PlayerId()) then
    return
  end
  SendReactMessage('removeMember', data)
  RemoveSquadMember(data)
  RemoveSquadBlips(data)
end)

RegisterNetEvent('squadDeleted', function()
  SendReactMessage('squadDeleted')
  SquadMembers = {}
  RemoveSquadBlips()
  RemoveGamerTags()
  TriggerEvent("gfx-squad:RemoveRelationShip")
end)

RegisterNetEvent('setInviteCount', function(count)
  SendReactMessage('setInviteCount', count)
end)

RegisterNetEvent('kicked', function()
  SquadMembers = {}
  RemoveGamerTags()
  RemoveSquadBlips()
  TriggerEvent("gfx-squad:RemoveRelationShip")
  SendReactMessage('kicked')
end)

RegisterNetEvent("gfx-squad:updateUnseenCount", function()
  SendReactMessage('updateUnseenCount')
end)

RegisterCommand('cm', function()
  SendReactMessage('updateUnseenCount')
end)

-- Kill detection (uses IsEntityDead instead of unreliable args[4] flag)
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]

        if attacker == PlayerPedId() and victim ~= attacker then
            if IsEntityAPed(victim) and IsPedAPlayer(victim) and IsEntityDead(victim) then
                local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
                if victimPlayer and victimPlayer ~= -1 then
                    local victimServerId = GetPlayerServerId(victimPlayer)
                    if victimServerId > 0 then
                        TriggerServerEvent('gfx-squad:onPlayerKill', victimServerId)
                    end
                end
            end
        end
    end
end)

-- War events
RegisterNetEvent('warChallenge', function(data)
    SendReactMessage('warChallenge', data)
end)

RegisterNetEvent('warBettingPhase', function(data)
    SendReactMessage('warBettingPhase', data)
end)

RegisterNetEvent('warStarted', function(data)
    IsInWar = true
    SendReactMessage('warStarted', data)
end)

RegisterNetEvent('warScoreUpdate', function(data)
    SendReactMessage('warScoreUpdate', data)
end)

RegisterNetEvent('warEnded', function(data)
    IsInWar = false
    RemoveWarBlips()
    SendReactMessage('warEnded', data)
end)

RegisterNetEvent('warDeclined', function()
    SendReactMessage('warDeclined', true)
end)

RegisterNetEvent('leaderboardUpdate', function()
    SendReactMessage('leaderboardUpdate', true)
end)