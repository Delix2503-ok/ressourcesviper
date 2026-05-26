'use strict';

window.addEventListener('message', function(e) {
    var d = e.data;
    if (!d || d.action !== 'showDamageNumber') return;

    var el       = document.createElement('div');
    var isHead   = !!d.isHeadshot;

    el.className  = 'dmg ' + (isHead ? 'headshot' : 'body');
    el.textContent = String(Math.floor(d.damage));
    el.style.left  = (d.x * 100) + '%';
    el.style.top   = (d.y * 100) + '%';

    document.body.appendChild(el);

    el.addEventListener('animationend', function() {
        if (el.parentNode) el.parentNode.removeChild(el);
    });
});
