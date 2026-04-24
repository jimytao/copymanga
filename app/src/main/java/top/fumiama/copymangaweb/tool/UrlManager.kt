package top.fumiama.copymangaweb.tool

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.net.HttpURLConnection
import java.net.URL

object UrlManager {
    val candidates = listOf(
        "https://www.2026copy.com",
        "https://www.copy20.com",
        "https://www.mangacopy.com",
    )

    val allowedPrefixes: List<String> by lazy {
        candidates + candidates.map { it.replace("://www.", "://") }
    }

    private const val PREF_NAME = "url_manager"
    private const val KEY_ACTIVE_URL = "active_url"
    private const val KEY_LAST_PROBE_SUMMARY = "last_probe_summary"
    private const val KEY_LAST_LOADING_PROFILE = "last_loading_profile"
    private const val KEY_MANUAL_OVERRIDE_URL = "manual_override_url"
    private const val TAG = "UrlManager"

    data class SourceDescriptor(
        val url: String,
        val title: String,
        val note: String,
    )

    data class ProbeMetrics(
        val faviconMs: Long,
        val rank: Int,
        val success: Boolean,
    )

    data class ProbeResult(
        val bestUrl: String,
        val bestMetrics: ProbeMetrics,
        val metricsByUrl: Map<String, ProbeMetrics>,
    )

    private val descriptors = listOf(
        SourceDescriptor("https://www.2026copy.com", "2026copy", "中国大陆推荐"),
        SourceDescriptor("https://www.copy20.com", "copy20", "国际线路"),
        SourceDescriptor("https://www.mangacopy.com", "mangacopy", "国际线路"),
    )

    var activeUrl: String = candidates[0]
        private set

    val comicDetailUrl: String get() = "$activeUrl/comic"

    fun init(context: Context) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val manual = prefs.getString(KEY_MANUAL_OVERRIDE_URL, null)
        val cached = manual ?: prefs.getString(KEY_ACTIVE_URL, null)
        if (cached != null) {
            activeUrl = cached
            Log.d(TAG, "init: loaded cached url = $activeUrl")
        }
        if (!prefs.contains(KEY_LAST_LOADING_PROFILE)) {
            prefs.edit().putString(KEY_LAST_LOADING_PROFILE, normalProfile()).apply()
        }
    }

    fun hasCachedUrl(context: Context): Boolean =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .contains(KEY_ACTIVE_URL)

    fun getLastProbeSummary(context: Context): String =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LAST_PROBE_SUMMARY, "") ?: ""

    fun getLoadingProfile(context: Context): String =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LAST_LOADING_PROFILE, normalProfile())
            ?: normalProfile()

    fun isManualOverrideEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .contains(KEY_MANUAL_OVERRIDE_URL)

    fun getManualOverrideUrl(context: Context): String? =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getString(KEY_MANUAL_OVERRIDE_URL, null)

    fun getSourceDescriptors(): List<SourceDescriptor> = descriptors

    fun getDisplayName(url: String): String {
        val descriptor = descriptors.firstOrNull { it.url == url }
        return if (descriptor != null) "${descriptor.title}（${descriptor.note}）" else url
    }

    fun formatSourceLine(url: String, metrics: ProbeMetrics?, selected: Boolean): String {
        val prefix = if (selected) "当前使用" else "候选"
        if (metrics == null || !metrics.success) return "$prefix ${getDisplayName(url)} 排名=不可用 主页=FAIL"
        return "$prefix ${getDisplayName(url)} 排名=${metrics.rank} 主页=${displayMs(metrics.faviconMs)}"
    }

    fun setManualOverride(context: Context, url: String) {
        activeUrl = url
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_MANUAL_OVERRIDE_URL, url)
            .apply()
    }

    fun setManualLoadingProfile(context: Context, profile: String) {
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_LOADING_PROFILE, profile)
            .apply()
    }

    fun clearManualOverride(context: Context) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_MANUAL_OVERRIDE_URL).apply()
        activeUrl = prefs.getString(KEY_ACTIVE_URL, candidates[0]) ?: candidates[0]
    }

    fun buildInjectedConfigScript(context: Context): String {
        val profile = getLoadingProfile(context)
        return "window.__CM_SOURCE_PROFILE='" + profile + "';window.__CM_ACTIVE_URL='" + activeUrl + "';"
    }

    suspend fun probeDetailed(context: Context): ProbeResult = coroutineScope {
        Log.d(TAG, "probe: start, candidates = $candidates")
        val rawResults = candidates.map { url ->
            async(Dispatchers.IO) {
                url to measureSource(url)
            }
        }.map { it.await() }
        val ranked = rawResults.sortedWith(
            compareBy<Pair<String, ProbeMetrics>> { !it.second.success }
                .thenBy { if (it.second.success) it.second.faviconMs else Long.MAX_VALUE }
        ).mapIndexed { index, pair ->
            pair.first to pair.second.copy(rank = if (pair.second.success) index + 1 else 0)
        }

        val best = ranked
            .filter { it.second.success }
            .minByOrNull { it.second.rank }
            ?: (candidates[0] to ProbeMetrics(Long.MAX_VALUE, 0, false))

        val summary = buildSummary(best.first, ranked.toMap())

        withContext(Dispatchers.Main) {
            activeUrl = best.first
        }
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ACTIVE_URL, best.first)
            .putString(KEY_LAST_PROBE_SUMMARY, summary)
            .remove(KEY_MANUAL_OVERRIDE_URL)
            .apply()
        Log.d(TAG, "probe: best = ${best.first}")
        ProbeResult(
            bestUrl = best.first,
            bestMetrics = best.second,
            metricsByUrl = ranked.toMap(),
        )
    }

    suspend fun inspectSources(context: Context): ProbeResult = coroutineScope {
        Log.d(TAG, "inspect: start, candidates = $candidates")
        val rawResults = candidates.map { url ->
            async(Dispatchers.IO) {
                url to measureSource(url)
            }
        }.map { it.await() }
        val ranked = rawResults.sortedWith(
            compareBy<Pair<String, ProbeMetrics>> { !it.second.success }
                .thenBy { if (it.second.success) it.second.faviconMs else Long.MAX_VALUE }
        ).mapIndexed { index, pair ->
            pair.first to pair.second.copy(rank = if (pair.second.success) index + 1 else 0)
        }
        val current = activeUrl
        val currentMetrics = ranked.toMap()[current] ?: ProbeMetrics(Long.MAX_VALUE, 0, false)
        ProbeResult(
            bestUrl = current,
            bestMetrics = currentMetrics,
            metricsByUrl = ranked.toMap(),
        )
    }

    suspend fun probe(context: Context): String = probeDetailed(context).bestUrl

    fun markCurrentFailed(context: Context) {
        Log.d(TAG, "markCurrentFailed: clearing cached url")
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit().remove(KEY_ACTIVE_URL).apply()
    }

    private fun measureSource(url: String): ProbeMetrics {
        val faviconMs = probeEndpoint("$url/favicon.ico", "HEAD")
        val success = faviconMs < Long.MAX_VALUE
        Log.d(TAG, "probe: $url favicon=${displayMs(faviconMs)}")
        return ProbeMetrics(
            faviconMs = faviconMs,
            rank = 0,
            success = success,
        )
    }

    private fun probeEndpoint(target: String, method: String): Long {
        val start = System.currentTimeMillis()
        return try {
            (URL(target).openConnection() as HttpURLConnection).run {
                requestMethod = method
                instanceFollowRedirects = true
                connectTimeout = 3000
                readTimeout = 3000
                setRequestProperty("User-Agent", "Mozilla/5.0")
                connect()
                if (method == "GET") {
                    BufferedInputStream(inputStream).use { input ->
                        val buffer = ByteArray(256)
                        input.read(buffer)
                    }
                }
                disconnect()
            }
            System.currentTimeMillis() - start
        } catch (e: Exception) {
            Long.MAX_VALUE
        }
    }

    private fun normalProfile(): String = "normal"

    private fun buildSummary(bestUrl: String, metricsByUrl: Map<String, ProbeMetrics>): String {
        val header = if (metricsByUrl[bestUrl] != null)
            formatSourceLine(bestUrl, metricsByUrl[bestUrl], true)
        else
            "当前使用 ${getDisplayName(bestUrl)}"
        val details = candidates.joinToString("\n") { url ->
            if (url == bestUrl) return@joinToString header
            val metrics = metricsByUrl[url]
            if (metrics == null) formatSourceLine(url, null, false)
            else formatSourceLine(url, metrics, false)
        }
        return details
    }

    private fun displayMs(value: Long): String {
        return if (value >= Long.MAX_VALUE) "FAIL" else "${value}ms"
    }
}
