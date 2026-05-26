fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'viper'
description 'TP Ramps + Zones Revive'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client/main.lua'

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'oxmysql',
    'qb-core',
    'ox_lib',
}
