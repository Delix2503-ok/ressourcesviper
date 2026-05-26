shared = {
    SetFuel = function(vehicle, fuel)
		local fuel = type(fuel) == "number" and fuel or tonumber(fuel)

        if GetResourceState("LegacyFuel") == "started" then
            exports["LegacyFuel"]:SetFuel(vehicle, fuel)
        elseif GetResourceState("ox_fuel") == "starting" then
            Entity(vehicle).state.fuel = fuel
        elseif GetResourceState("lc_fuel") == "starting" then
            exports['lc_fuel']:SetFuel(vehicle, fuel)
        elseif GetResourceState("sna-fuel") == "starting" or GetResourceState("esx-sna-fuel") == "starting" then
            exports['esx-sna-fuel']:SetFuel(vehicle, fuel)
        elseif GetResourceState("okokGasStation") == "starting" then
            exports['okokGasStation']:SetFuel(vehicle, fuel)
        elseif GetResourceState("ti_fuel") == "starting" then
            exports['ti_fuel']:setFuel(vehicle, fuel)
        elseif GetResourceState("cdn-fuel") == "starting" then
            exports['cdn-fuel']:SetFuel(vehicle, fuel)
        elseif GetResourceState("ps-fuel") == "starting" then
            exports['ps-fuel']:SetFuel(vehicle, fuel)
        else
            SetVehicleFuelLevel(vehicle, fuel)
        end
    end,

    GetFuel = function(vehicle)
		if GetResourceState("LegacyFuel") == "started" then
			return exports["LegacyFuel"]:GetFuel(vehicle)
		elseif GetResourceState("ox_fuel") == "starting" then
			return Entity(vehicle).state.fuel
		else
			return GetVehicleFuelLevel(vehicle)
		end
    end,

	Notify = function(msg, type, source)
		if GetResourceState("qb-core") == "started" then
            if source then TriggerClientEvent("QBCore:Notify", source, msg, type) else TriggerEvent("QBCore:Notify", msg, type) end
        elseif GetResourceState("es_extended") == "started" then
            if source then TriggerClientEvent("esx:showNotification", source, msg) else TriggerEvent("esx:showNotification", msg) end
        elseif GetResourceState("okokNotify") == "started" then
            if not source then    exports['okokNotify']:Alert('Notification', msg, 6000, type or 'info')
            else TriggerClientEvent('okokNotify:Alert', source, 'Notification', msg, 6000, type or 'info') end
        elseif GetResourceState("infinity-notify") == "started" then
            if not source then TriggerEvent('infinity-notify:sendNotify', msg, type)
            else TriggerClientEvent('infinity-notify:sendNotify', source, msg, type) end
        elseif GetResourceState("ox_lib") == "started" then
            if not source then    exports.ox_lib:notify({description = msg, type = type or "success"})
            else TriggerClientEvent('ox_lib:notify', source, { type = type or "success", description = msg }) end
        elseif GetResourceState("t-notify") == "started" then
            if not source then exports['t-notify']:Custom({title = 'Notification', style = type, message = msg, sound = true})
            else TriggerClientEvent('t-notify:client:Custom', source, { style = type, duration = 6000, title = title, message = msg, sound = true, custom = true}) end
        else
            print(msg)
        end
	end,

	RemoveKeyExport = function(plate, model)
        if GetResourceState("qb-vehiclekeys") == "started" then
            exports['qs-vehiclekeys']:RemoveKeys(plate, model)
        elseif GetResourceState("okokGarage") == "started" then
            TriggerServerEvent("okokGarage:RemoveKeys", plate, GetPlayerServerId(PlayerId()))
        elseif GetResourceState("Renewed") == "started" then
            exports['Renewed-Vehiclekeys']:removeKey(plate)
        elseif GetResourceState("wasabi_carlock") == "started" then
            exports['wasabi_carlock']:RemoveKey(plate)
		end
    end,

    KeyExport = function(vehicle, plate)
       if GetResourceState("qb-vehiclekeys") == "started" then
            TriggerEvent("vehiclekeys:client:SetOwner", plate)
        elseif GetResourceState("okokGarage") == "started" then
            TriggerServerEvent("okokGarage:GiveKeys", plate)
        elseif GetResourceState("tgiann-hotwire") == "started" then
            exports["tgiann-hotwire"]:SetNonRemoveableIgnition(vehicle, true)
        elseif GetResourceState("qs-vehiclekeys") == "started" then
            exports['qs-vehiclekeys']:GiveKeys(plate, vehicle)
        elseif GetResourceState("cd_garage") == "started" then
            TriggerEvent('cd_garage:AddKeys', plate)
        elseif GetResourceState("Renewed") == "started" then
            exports['Renewed-Vehiclekeys']:addKey(plate)
        elseif GetResourceState("wasabi_carlock") == "started" then
            exports['wasabi_carlock']:GiveKey(plate)
        end
    end
}

function getShared()
    return shared
end
exports('getShared', getShared)