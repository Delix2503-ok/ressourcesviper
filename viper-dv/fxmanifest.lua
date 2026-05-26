fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Viper'
description 'Viper DV — Suppression automatique + zones parking admin'
version '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

shared_scripts {
    'config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua',
}
