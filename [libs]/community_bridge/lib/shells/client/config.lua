Shells = Shells or {}


--Data table
Shells.Targets = Shells.Targets or {
    ['entrance'] = {
        ['enter'] = {
            label = 'Enter',
            icon = 'fa-solid fa-door-open',
            onSelect = function(entity, shellId, objectId)
                TriggerServerEvent('community_bridge:server:EnterShell', shellId, objectId)
            end
        },
    },
    ['exit'] = {
        ['leave'] = {
            label = 'Exit',
            icon = 'fa-solid fa-door-closed',
            onSelect = function(entity, shellId, objectId)
                TriggerServerEvent('community_bridge:server:ExitShell', shellId, objectId)
            end
        }
    }
}

--Functions to set data table
Shells.Target = {
    Set = function(shellType, options)
        assert(shellType, "Shells.Target.Set: 'shellType' is required")
        options = options or {}
        for key, value in pairs(options) do
            if Shells.Targets[shellType] and Shells.Targets[shellType][key] then
                value.onSelect = Shells.Targets[shellType][key].onSelect
            end
            Shells.Targets[shellType] = Shells.Targets[shellType] or {}
            Shells.Targets[shellType][key] = value
        end
        return true
    end,
    Get = function(shellType, shellId, objectId)
        local aOptions = {}
        for key, value in pairs(Shells.Targets[shellType] or {}) do
            local onSelect = value.onSelect
            value.onSelect = function(entity)
                onSelect(entity, shellId, objectId)
            end
            table.insert(aOptions, value)
        end
        return aOptions
    end
}

return Shells