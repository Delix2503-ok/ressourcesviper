webhooks = {
    reviveheal = 'Webhook_Here',
    spawnvehicle = 'Webhook_Here',
    kickban = 'Webhook_Here',
    gotobring = 'Webhook_Here',
    setjob = 'Webhook_Here',
    givedelitem = 'Webhook_Here',
    giveremovevehicle = 'Webhook_Here',
    giveremovemoney = 'Webhook_Here',
    delplayer = 'Webhook_Here',
    unbanplayer = 'Webhook_Here',
    admins = 'Webhook_Here',
}

function SendWebhook(url, desc, target)
    if not url or url == "" then 
        return 
    end

    local src = target or source

    local rawName    = GetPlayerName(src) or ("ID "..src)
    local triggerName = string.format("%s *(%d)*", string.upper(rawName), src)

    local description = string.format(
      "**Admin:** %s\n**Action:**  %s",
      triggerName,
      desc
    )

    local embed = {
        title       = "__Ft Script's Bot__",
        url         = "https://ftscripts.tebex.io/",
        description = description,
        color       = 0x00aeff,
        footer = {
            text     = "Ft Script's Bot",
            icon_url = "https://i.ibb.co/3ybjh6t3/FT-SCRIPTS-LOGO.png"
        },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = {
        username   = "Ft Script's Bot",
        avatar_url = "https://i.ibb.co/3ybjh6t3/FT-SCRIPTS-LOGO.png",
        embeds     = { embed },
    }

    PerformHttpRequest(url, function(err, text)
        if err == 204 then
            print("^2[Webhook] Sent successfully.^7")
        else
            print(("^1[Webhook] Failed (HTTP %s): %s^7"):format(err, text))
        end
    end, "POST", json.encode(payload), {
        ["Content-Type"] = "application/json"
    })
end
