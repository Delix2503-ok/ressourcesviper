fx_version 'adamant'
games { 'gta5' }
description 'thug-killfeed'
lua54 'yes'

shared_script 'config.lua'

client_scripts{
    'client/weapons.lua',
    'client/main.lua',
}

server_scripts{
    'server/*.lua',
}

ui_page 'html/index.html'

files {
    'html/**/*.*',
    'html/*.*',
    'html/libs/jquery.min.js',
    'html/libs/jquery-ui.min.js',
    'html/libs/anime.min.js',
}

escrow_ignore {
    'config.lua',
    'client/main.lua',
    'client/weapons.lua',
    'server/main.lua',
  }