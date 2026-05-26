$(".hideoverlay .bind").html(Config.CustomBindText == "" ? String.fromCharCode(Config.HideoverlayKeybind).toUpperCase() : Config.CustomBindText)

var overlay = true;
$(document).keydown(function(e) {
    if(e.which == Config.HideoverlayKeybind) {
        overlay = !overlay;
        if(!overlay) {
            $(".overlay").css("opacity", ".0")
        } else {
            $(".overlay").css("opacity", "")
        }
    }
})

$(document).ready(function () {
    const socialsDiv = $('.socials');
    socialsDiv.empty();

    const socials = {
        discord: {
            icon: 'fab fa-discord',
            link: Config.socials.discord
        },
        tiktok: {
            icon: 'fab fa-tiktok',
            link: Config.socials.tiktok
        },
        instagram: {
            icon: 'fab fa-instagram',
            link: Config.socials.instagram
        }
    };

    for (const key in socials) {
        const social = socials[key];

        const anchor = $(`
            <a href="${social.link}" target="_blank" rel="noopener noreferrer">
                <i class="${social.icon}"></i>
            </a>
        `);

        anchor.on('click', function (e) {
            e.preventDefault();
            window.invokeNative('openUrl', social.link);
        });

        socialsDiv.append(anchor);
    }
});

function setup() {
    fetch("http://" + Config.ServerIP + "/info.json", { method: "GET", mode: "cors" }).then(res => {
        if (!res.ok) {
            throw new Error("Network response was not ok");
        }
        return res.json();
    }).then(info => {
        if (typeof info.vars !== "undefined" && typeof info.vars.sv_maxClients !== "undefined") {
            fetch("http://" + Config.ServerIP + "/players.json", { method: "GET", mode: "cors" }).then(res => {
                if (!res.ok) {
                    throw new Error("Network response was not ok");
                }
                return res.json();
            }).then(players => {
                if (Array.isArray(players)) {
                    $("#clients").text(players.length + "/" + info.vars.sv_maxClients);
                } else {
                    console.error("Invalid players data format");
                }
            }).catch(error => {
                console.error("There was a problem fetching players data: ", error);
            });
        } else {
            console.error("Invalid info data format");
        }
    }).catch(error => {
        console.error("There was a problem fetching server info: ", error);
    });
}

var song = new Audio("assets/media/" + Config.Song);
song.play();

var muted = false;
let interval;
$('#sounds').on("change", function(){
    muted = !muted;
    clearInterval(interval);
    if(muted) {
        let volume = 1.0;
        interval = setInterval(() => {
            if(volume > 0.05) {
                volume -= 0.02;
                song.volume = Math.max(0, volume);
            } else {
                clearInterval(interval);
                song.volume = 0.0;
            }
        }, 10);
    } else {
        let volume = 0.0;
        interval = setInterval(() => {
            if(volume < 1.0) {
                volume += 0.02;
                song.volume = Math.min(1.0, volume);
            } else {
                clearInterval(interval);
                song.volume = 1.0;
            }
        }, 10);
    }
});

function loadProgress(progress) {
    $(".loader .progress-bar").css("width", progress + "%");
    const progressText = document.createElement('span');
    progressText.textContent = progress + "%";
    $(".loader .progress").empty().append(progressText);
}

window.addEventListener('message', function(e) {
    if(e.data.eventName === 'loadProgress') {
        loadProgress(parseInt(e.data.loadFraction * 100));
    }
});

document.addEventListener('DOMContentLoaded', () => {
    document.documentElement.style.setProperty('--main-color', Config.rgbColor);
});

function copyToClipboard(text) {
    const body = document.querySelector('body');
    const area = document.createElement('textarea');
    body.appendChild(area);
  
    area.value = text;
    area.select();
    document.execCommand('copy');
  
    body.removeChild(area);
}

setup();