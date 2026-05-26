fx_version 'cerulean'
game 'gta5'
author 'atiysu'
description 'Library for gfx scripts'
lua54 'yes'
version '1.2.0'
discord 'https://discord.gg/gfxscripts'

client_scripts {
    'client/bridge.lua',
    'client/modules.lua',
    'client/checker.lua',
}

server_scripts {
    'server/version.lua',
    'server/bridge.lua',
    'server/checker.lua',
    'server/modules.lua',
    'server/open.lua',
    'serverconfig.lua',
}

shared_scripts {
    'config.lua',
    'shared.lua',
}

escrow_ignore {
    'shared.lua',
    'config.lua',
    'serverconfig.lua',
}

dependency '/assetpacks'