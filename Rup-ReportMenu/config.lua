Config = {}

Config.Debug = false
Config.DebugPrint = false

-- Language
Config.Language = { -- en, es
    Default = 'en',
}

-- Permissions
Config.Permissions = {
    -- Admin
    'reportmenu.admin.view',
    'reportmenu.admin.manage',
    'reportmenu.admin.delete',
    -- Mod
    'reportmenu.mod.view',
    'reportmenu.mod.manage',
}

-- Cooldowns
Config.Cooldowns = {
    Chat = 5000,    -- 5 seconds
    Report = 10000, -- 10 seconds
    Theme = 10000   -- 10 seconds
}

-- Discord Webhook
Config.Discord = {
    Enabled = true,
    -- Salon "nouveaux reports"
    Webhook = 'https://discord.com/api/webhooks/1502962149151084636/rMl4DbmDiY8fK56ZZM_Qu8gjfiCyFBjRS-gbses0I_TOI92wGUqikmMCauo9n_dN4JuD',
    -- Salon "transcripts / suppressions"
    TranscriptWebhook = 'https://discord.com/api/webhooks/1502962927940927488/h5_OA0R7xhs8ZJrS0CgwFgK3dD10oUNV1ehzAxW4yCxGtzQXPKeWvIYqigI5IcVwmDdb',
    ImageUrl = 'https://i.imgur.com/Ny3nszg.png',
    ReportEmbedColor = 16711680, -- Rouge (suppression)
    CreateEmebedColor = 65280,   -- Vert (nouveau report)
}

-- FiveManage API
Config.FiveManage = {
    ApiKey = "YOUR_API_KEY",  -- Replace with your actual API key (https://fivemanage.com/)
    DeleteMedia = true,       -- Delete media files after report deletion
}