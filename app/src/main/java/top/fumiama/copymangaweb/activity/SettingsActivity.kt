package top.fumiama.copymangaweb.activity

import android.app.Activity
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
        tvActiveUrl.text = "当前：${UrlManager.activeUrl}"
        findViewById<Button>(R.id.btn_probe_url).setOnClickListener {
            tvActiveUrl.text = "检测中，请稍候…"
            it.isEnabled = false
            scope.launch {
                val best = withContext(Dispatchers.IO) { UrlManager.probe(this@SettingsActivity) }
                tvActiveUrl.text = "当前：$best"
                it.isEnabled = true
                // 通知主界面重新加载
                MainActivity.wm?.get()?.loadHiddenUrl(best)
                Toast.makeText(this@SettingsActivity, "已切换至 $best", Toast.LENGTH_SHORT).show()
            }
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
}
