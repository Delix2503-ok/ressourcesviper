fx_version 'cerulean'
game 'gta5'

author 'ViperDev'
description 'Viper Ranked 1v1/2v2/3v3 System'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/queue.lua',
    'server/match.lua',
    'server/shop.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*.png',
    'html/img/*.PNG',
    'html/img/*.gif',
}

dependencies {
    'qb-core',
    'oxmysql',
    'ox_lib',
    'ox_inventory',
}
