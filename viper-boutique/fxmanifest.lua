fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Viper'
description 'Viper Boutique — Système ViperCoins'
version '1.0.0'

shared_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/aa.png',
    'html/images/aaa.png',
    'html/images/dbm323.png',
}
