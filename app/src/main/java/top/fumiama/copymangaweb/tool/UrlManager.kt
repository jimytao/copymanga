package top.fumiama.copymangaweb.tool

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

object UrlManager {
    // 候选域名列表：大陆无障碍地址优先，其余按优先级排列
    val candidates = listOf(
        "https://www.2026copy.com",
        "https://www.copy20.com",
        "https://www.mangacopy.com",
    )

    /** 允许的 URL 前缀：候选域名 + 去掉 www 的变体，覆盖站点跨域跳转 */
    val allowedPrefixes: List<String> by lazy {
        candidates + candidates.map { it.replace("://www.", "://") }
    }

    private const val PREF_NAME = "url_manager"
    private const val KEY_ACTIVE_URL = "active_url"
    private const val TAG = "UrlManager"

    /** 当前使用的根 URL，例如 "https://www.copy20.com" */
    var activeUrl: String = candidates[0]
        private set

    /** 对应 /comic 详情页 PC 端前缀 */
    val comicDetailUrl: String get() = "$activeUrl/comic"

    /** 从 SharedPreferences 读取上次缓存的 URL；未命中则保持 candidates[0] */
    fun init(context: Context) {
        val cached = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ACTIVE_URL, null)
        if (cached != null) {
            activeUrl = cached
            Log.d(TAG, "init: loaded cached url = $activeUrl")
        }
    }

    /** 是否已有缓存 URL（用于区分首次启动） */
    fun hasCachedUrl(context: Context): Boolean =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .contains(KEY_ACTIVE_URL)

    /**
     * 并发探测所有候选地址，选取响应最快的一个。
     * 结果写入 SharedPreferences 并更新 [activeUrl]。
     * 必须在协程中调用（IO dispatcher 友好）。
     */
    suspend fun probe(context: Context): String = coroutineScope {
        Log.d(TAG, "probe: start, candidates = $candidates")
        val results = candidates.map { url ->
            async(Dispatchers.IO) {
                val start = System.currentTimeMillis()
                try {
                    (URL("$url/favicon.ico").openConnection() as HttpURLConnection).apply {
                        requestMethod = "HEAD"
                        connectTimeout = 3000
                        readTimeout = 3000
                        connect()
                        disconnect()
                    }
                    val latency = System.currentTimeMillis() - start
                    Log.d(TAG, "probe: $url OK ${latency}ms")
                    url to latency
                } catch (e: Exception) {
                    Log.d(TAG, "probe: $url FAIL ${e.message}")
                    url to Long.MAX_VALUE
                }
            }
        }.map { it.await() }

        val best = results
            .filter { it.second < Long.MAX_VALUE }
            .minByOrNull { it.second }
            ?.first
            ?: candidates[0]

        withContext(Dispatchers.Main) {
            activeUrl = best
        }
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit().putString(KEY_ACTIVE_URL, best).apply()
        Log.d(TAG, "probe: best = $best")
        best
    }

    /**
     * 当前 URL 连接失败时调用：清除缓存，下次 [init] 时会重新探测。
     */
    fun markCurrentFailed(context: Context) {
        Log.d(TAG, "markCurrentFailed: clearing cached url")
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit().remove(KEY_ACTIVE_URL).apply()
    }
}
