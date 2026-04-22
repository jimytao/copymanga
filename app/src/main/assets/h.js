javascript:
if (typeof (loaded) == "undefined") {
    var loaded = true;
    function scanChapters(chapter) {
        var chapterList = chapter.getElementsByClassName("tab-pane fade show active")[0].getElementsByTagName("ul")[0].getElementsByTagName("a");
        var chapterArr = Array();
        for (var i = 0; i < chapterList.length; i++) {
            chapterArr.push({"name": chapterList[i].title, "url": chapterList[i].href});
        }
        return chapterArr;
    }
    function smoothLoadChapter(speed, interval) {
        var prevHeight = document.body.scrollHeight;
        var lastTime = 0;
        var ticking = false;
        var currentSpeed = speed;
        var prevUrlCount = 0;
        var speedAdjustCooldown = 0;
        var waitStartTime = 0;
        var MIN_SPEED = 200;
        var MAX_SPEED = 600;
        var SPEED_ADJUST_INTERVAL = 5;
        
        function requestTick() {
            if (!ticking) {
                ticking = true;
                requestAnimationFrame(step);
            }
        }
        function allDataSrcReady(contentEl) {
            var items = contentEl.getElementsByTagName("li");
            if (items.length === 0) return false;
            for (var i = 0; i < items.length; i++) {
                var img = items[i].getElementsByTagName("img")[0];
                if (img && !img.dataset.src) return false;
            }
            return true;
        }
        function countUrls(contentEl) {
            var items = contentEl.getElementsByTagName("li");
            var count = 0;
            for (var i = 0; i < items.length; i++) {
                var img = items[i].getElementsByTagName("img")[0];
                if (img && img.dataset.src) count++;
            }
            return count;
        }
        function step(timestamp) {
            try {
                if (!lastTime) lastTime = timestamp;
                var elapsed = timestamp - lastTime;
                if (elapsed >= interval) {
                    var comicCountEls = document.getElementsByClassName("comicCount");
                    var count = comicCountEls.length > 0 ? comicCountEls[0].innerText : "999";

                    window.scrollBy(0, currentSpeed);
                    lastTime = timestamp;
                    var currentHeight = document.body.scrollHeight;
                    var atBottom = Math.round(window.innerHeight+window.scrollY+0.5) >= currentHeight;

                    var contentEl = document.getElementsByClassName("container-fluid comicContent")[0];
                    var items = contentEl ? contentEl.getElementsByTagName("li") : [];
                    var totalCount = parseInt(count);
                    var hasTotalCount = !isNaN(totalCount) && totalCount > 0 && count !== "999";

                    var loadedCount = contentEl ? countUrls(contentEl) : 0;
                    if (typeof GM !== "undefined" && GM.setLoadingDialogProgress) {
                        GM.setLoadingDialogProgress(String(loadedCount), hasTotalCount ? count : String(items.length));
                    }

                    var isFullyLoaded = hasTotalCount && items.length > 0 && items.length >= totalCount && allDataSrcReady(contentEl);
                    
                    if (contentEl && speedAdjustCooldown <= 0) {
                        var urlCount = countUrls(contentEl);
                        var urlDelta = urlCount - prevUrlCount;
                        if (urlDelta === 0 && hasTotalCount && items.length < totalCount) {
                            currentSpeed = Math.max(MIN_SPEED, currentSpeed - 50);
                        } else if (urlDelta >= 3) {
                            currentSpeed = Math.min(MAX_SPEED, currentSpeed + 30);
                        }
                        prevUrlCount = urlCount;
                        speedAdjustCooldown = SPEED_ADJUST_INTERVAL;
                    }
                    speedAdjustCooldown--;

                    if (atBottom && currentHeight !== prevHeight) {
                        prevHeight = currentHeight;
                    }

                    var shouldFinish = false;
                    if (isFullyLoaded) {
                        shouldFinish = true;
                    } else if (!hasTotalCount && atBottom && allDataSrcReady(contentEl)) {
                        if (waitStartTime === 0) waitStartTime = timestamp;
                        if (timestamp - waitStartTime >= 500) {
                            waitStartTime = 0;
                            shouldFinish = true;
                        } else {
                            requestTick();
                            return;
                        }
                    } else {
                        waitStartTime = 0;
                    }

                    if (shouldFinish) {
                        var nextEl = document.getElementsByClassName("comicContent-next")[0];
                        var prevEl = document.getElementsByClassName("comicContent-prev")[1];
                        if (!contentEl || !nextEl || !prevEl) { 
                            if(typeof GM !== "undefined") GM.setLoadingDialog(false); 
                            return; 
                        }
                        var images = contentEl.getElementsByTagName("li");
                        var nextA = nextEl.getElementsByTagName("a")[0];
                        var prevA = prevEl.getElementsByTagName("a")[0];
                        var nextChapter = nextA && nextA.href ? nextA.href : location.href;
                        var prevChapter = prevA && prevA.href ? prevA.href : location.href;
                        if(nextChapter == location.href) nextChapter = "null";
                        if(prevChapter == location.href) prevChapter = "null";
                        var result = document.title.split(" - ")[1] + " " + location.href.substring(location.href.lastIndexOf("/")+1) + "\n" + nextChapter + "\n" + prevChapter;
                        for(var i = 0; i < images.length; i++) {
                            var img = images[i].getElementsByTagName("img")[0];
                            if (img && img.dataset.src) result += "\n" + img.dataset.src;
                        }
                        if(typeof GM !== "undefined") {
                            GM.setLoadingDialog(false);
                            GM.loadChapter(result);
                        }
                        return;
                    }
                }
                ticking = false;
                requestTick();
            } catch (e) {
                if(typeof GM !== "undefined") GM.setLoadingDialog(false);
            }
        }
        requestTick();
    }
    function modify() {
        var url = location.href;
        if(url.indexOf("/chapter/") > 0){
            if(typeof GM !== "undefined" && GM.setLoadingDialog) {
                GM.setLoadingDialog(true);
                var speed = 350;
                smoothLoadChapter(speed, 16);
            }
        } else {
            var json = Array();
            var chapters = document.getElementsByClassName("upLoop")[0].children;
            var newObj = null;
            for(var i = 0; i < chapters.length; i++) {
                if(i % 2) {
                    newObj["chapters"] = scanChapters(chapters[i]);
                    json.push(newObj);
                    newObj = null;
                }
                else {
                    newObj = {"name": chapters[i].innerText};
                }
            }
            GM.setTitle(document.getElementsByTagName("h6")[0].title);
            GM.setFab(JSON.stringify(json));
        }
    }
    modify();
} else {
    setTimeout(modify, 100);
}