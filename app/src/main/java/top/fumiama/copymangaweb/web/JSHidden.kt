package top.fumiama.copymangaweb.web

import android.webkit.JavascriptInterface
import top.fumiama.copymangaweb.activity.DlActivity
import top.fumiama.copymangaweb.activity.MainActivity.Companion.mh
import top.fumiama.copymangaweb.activity.MainActivity.Companion.wm
import top.fumiama.copymangaweb.handler.MainHandler

class JSHidden {
    @JavascriptInterface
    fun loadChapter(listString: String){
        wm?.get()?.callViewManga(listString)
    }
    @JavascriptInterface
    fun setTitle(title:String){
        DlActivity.comicName = title
    }
    @JavascriptInterface
    fun setFab(content: String){
        val ma = wm?.get() ?: return
        if (!ma.isPrefetching) ma.setFab(content)
    }
    @JavascriptInterface
    fun setLoadingDialog(display: Boolean) {
        if (wm?.get()?.isPrefetching == true) return
        mh?.sendEmptyMessage(if (display) MainHandler.SHOW_LOADING_DIALOG else MainHandler.HIDE_LOADING_DIALOG)
    }
    @JavascriptInterface
    fun setLoadingDialogProgress(index: String, count: String) {
        if (wm?.get()?.isPrefetching == true) return
        mh?.obtainMessage(MainHandler.SET_LOADING_DIALOG_TEXT, "$index/$count")?.sendToTarget()
    }
}