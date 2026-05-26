
while GetCurrentResourceName() ~= "jraxion_handlingeditor" do
    Wait(2000)
    print("Make sure the resource name is jraxion_handlingeditor, it will break the resource if you rename it.")
end

RegisterNUICallback('saveHandling', function(data, cb)
    local vehicle = tostring(data.vehicle or 'unknown'):gsub('[^%w_%-]', '_')
    local filename = 'exports/' .. vehicle .. '.meta'
    SaveResourceFile(GetCurrentResourceName(), filename, data.xml, -1)
    print(('[HandlingEditor] Fichier sauvegardé : %s'):format(filename))
    cb('ok')
end)

RegisterCommand('handlingeditor', function(source, args, rawCommand)
    -- Add your permission system here.

    if Config.isAllowed(source) then
        TriggerClientEvent('jraxion_handlingeditor:openHandlingEditor', source)
    else
        print('No permission')
    end
end, false)
