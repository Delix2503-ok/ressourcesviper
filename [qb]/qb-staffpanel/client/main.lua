local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local isStaff = false
local menuOpen = false
local currentTab = 'dashboard'
local selectedPlayer = nil
local selectedBusiness = nil
local serverStats = {}
local onlinePlayers = {}
local businesses = {}

-- Register key mapping
RegisterCommand(Config.KeyBind.Command, function()
    TriggerEvent('qb-staffpanel:client:ToggleMenu')
end, false)
RegisterKeyMapping(Config.KeyBind.Command, 'Open Staff Menu', 'keyboard', Config.KeyBind.OpenMenu)

-- Check staff permission
local function CheckStaffPermission()
    QBCore.Functions.TriggerCallback('qb-staffpanel:server:CheckPermission', function(result)
        isStaff = result
        if not isStaff then
            QBCore.Functions.Notify('No permission to access staff menu', 'error')
        end
    end)
end

-- Toggle menu
RegisterNetEvent('qb-staffpanel:client:ToggleMenu')
AddEventHandler('qb-staffpanel:client:ToggleMenu', function()
    if not isStaff then
        CheckStaffPermission()
        if not isStaff then return end
    end
    
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    SendNUIMessage({
        action = menuOpen and 'open' or 'close',
        data = {
            staffName = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname,
            staffRank = PlayerData.job.name .. ' - ' .. PlayerData.job.grade.name
        }
    })
    
    if menuOpen then
        TriggerEvent('qb-staffpanel:client:LoadDashboard')
    end
end)

-- Load dashboard data
RegisterNetEvent('qb-staffpanel:client:LoadDashboard')
AddEventHandler('qb-staffpanel:client:LoadDashboard', function()
    QBCore.Functions.TriggerCallback('qb-staffpanel:server:GetServerStats', function(stats)
        serverStats = stats
        SendNUIMessage({
            action = 'updateDashboard',
            data = serverStats
        })
    end)
end)

-- Load players list
RegisterNetEvent('qb-staffpanel:client:LoadPlayers')
AddEventHandler('qb-staffpanel:client:LoadPlayers', function()
    QBCore.Functions.TriggerCallback('qb-staffpanel:server:GetOnlinePlayers', function(players)
        onlinePlayers = players
        SendNUIMessage({
            action = 'updatePlayersList',
            data = onlinePlayers
        })
    end)
end)

-- Load player details
RegisterNetEvent('qb-staffpanel:client:LoadPlayerDetails')
AddEventHandler('qb-staffpanel:client:LoadPlayerDetails', function(playerId)
    selectedPlayer = playerId
    QBCore.Functions.TriggerCallback('qb-staffpanel:server:GetPlayerDetails', function(details)
        SendNUIMessage({
            action = 'updatePlayerDetails',
            data = details
        })
    end, playerId)
end)

-- Load businesses
RegisterNetEvent('qb-staffpanel:client:LoadBusinesses')
AddEventHandler('qb-staffpanel:client:LoadBusinesses', function()
    QBCore.Functions.TriggerCallback('qb-staffpanel:server:GetBusinesses', function(bizList)
        businesses = bizList
        SendNUIMessage({
            action = 'updateBusinessesList',
            data = businesses
        })
    end)
end)

-- NUI Callbacks
RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('changeTab', function(data, cb)
    currentTab = data.tab
    
    if currentTab == 'dashboard' then
        TriggerEvent('qb-staffpanel:client:LoadDashboard')
    elseif currentTab == 'players' then
        TriggerEvent('qb-staffpanel:client:LoadPlayers')
    elseif currentTab == 'business' then
        TriggerEvent('qb-staffpanel:client:LoadBusinesses')
    end
    
    cb('ok')
end)

RegisterNUICallback('selectPlayer', function(data, cb)
    TriggerEvent('qb-staffpanel:client:LoadPlayerDetails', data.playerId)
    cb('ok')
end)

RegisterNUICallback('selectBusiness', function(data, cb)
    selectedBusiness = data.businessId
    QBCore.Functions.TriggerCallback('qb-staffpanel:server:GetBusinessDetails', function(details)
        SendNUIMessage({
            action = 'updateBusinessDetails',
            data = details
        })
    end, data.businessId)
    cb('ok')
end)

RegisterNUICallback('giveMoney', function(data, cb)
    TriggerServerEvent('qb-staffpanel:server:GiveMoney', data.targetId, data.moneyType, data.amount)
    cb('ok')
end)

RegisterNUICallback('giveJob', function(data, cb)
    TriggerServerEvent('qb-staffpanel:server:GiveJob', data.targetId, data.jobName, data.jobGrade)
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    TriggerServerEvent('qb-staffpanel:server:GiveItem', data.targetId, data.itemName, data.amount)
    cb('ok')
end)

-- Player data handlers
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    CheckStaffPermission()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if menuOpen then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
end)