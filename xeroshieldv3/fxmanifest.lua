fx_version 'bodacious'

game 'gta5'
lua54 'yes'

ui_page "index.html"

server_script "server.js"
server_script 'server.lua'
client_script "client.lua"
file "init.lua"

files {
    "index.html",
    "style.css",
    "vendor.js",
    "script.js",
}

dependencies {
    "/onesync",
    "/server:5104",
}