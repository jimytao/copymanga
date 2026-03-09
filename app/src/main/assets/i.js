javascript:
if (typeof (loaded) == "undefined") {
    var loaded = true;
    var invoke = {
        preUrl: "",
        hideRanobeTab: function () {
            var tabs = document.getElementsByClassName("van-tabbar-item");
            for (i = 0; i < tabs.length; i++) {
                if (tabs[i].innerText == "輕小說") tabs[i].style = "display: none;";
            }
        },
        hideRanobeRack: function () {
            var tabs = document.getElementsByClassName("van-tabs van-tabs--line");
            if (tabs.length) tabs[0].hidden = true;
        },
        pinTitle: function () {
            var game = document.getElementsByName("exchange");
            if (game.length) game[0].hidden = true;
        },
        notCallGM: function (url) {
            if (this.preUrl == url) return false;
            else {
                this.preUrl = url;
                return true;
            }
        },
        clickClass: function (name, index) { document.getElementsByClassName(name)[index].click(); },
        clickClassCenter: function (name, index) {
            var ev = document.createEvent('HTMLEvents');
            ev.clientX = innerWidth / 2;
            ev.clientY = innerHeight / 2;
            ev.initEvent('click', false, true);
            document.getElementsByClassName(name)[index].dispatchEvent(ev);
        },
        resetPreUrl: function () { this.preUrl = ""; },
        loadChapter: function () { this.clickClassCenter("comicContentPopupImageItem", 0); GM.loadComic(location.href); },
        injectAppSettings: function () {
            if (document.getElementById('_app_cfg')) return;
            var cell = document.createElement('div');
            cell.id = '_app_cfg';
            cell.style.cssText = 'display:flex;align-items:center;min-height:44px;padding:10px 16px;background:#fff;border-bottom:1px solid #ebedf0;cursor:pointer;';
            cell.innerHTML = '<span style="flex:1;font-size:14px;color:#323233;">&#9881; App扩展设置</span><span style="color:#969799;font-size:18px;">&#8250;</span>';
            cell.onclick = function () { GM.openSettings(); };
            var target = document.querySelector('.van-cell-group') ||
                document.querySelector('.van-list') ||
                document.querySelector('main') ||
                document.body;
            target.insertAdjacentElement('afterbegin', cell);
        },
        urlChangeListener: function (todo) {
            setInterval(function () { if (invoke.notCallGM(location.href)) { todo(); } }, 1000);
        }
    };
    function modify() {
        var url = location.href;
        GM.hideFab();
        GM.hideSettingsFab();
        if (url.endsWith("/index")) {
            invoke.pinTitle();
        }
        else if (url.indexOf("/comicContent/") > 0) setTimeout(function () { invoke.loadChapter() }, 1000);
        else if (url.indexOf("/details/comic/") > 0) GM.loadComic(url);
        else if (url.indexOf("/personal") > 0) {
            GM.enterProfile();
            setTimeout(function () { invoke.injectAppSettings(); }, 1200);
        }
    }
    modify();
    invoke.urlChangeListener(modify);
} else {
    setTimeout(modify, 1280);
}