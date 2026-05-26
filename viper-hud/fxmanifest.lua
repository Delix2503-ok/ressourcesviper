fx_version 'cerulean'
game 'gta5'

author 'ViperPVP'
description 'Viper HUD - HUD custom, panel admin, controles serveur'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/blips.lua',
    'client/admin.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/logo.png'
}

lua54 'yes'
