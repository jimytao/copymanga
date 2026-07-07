package top.fumiama.copymangaweb

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.WebView

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DOWNLOAD_CHANNEL_ID,
                "下载通知",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "漫画章节下载完成提醒" }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
        // 在主线程下一帧触发 WebView 进程预创建，避免 MainActivity 冷启动时的白屏等待
        Handler(Looper.getMainLooper()).post {
            WebView(applicationContext).destroy()
        }
    }

    companion object {
        const val DOWNLOAD_CHANNEL_ID = "download_complete"
        const val DOWNLOAD_NOTIFICATION_ID = 1001
    }
}
