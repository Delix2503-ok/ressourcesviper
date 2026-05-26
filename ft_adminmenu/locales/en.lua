
Locales = {}
local lang = 'en'

Locales["en"] = {
    other = {
        DUTY = "~r~🛡️STAFF DUTY",
        Staff = "Staff",
        Open = "Open the admin menu",
    },
    notify = {
        title = "Admin Menu",

        -- Client Side
        reports_pending = "You already have reports pending.",
        healed = "You have been healed!",
        revived = "You have been revived.",
        model = "Invalid vehicle model.",
        spawned = "Vehicle spawned by admin",
        deleted = "Vehicle deleted.",
        vehicle = "No vehicle found.",
        clipboard = "Coordinates copied to clipboard.",
        feature = "This feature will be available in FT Scripts Admin Menu V2.",
        support = "Contact support in Ft-Script's to get help on this issue.",
        nopermission = "You don't have permission",

        -- Server Side
        permission = "You do not have permission to use this command.",
        submitted = "Report submitted. Thank you!",
        New_report = "📩 New report received from %s [%s]",
        Set_job = "Set job of ID %s to %s [grade %s]",
        set_your_job = "An admin set your job to %s [grade %s]",
        Invalid = "Invalid target player.",
        healed = "You have been healed by an admin.",
        Player_healed = "Player healed.",
        Invalid_ID = "Invalid player ID.",
        not_found = "Player not found",
        License_not_found = "License not found",
        unbanned = "Player unbanned successfully.",
        Item_not_exist = "Item '%s' does not exist.",
        Gave_to = "Gave %sx %s to %s",
        You_received = "You received %sx %s from admin",
        Vehicle_not_exist = "Vehicle model '%s' does not exist.",
        Gave_vehicle = "Gave vehicle '%s' (%s) to %s",
        received_plate = "You received a %s with plate %s",
        Invalid_money = "Invalid money type.",
        enough_cash = "Player doesn't have enough cash.",
        enough_bank = "Player doesn't have enough bank balance.",
        already_admin = "⚠️ %s is already an admin.",
        Added_admin = "✅ Added admin: %s",
        Failed_add_admin = "❌ Failed to add admin: %s",
        been_revived = "You have been revived by an admin.",
        Player_revived = "Player revived.",
        been_warned = "You have been warned by an admin.",
        warned = "Player has been warned.",
        were_kicked = "You were kicked by an admin.",
        kicked = "Player has been kicked.",
        brought = "Player brought to you.",
        were_brought = "You were brought by an admin.",
        teleported = "You teleported to the player.",
        not_found = "Player not found or offline.",
        give_vehicle = "Failed to give vehicle (DB error)",
        Invalid_data = "❌ Invalid admin data",
    },
}
















function L(key)
    local value = Locales[lang]
    for k in key:gmatch("[^.]+") do
        value = value[k]

        if not value then
            print("Missing locale for: " .. key)
            return ""
        end
    end
    return value
end