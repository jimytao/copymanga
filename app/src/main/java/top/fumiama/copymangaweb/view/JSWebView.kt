package top.fumiama.copymangaweb.view

import android.annotation.SuppressLint
import android.content.Context
import android.util.AttributeSet
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import top.fumiama.copymangaweb.web.WebViewClient

@SuppressLint("JavascriptInterface", "SetJavaScriptEnabled")
class JSWebView : WebView {
    constructor(context: Context): super(context)
    constructor(context: Context, attributeSet: AttributeSet): super(context, attributeSet)
    constructor(context: Context, attributeSet: AttributeSet, defSA: Int): super(context, attributeSet, defSA)
    constructor(context: Context, UA: String) : super(context) { settings.userAgentString = UA }
    init {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        val enableCache = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
            .getBoolean("enable_cache", true)
        settings.cacheMode = if (enableCache) WebSettings.LOAD_DEFAULT else WebSettings.LOAD_NO_CACHE
    }
    fun setWebViewClient(jsFileName: String){webViewClient = WebViewClient(context, jsFileName)}
    fun loadJSInterface(obj: Any){addJavascriptInterface(obj, "GM")}

    fun applyDarkMode(enabled: Boolean) {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
            WebSettingsCompat.setForceDark(settings, if (enabled) WebSettingsCompat.FORCE_DARK_ON else WebSettingsCompat.FORCE_DARK_OFF)
        }
        // 使用该策略可以确保在 CSS 注入前，浏览器引擎就尝试以深色渲染
        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK_STRATEGY)) {
            WebSettingsCompat.setForceDarkStrategy(settings, WebSettingsCompat.DARK_STRATEGY_USER_AGENT_DARKENING_ONLY)
        }
        setBackgroundColor(if (enabled) android.graphics.Color.BLACK else android.graphics.Color.WHITE)
    }
}