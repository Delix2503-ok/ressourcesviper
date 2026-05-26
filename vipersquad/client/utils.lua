--- A simple wrapper around SendNUIMessage that you can use to
--- dispatch actions to the React frame.
---
---@param action string The action you wish to target
---@param data any The data you wish to send along with this action
function SendReactMessage(action, data)
  SendNUIMessage({
    action = action,
    data = data
  })
end

local currentResourceName = GetCurrentResourceName()

local debugIsEnabled = GetConvarInt(('%s-debugMode'):format(currentResourceName), 0) == 1

--- A simple debug print function that is dependent on a convar
--- will output a nice prettfied message if debugMode is on
function debugPrint(...)
  if not debugIsEnabled then return end
  local args <const> = { ... }

  local appendStr = ''
  for _, v in ipairs(args) do
    appendStr = appendStr .. ' ' .. tostring(v)
  end
  local msgTemplate = '^3[%s]^0%s'
  local finalMsg = msgTemplate:format(currentResourceName, appendStr)
  print(finalMsg)
end

function TriggerCallback(name, ...)
  local id = GetRandomIntInRange(0, 999999)
  local eventName = currentResourceName..":triggerCallback:" .. id
  local eventHandler
  local promise = promise:new()
  RegisterNetEvent(eventName)
  local eventHandler = AddEventHandler(eventName, function(...)
      promise:resolve(...)
  end)

  SetTimeout(15000, function()
    promise:resolve("timeout")
    RemoveEventHandler(eventHandler)
  end)
  local args = {...}
  TriggerServerEvent(name, id, args)

  local result = Citizen.Await(promise)
  RemoveEventHandler(eventHandler)
  return result
end

function GetClosestPedToPlayer()
  local playerPed = PlayerPedId()
  local playerPos = GetEntityCoords(playerPed)
  local closestPed = nil
  local closestDistance = 1000.0
  local peds = GetGamePool('CPed')

  for k, ped in pairs(peds) do
    if ped ~= playerPed then
      local pedPos = GetEntityCoords(ped)
      local distance = #(playerPos - pedPos)
      if distance < closestDistance then
        closestPed = ped
        closestDistance = distance
      end
    end
  end

  return closestPed, closestDistance
end

function GetClosestVehicleToPlayer()
  local playerPed = PlayerPedId()
  local playerPos = GetEntityCoords(playerPed)
  local closestVehicle = nil
  local closestDistance = 1000.0
  local vehicles = GetGamePool('CVehicle')

  for k, vehicle in pairs(vehicles) do
    if vehicle ~= playerPed then
      local vehiclePos = GetEntityCoords(vehicle)
      local distance = #(playerPos - vehiclePos)
      if distance < closestDistance then
        closestVehicle = vehicle
        closestDistance = distance
      end
    end
  end
  
  return closestVehicle, closestDistance
end

---@param dict string The animation dictionary to load
function LoadAnimDict(dict)
  RequestAnimDict(dict)

  while not HasAnimDictLoaded(dict) do
    Wait(0)
  end
end

---@param dict string The model dictionary to load
function LoadObject(dict)
  RequestModel(dict)

  while not HasModelLoaded(dict) do
    Wait(0)
  end
end

---@param x number The x coordinate
---@param y number The y coordinate
---@param z number The z coordinate
---@param model string The model to create
---@param cb function The callback to run after the ped is created
function CreatePedOnCoord(x, y, z, model, cb)
  local pedModel = GetHashKey(model)
  RequestModel(pedModel)
  while not HasModelLoaded(pedModel) do
    Wait(0)
  end
  local ped = CreatePed(4, pedModel, x, y, z, 0.0, true, false)
  SetEntityAsMissionEntity(ped, true, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetModelAsNoLongerNeeded(pedModel)
  if cb then
    cb(ped)
  end
  return ped
end

---@param x number The x coordinate
---@param y number The y coordinate
---@param z number The z coordinate
---@param sprite number The sprite to use for the blip
---@param color number The color to use for the blip
---@param text string The text to display on the blip
function CreateBlipOnCoords(x, y, z, sprite, color, text)
  local blip = AddBlipForCoord(x, y, z)
  SetBlipSprite(blip, sprite)
  SetBlipColour(blip, color)
  SetBlipScale(blip, 0.8)
  SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(text)
  EndTextCommandSetBlipName(blip)
  return blip
end

---@param t table
function table_size(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

---@param x number The x coordinate
---@param y number The y coordinate
---@param z number The z coordinate
---@param text string The text to draw
function DrawText3D(x, y, z, text)
  local onScreen, _x, _y = World3dToScreen2d(x, y, z)

  if onScreen then
    SetTextScale(0.25, 0.25)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropShadow()
    SetTextDropshadow(0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)

    AddTextComponentString(text)
    DrawText(_x, _y)
  end
end

---@param text string The text to display
function ShowNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text)
  DrawNotification(false, false)
end

---@param entity number The entity to play the animation on
---@param dict string The animation dictionary
---@param anim string The animation to play
---@param cb function The callback to run after the animation is played
function PlayAnimationWithEntity(entity, dict, anim, cb)
  LoadAnimDict(dict)
  TaskPlayAnim(entity, dict, anim, 8.0, 8.0, -1, 1, 0, false, false, false)
  if cb then
    cb()
  end
end

function table_copy(t)
    local t2 = {}
    for k,v in pairs(t) do
        t2[k] = v
    end
    return t2
end

function ClearTableKeys(t)
    local t2 = {}

    for k, v in pairs(t) do
        table.insert(t2, v)
    end

    return t
end