fx_version 'cerulean'
game 'gta5'

client_scripts {
    "config.lua",
    'client/blipMapInfo.lua',
    'client/client_shared.lua',
    'client/client.lua',
    'client/death.lua',
    'client/safezone.lua',
}

server_scripts {
    "config.lua",
    'server/server_shared.lua',
    "server/server.lua",
    'server/death.lua',
    'server/safezone.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/index.css',
    'html/index.js',
    'html/assets/images/*.png',
    'html/assets/fonts/*.TTF',
    'html/assets/fonts/*.OTF',
}

lua54 'yes'