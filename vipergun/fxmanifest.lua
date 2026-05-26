fx_version 'cerulean'
game 'gta5'

name 'vipergun'
description 'Viper Gun System - Chests, attachments'
version '1.0.0'
author 'Viper PvP'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/ped.lua',
    'client/coffres.lua',
    'client/admin.lua',
    'client/attachments.lua',
    'client/quickdraw.lua',
    'client/movement.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/coffres.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/logo.png',
    'html/images/**',
}

dependencies {
    'qb-core',
    'ox_inventory',
    'ox_lib',
    'oxmysql',
}
