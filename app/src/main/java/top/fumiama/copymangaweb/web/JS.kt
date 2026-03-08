package top.fumiama.copymangaweb.web

import android.util.Log
import android.webkit.JavascriptInterface
import top.fumiama.copymangaweb.activity.MainActivity.Companion.wm
import top.fumiama.copymangaweb.tool.UrlManager

class JS {
    @JavascriptInterface
    fun loadComic(url: String) {
        val base = UrlManager.comicDetailUrl
        val u = when {
            url.contains("/details/comic/") -> "$base${url.substringAfter("comic")}"
            url.contains("/comicContent/") -> "$base/${url.substringAfter("comicContent/").substringBefore("/")}/chapter/${url.substringAfterLast("/")}"
            else -> ""
        }
        Log.d("MyJS", "Load comic: $u")
        wm?.get()?.loadHiddenUrl(u)
    }
    @JavascriptInterface
    fun hideFab() {
        wm?.get()?.hideFab()
    }
    @JavascriptInterface
    fun enterProfile(){
        wm?.get()?.setFab2DlList()
    }
    @JavascriptInterface
    fun openSettings() { wm?.get()?.openSettings() }
}