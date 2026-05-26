fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Viper'
description 'Viper Shop — Vendeur Armes & Munitions'
version '1.0.0'

shared_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
}
