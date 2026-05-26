var timerInterval    = null;
var lootAnimHandle   = null;
var reviveAnimHandle = null;
var deathEWaitInt    = null;
var voteTimerInt     = null;
var voteOptionsList  = [];
var voteHasVotedJS   = false;

window.addEventListener("message", function(e) {
    var data = e.data;
    switch (data.type) {
        case "display":      Display(data);                       break;
        case "update":       Update(data);                        break;
        case "timerUpdate":  StartTimer(data.seconds);            break;
        case "deathScreen":  showDeathScreen(data.totalSecs, data.reviveSecs); break;
        case "deathHide":    hideDeathScreen();                   break;
        case "deathEAvailable": showDeathEHint();                 break;
        case "deathTimerUpdate": updateDeathTimer(data.remaining); break;
        case "tpSelect":     showTpSelect(data.zones);            break;
        case "leaderboard":  showLeaderboard(data.rows);          break;
        case "lootStart":    showProgressBar("loot",   data.duration); break;
        case "lootCancel":   hideProgressBar("loot");             break;
        case "lootDone":     hideProgressBar("loot");             break;
        case "reviveStart":  showProgressBar("revive", data.duration); break;
        case "reviveCancel": hideProgressBar("revive");           break;
        case "reviveDone":   hideProgressBar("revive");           break;
        case "voteStart":    gfxVoteStart(data.options, data.duration); break;
        case "voteEnd":      gfxVoteEnd(data.winnerId, data.winnerName); break;
        case "voteUpdate":   gfxVoteUpdate(data.counts);          break;
        case "voteSelect":   gfxVoteSelect(data.index);           break;
        case "voteVoted":    gfxVoteMarkVoted(data.index);        break;
        case "voteHide":     document.getElementById("vote-panel").classList.add("hidden"); break;
        case "zonePicker":   openZonePicker(data.zones); break;
        default: break;
    }
});

function StartTimer(seconds) {
    clearInterval(timerInterval);
    var remaining = Math.max(0, Math.floor(seconds));
    UpdateTimerDisplay(remaining);
    timerInterval = setInterval(function() {
        remaining = Math.max(0, remaining - 1);
        UpdateTimerDisplay(remaining);
    }, 1000);
}

function UpdateTimerDisplay(seconds) {
    var mins = Math.floor(seconds / 60);
    var secs = seconds % 60;
    $(".zone-timer").html(mins + ":" + (secs < 10 ? "0" : "") + secs);
}

function Display(data) {
    if (data.bool) {
        $(".redzone-container").css("display", "flex");
        var leaderName  = (data.zone.leader && data.zone.leader.n) ? data.zone.leader.n : "—";
        var leaderKills = (data.zone.leader && data.zone.leader.k) ? data.zone.leader.k : 0;
        var myKills     = (data.zone.players && data.identifier && data.zone.players[data.identifier])
                          ? data.zone.players[data.identifier].k : 0;
        $(".leader-name").html(leaderName);
        $(".leader-kills").html(leaderKills);
        $(".total-kills").html(data.zone.totalKills || 0);
        $(".your-kills").html(myKills);
        $(".leaderboard-place").html(data.myRank !== "None" ? data.myRank + "." : "—");
    } else {
        $(".redzone-container").hide();
    }
}

// ── Barres de progression ──────────────────────────────────────────────────────

function showProgressBar(type, durationSecs) {
    var box  = document.getElementById(type + "-bar");
    var fill = document.getElementById(type + "-bar-fill");
    var pct  = document.getElementById(type + "-bar-pct");
    if (!box || !fill || !pct) return;
    if (type === "loot") {
        if (lootAnimHandle) { cancelAnimationFrame(lootAnimHandle); lootAnimHandle = null; }
    } else {
        if (reviveAnimHandle) { cancelAnimationFrame(reviveAnimHandle); reviveAnimHandle = null; }
    }
    box.classList.remove("hidden");
    fill.style.width = "0%";
    pct.textContent  = "0%";
    var start = performance.now();
    var dur   = durationSecs * 1000;
    function tick(now) {
        var progress = Math.min(100, ((now - start) / dur) * 100);
        fill.style.width = progress + "%";
        pct.textContent  = Math.floor(progress) + "%";
        if (progress < 100) {
            var handle = requestAnimationFrame(tick);
            if (type === "loot") lootAnimHandle = handle;
            else reviveAnimHandle = handle;
        } else {
            if (type === "loot") lootAnimHandle = null;
            else reviveAnimHandle = null;
        }
    }
    var h = requestAnimationFrame(tick);
    if (type === "loot") lootAnimHandle = h; else reviveAnimHandle = h;
}

function hideProgressBar(type) {
    if (type === "loot" && lootAnimHandle)     { cancelAnimationFrame(lootAnimHandle);   lootAnimHandle = null; }
    if (type === "revive" && reviveAnimHandle) { cancelAnimationFrame(reviveAnimHandle); reviveAnimHandle = null; }
    var box  = document.getElementById(type + "-bar");
    var fill = document.getElementById(type + "-bar-fill");
    var pct  = document.getElementById(type + "-bar-pct");
    if (box)  box.classList.add("hidden");
    if (fill) fill.style.width = "0%";
    if (pct)  pct.textContent  = "0%";
}

// ── Écran de mort / coma ───────────────────────────────────────────────────────

function showDeathScreen(totalSecs, reviveSecs) {
    document.getElementById("death-screen").classList.remove("hidden");
    document.getElementById("death-e-hint").classList.add("hidden");
    document.getElementById("death-e-wait").classList.remove("hidden");
    updateDeathTimer(totalSecs);
    var eWait = reviveSecs || 30;
    var el = document.getElementById("death-e-countdown");
    if (el) el.textContent = eWait;
    clearInterval(deathEWaitInt);
    deathEWaitInt = setInterval(function() {
        eWait--;
        if (el) el.textContent = Math.max(0, eWait);
        if (eWait <= 0) { clearInterval(deathEWaitInt); showDeathEHint(); }
    }, 1000);
}

function hideDeathScreen() {
    document.getElementById("death-screen").classList.add("hidden");
    clearInterval(deathEWaitInt);
}

function showDeathEHint() {
    document.getElementById("death-e-hint").classList.remove("hidden");
    document.getElementById("death-e-wait").classList.add("hidden");
}

function updateDeathTimer(remaining) {
    var el = document.getElementById("death-timer-val");
    if (!el) return;
    var mins = Math.floor(remaining / 60);
    var secs = remaining % 60;
    el.textContent = (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
}

// ── Leaderboard NUI ────────────────────────────────────────────────────────────

function showLeaderboard(rows) {
    var podium = document.getElementById('lb-podium');
    var list   = document.getElementById('lb-list');
    podium.innerHTML = '';
    list.innerHTML   = '';

    if (!rows || rows.length === 0) {
        list.innerHTML = '<div class="lb-empty">— AUCUN KILL ENREGISTRÉ —</div>';
        document.getElementById('leaderboard').classList.remove('hidden');
        return;
    }

    var medals  = ['🥇','🥈','🥉'];
    var classes = ['lb-pod-1','lb-pod-2','lb-pod-3'];
    var labels  = ['1ER','2ÈME','3ÈME'];

    rows.slice(0, 3).forEach(function(row, i) {
        var pod = document.createElement('div');
        pod.className = 'lb-pod ' + classes[i];
        pod.innerHTML =
            '<div class="lb-pod-medal">' + medals[i] + '</div>' +
            '<div class="lb-pod-rank">' + labels[i] + '</div>' +
            '<div class="lb-pod-name">' + row.player_name + '</div>' +
            '<div class="lb-pod-kills">' + row.kills + '</div>' +
            '<div class="lb-pod-kills-lbl">KILLS</div>';
        podium.appendChild(pod);
    });

    rows.slice(3).forEach(function(row, i) {
        var div = document.createElement('div');
        div.className = 'lb-row';
        div.innerHTML =
            '<span class="lb-rank">' + (i + 4) + '</span>' +
            '<span class="lb-name">' + row.player_name + '</span>' +
            '<span class="lb-kills">' + row.kills + '<small> kills</small></span>';
        list.appendChild(div);
    });

    document.getElementById('leaderboard').classList.remove('hidden');
}

function closeLeaderboard() {
    document.getElementById('leaderboard').classList.add('hidden');
    fetch('https://gfx-redzone/leaderboardClose', { method: 'POST', body: JSON.stringify({}) });
}

// ── Panel TP Safezone ──────────────────────────────────────────────────────────

function showTpSelect(zones) {
    var list = document.getElementById('tp-select-list');
    list.innerHTML = '';
    if (!zones || zones.length === 0) {
        list.innerHTML = '<div style="color:#666;font-family:\'Enigmatic\';font-size:11px;text-align:center;padding:10px;">Aucune safezone disponible</div>';
    } else {
        zones.forEach(function(z) {
            var btn = document.createElement('button');
            btn.className = 'tp-zone-btn';
            btn.textContent = z.name;
            btn.onclick = function() { tpToZone(z.id); };
            list.appendChild(btn);
        });
    }
    document.getElementById('tp-select').classList.remove('hidden');
}

function closeTpSelect() {
    document.getElementById('tp-select').classList.add('hidden');
    fetch('https://gfx-redzone/tpSelectClose', { method: 'POST', body: JSON.stringify({}) });
}

function tpToZone(id) {
    document.getElementById('tp-select').classList.add('hidden');
    fetch('https://gfx-redzone/tpToSafezone', { method: 'POST', body: JSON.stringify({ id: id }) });
}

// ── Zone Picker (admin) ───────────────────────────────────────────────────────

function openZonePicker(zones) {
    var grid = document.getElementById('zone-picker-grid');
    grid.innerHTML = '';
    zones.forEach(function(z) {
        var btn = document.createElement('button');
        btn.className = 'zp-btn';
        btn.innerHTML = '<span class="zp-btn-num">' + z.index + '</span>' + escHtml(z.name);
        btn.onclick = function() { pickZone(z.index); };
        grid.appendChild(btn);
    });
    document.getElementById('zone-picker').classList.remove('hidden');
}

function closeZonePicker() {
    document.getElementById('zone-picker').classList.add('hidden');
    fetch('https://gfx-redzone/zonePickerClose', { method: 'POST', body: JSON.stringify({}) });
}

function pickZone(index) {
    document.getElementById('zone-picker').classList.add('hidden');
    fetch('https://gfx-redzone/zonePickerSelect', { method: 'POST', body: JSON.stringify({ index: index }) });
}

// ── Fonctions redzone HUD ─────────────────────────────────────────────────────

function Update(data) {
    var leaderName  = (data.zone.leader && data.zone.leader.n) ? data.zone.leader.n : "—";
    var leaderKills = (data.zone.leader && data.zone.leader.k) ? data.zone.leader.k : 0;
    var myKills     = (data.zone.players && data.identifier && data.zone.players[data.identifier])
                      ? data.zone.players[data.identifier].k : 0;
    $(".leader-name").html(leaderName);
    $(".leader-kills").html(leaderKills);
    $(".total-kills").html(data.zone.totalKills || 0);
    $(".your-kills").html(myKills);
    $(".leaderboard-place").html(data.myRank !== "None" ? data.myRank + "." : "—");
}

// ── Vote prochaine zone ────────────────────────────────────────────────────────

function gfxVoteStart(options, duration) {
    voteOptionsList  = options;
    voteHasVotedJS   = false;
    var container = document.getElementById("gfx-vote-options");
    container.innerHTML = "";
    options.forEach(function(opt, i) {
        var card = document.createElement("div");
        card.className = "gfx-vote-card" + (i === 0 ? " vote-selected" : "");
        card.id = "gfx-vote-card-" + i;
        card.innerHTML =
            '<div class="gfx-vote-card-name">' + escHtml(opt.name) + '</div>' +
            '<div class="gfx-vote-card-votes" id="gfx-vote-votes-' + opt.id + '">0 vote</div>' +
            '<div class="gfx-vote-card-bar-bg"><div class="gfx-vote-card-bar" id="gfx-vote-bar-' + opt.id + '"></div></div>';
        card.onclick = function() {
            if (voteHasVotedJS) return;
            voteHasVotedJS = true;
            document.querySelectorAll(".gfx-vote-card").forEach(function(c, j) {
                c.classList.toggle("vote-voted", j === i);
            });
            var hint = document.getElementById("gfx-vote-hint");
            if (hint) hint.textContent = "✓ Vote enregistré !";
            fetch('https://gfx-redzone/voteSubmit', { method: 'POST', body: JSON.stringify({ id: opt.id }) });
        };
        container.appendChild(card);
    });
    document.getElementById("gfx-vote-result").classList.add("hidden");
    document.getElementById("gfx-vote-hint").textContent = "← → naviguer • ENTRÉE voter";
    document.getElementById("vote-panel").classList.remove("hidden");
    var remaining = duration;
    var timerEl   = document.getElementById("gfx-vote-timer");
    timerEl.textContent = remaining;
    clearInterval(voteTimerInt);
    voteTimerInt = setInterval(function() {
        remaining--;
        if (timerEl) timerEl.textContent = Math.max(0, remaining);
        if (remaining <= 0) clearInterval(voteTimerInt);
    }, 1000);
}

function gfxVoteSelect(index) {
    document.querySelectorAll(".gfx-vote-card").forEach(function(card, i) {
        card.classList.toggle("vote-selected", i === index);
    });
}

function gfxVoteMarkVoted(index) {
    voteHasVotedJS = true;
    document.querySelectorAll(".gfx-vote-card").forEach(function(card, i) {
        if (i === index) card.classList.add("vote-voted");
    });
    var hint = document.getElementById("gfx-vote-hint");
    if (hint) hint.textContent = "✓ Vote enregistré !";
}

function gfxVoteUpdate(counts) {
    if (!voteOptionsList) return;
    var total = 0;
    for (var k in counts) total += counts[k];
    voteOptionsList.forEach(function(opt) {
        var count = counts[opt.id] || counts[String(opt.id)] || 0;
        var pct   = total > 0 ? (count / total * 100) : 0;
        var el  = document.getElementById("gfx-vote-votes-" + opt.id);
        var bar = document.getElementById("gfx-vote-bar-"   + opt.id);
        if (el)  el.textContent  = count + " vote" + (count !== 1 ? "s" : "");
        if (bar) bar.style.width = pct + "%";
    });
}

function gfxVoteEnd(winnerId, winnerName) {
    clearInterval(voteTimerInt);
    document.querySelectorAll(".gfx-vote-card").forEach(function(card, i) {
        var opt = voteOptionsList[i];
        if (!opt) return;
        card.classList.toggle("vote-winner", opt.id === winnerId);
        card.classList.toggle("vote-loser",  opt.id !== winnerId);
    });
    var result = document.getElementById("gfx-vote-result");
    result.innerHTML = "&#127942; Prochaine zone : <strong>" + escHtml(winnerName || "?") + "</strong>";
    result.classList.remove("hidden");
}

function escHtml(str) {
    if (!str) return "";
    return String(str).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
}
