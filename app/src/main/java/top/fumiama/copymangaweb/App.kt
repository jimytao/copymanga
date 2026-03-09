package top.fumiama.copymangaweb

import android.app.Application
import android.os.Handler
import android.os.Looper
import android.webkit.WebView

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        // 在主线程下一帧触发 WebView 进程预创建，避免 MainActivity 冷启动时的白屏等待
        Handler(Looper.getMainLooper()).post {
            WebView(applicationContext).destroy()
        }
    }
}
