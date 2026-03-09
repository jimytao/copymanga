package top.fumiama.copymangaweb.web

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.activity.MainActivity.Companion.wm
import top.fumiama.copymangaweb.tool.UrlManager

class WebViewClient(private val context: Context, jsFileName: String):WebViewClient() {
    private val js = context.assets.open(jsFileName).readBytes().decodeToString()
    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        super.onPageStarted(view, url, favicon)
        Log.d("MyWC", "Load URL: $url")
        url?.let {
            // 允许所有已知候选域名及其无 www 变体，防止站点跨域跳转被误拦截
            val allowed = UrlManager.allowedPrefixes.any { prefix -> it.startsWith(prefix) }
            if (!allowed) {
                // 有历史时回退，无历史时留在当前页避免白屏
                if (view?.canGoBack() == true) view.goBack()
                Toast.makeText(context, R.string.blocked_ad, Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        wm?.get()?.lifecycleScope?.launch {
            withContext(Dispatchers.IO) {
                delay(500)
                withContext(Dispatchers.Main) {
                    view?.loadUrl(js)
                    if (context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
                            .getBoolean("dark_mode", false)) {
                        view?.loadUrl("javascript:(function(){var e=document.getElementById('_dk');if(!e){e=document.createElement('style');e.id='_dk';document.head.appendChild(e);}e.textContent='html{filter:invert(1) hue-rotate(180deg)!important}img,video{filter:invert(1) hue-rotate(180deg)!important}'})();")
                    }
                    Log.d("MyWC", "Inject JS into: $url")
                    super.onPageFinished(view, url)
                }
            }
        }
    }

    override fun shouldInterceptRequest(
        view: WebView?,
        request: WebResourceRequest?
    ): WebResourceResponse? {
        request?.requestHeaders?.set("Access-Control-Allow-Origin", "*")
        return super.shouldInterceptRequest(view, request)
    }
}