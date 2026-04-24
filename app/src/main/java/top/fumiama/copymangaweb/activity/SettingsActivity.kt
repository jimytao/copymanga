package top.fumiama.copymangaweb.activity

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle
import android.widget.Button
import android.widget.CompoundButton
import android.widget.ImageButton
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.tool.PropertiesTools
import top.fumiama.copymangaweb.tool.UrlManager
import java.io.File

@Suppress("DEPRECATION")
class SettingsActivity : Activity() {

    private lateinit var prefs: android.content.SharedPreferences
    private lateinit var p: PropertiesTools
    private val scope: CoroutineScope = MainScope()

    override fun onCreate(savedInstanceState: Bundle?) {
        prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
        if (prefs.getBoolean("dark_mode", false)) {
            setTheme(android.R.style.Theme_DeviceDefault_NoActionBar)
        }
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        p = PropertiesTools(File("$filesDir/settings.properties"))

        findViewById<ImageButton>(R.id.btn_back).setOnClickListener { finish() }

        // 夜间模式
        val swDark = findViewById<Switch>(R.id.sw_dark_mode)
        swDark.isChecked = prefs.getBoolean("dark_mode", false)
        swDark.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener { _, on ->
            prefs.edit().putBoolean("dark_mode", on).apply()
            MainActivity.wm?.get()?.applyDarkMode(on)
            recreate()
        })

        // 隐藏状态栏
        val swStatus = findViewById<Switch>(R.id.sw_hide_statusbar)
        swStatus.isChecked = prefs.getBoolean("hide_status_bar", false)
        swStatus.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener { _, on ->
            prefs.edit().putBoolean("hide_status_bar", on).apply()
            MainActivity.wm?.get()?.setStatusBarHidden(on)
        })

        // 清理缓存
        val tvCacheHint = findViewById<TextView>(R.id.tv_cache_hint)
        tvCacheHint.text = getCacheSizeText()
        findViewById<Button>(R.id.btn_clear_cache).setOnClickListener {
            MainActivity.wm?.get()?.let { ma ->
                ma.mBinding.w.clearCache(true)
                ma.mBinding.wh.clearCache(true)
            }
            cacheDir.deleteRecursively()
            cacheDir.mkdirs()
            tvCacheHint.text = "已清理完成（0 B）"
            Toast.makeText(this, "缓存已清理", Toast.LENGTH_SHORT).show()
        }

        // 显示页码
        val swPageNum = findViewById<Switch>(R.id.sw_show_page_num)
        swPageNum.isChecked = p["showPageNum"] != "false"
        swPageNum.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener { _, on ->
            p["showPageNum"] = if (on) "true" else "false"
        })

        // 网络 - 服务器检测
        val tvActiveUrl = findViewById<TextView>(R.id.tv_active_url)
        val tvSourceHint = findViewById<TextView>(R.id.tv_source_hint)
        val tvProfileHint = findViewById<TextView>(R.id.tv_profile_hint)
        tvActiveUrl.text = buildUrlSummary()
        tvSourceHint.text = buildSourceHint()
        tvProfileHint.text = buildProfileHint()
        findViewById<Button>(R.id.btn_probe_url).setOnClickListener {
            tvActiveUrl.text = "检测中，请稍候…"
            it.isEnabled = false
            scope.launch {
                val result = withContext(Dispatchers.IO) { UrlManager.probeDetailed(this@SettingsActivity) }
                val best = result.bestUrl
                tvActiveUrl.text = buildUrlSummary()
                tvSourceHint.text = buildSourceHint()
                tvProfileHint.text = buildProfileHint()
                it.isEnabled = true
                MainActivity.wm?.get()?.let { ma ->
                    ma.mBinding.w.post { ma.mBinding.w.loadUrl(best) }
                    ma.mBinding.wh.post { ma.mBinding.wh.loadUrl(best) }
                }
                Toast.makeText(
                    this@SettingsActivity,
                    "已切换至 ${UrlManager.getDisplayName(best)}",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
        findViewById<Button>(R.id.btn_choose_url).setOnClickListener {
            tvSourceHint.text = "正在读取各源主页延迟与排序…"
            scope.launch {
                val result = withContext(Dispatchers.IO) { UrlManager.inspectSources(this@SettingsActivity) }
                showSourceChooser(tvActiveUrl, tvSourceHint, result)
            }
        }
        findViewById<Button>(R.id.btn_choose_profile).setOnClickListener {
            showProfileChooser(tvProfileHint)
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun getCacheSizeText(): String {
        val bytes = cacheDir.walkTopDown().filter { it.isFile }.sumOf { it.length() }
        return when {
            bytes > 1024 * 1024 -> "当前缓存约 %.1f MB，点击清理".format(bytes / 1024.0 / 1024.0)
            bytes > 1024 -> "当前缓存约 %.1f KB，点击清理".format(bytes / 1024.0)
            else -> "当前缓存约 ${bytes} B，点击清理"
        }
    }

    private fun buildUrlSummary(): String {
        val summary = UrlManager.getLastProbeSummary(this)
        return if (summary.isNotBlank()) summary else "当前：${UrlManager.getDisplayName(UrlManager.activeUrl)}（${UrlManager.getLoadingProfile(this)}）"
    }

    private fun buildSourceHint(): String {
        return if (UrlManager.isManualOverrideEnabled(this)) {
            "当前为手动模式；服务器由你指定，自动检测不会在下次启动时替你换源"
        } else {
            "当前为自动模式；检测仅按主页延迟从快到慢排序，并自动选择第一名"
        }
    }

    private fun buildProfileHint(): String {
        val profile = UrlManager.getLoadingProfile(this)
        return if (profile == "conservative") {
            "当前挡位：conservative。滚动更保守、更稳，适合慢源或卡顿时手动切换"
        } else {
            "当前挡位：normal。滚动更积极，适合大多数速度正常的源"
        }
    }

    private fun showSourceChooser(
        tvActiveUrl: TextView,
        tvSourceHint: TextView,
        result: UrlManager.ProbeResult,
    ) {
        val descriptors = UrlManager.getSourceDescriptors()
        val entries = descriptors.map { descriptor ->
            UrlManager.formatSourceLine(
                descriptor.url,
                result.metricsByUrl[descriptor.url],
                descriptor.url == UrlManager.activeUrl,
            )
        }.toMutableList()
        entries.add("恢复自动选择（保留当前测速结果）")
        AlertDialog.Builder(this)
            .setTitle("选择服务器")
            .setItems(entries.toTypedArray()) { _, which ->
                if (which >= descriptors.size) {
                    UrlManager.clearManualOverride(this)
                    tvActiveUrl.text = buildUrlSummary()
                    tvSourceHint.text = buildSourceHint()
                    Toast.makeText(this, "已恢复自动模式", Toast.LENGTH_SHORT).show()
                    return@setItems
                }
                val selected = descriptors[which]
                UrlManager.setManualOverride(this, selected.url)
                tvActiveUrl.text = buildUrlSummary()
                tvSourceHint.text = buildSourceHint()
                MainActivity.wm?.get()?.let { ma ->
                    ma.mBinding.w.post { ma.mBinding.w.loadUrl(selected.url) }
                    ma.mBinding.wh.post { ma.mBinding.wh.loadUrl(selected.url) }
                }
                Toast.makeText(this, "已手动切换至 ${selected.title}", Toast.LENGTH_SHORT).show()
            }
            .show()
    }

    private fun showProfileChooser(tvProfileHint: TextView) {
        val profiles = arrayOf(
            "normal：滚动更快，适合大多数情况",
            "conservative：滚动更稳，适合慢源或卡顿时",
        )
        AlertDialog.Builder(this)
            .setTitle("选择加载挡位")
            .setItems(profiles) { _, which ->
                val selected = if (which == 1) "conservative" else "normal"
                UrlManager.setManualLoadingProfile(this, selected)
                tvProfileHint.text = buildProfileHint()
                Toast.makeText(this, "已切换到 $selected 挡位", Toast.LENGTH_SHORT).show()
            }
            .show()
    }
}
