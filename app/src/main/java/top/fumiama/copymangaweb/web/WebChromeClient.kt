package top.fumiama.copymangaweb.web

import android.net.Uri
import android.webkit.JsPromptResult
import android.webkit.JsResult
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import top.fumiama.copymangaweb.activity.MainActivity.Companion.wm

class WebChromeClient:WebChromeClient() {
    private fun isDarkMode(context: android.content.Context) = context.getSharedPreferences("app_settings", android.content.Context.MODE_PRIVATE)
        .getBoolean("dark_mode", false)

    private val darkModeJs = "(function(){var e=document.getElementById('_dk');if(!e){e=document.createElement('style');e.id='_dk';(document.head||document.documentElement).appendChild(e);}e.textContent='html{filter:invert(1) hue-rotate(180deg)!important;background-color:#fff!important}img,video{filter:invert(1) hue-rotate(180deg)!important}'})();"

    override fun onProgressChanged(view: WebView?, newProgress: Int) {
        super.onProgressChanged(view, newProgress)
        val context = view?.context ?: return
        wm?.get()?.updateLoadProgress(newProgress)
        
        if (newProgress > 2 && isDarkMode(context)) {
            view.evaluateJavascript(darkModeJs, null)
        }
    }

    override fun onJsAlert(
        view: WebView?,
        url: String?,
        message: String?,
        result: JsResult?
    ): Boolean {
        result?.confirm()
        return true
    }

    override fun onJsPrompt(
        view: WebView?,
        url: String?,
        message: String?,
        defaultValue: String?,
        result: JsPromptResult?
    ): Boolean {
        result?.confirm()
        return true
    }

    override fun onJsConfirm(
        view: WebView?,
        url: String?,
        message: String?,
        result: JsResult?
    ): Boolean {
        result?.confirm()
        return true
    }

    override fun onShowFileChooser(
        webView: WebView?,
        filePathCallback: ValueCallback<Array<Uri>>?,
        fileChooserParams: FileChooserParams?
    ): Boolean {
        wm?.get()?.apply {
            uploadMessageAboveL = filePathCallback
            openImageChooserActivity()
        }
        return true
    }
}