package top.fumiama.copymangaweb.activity

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.CompoundButton
import android.widget.ImageButton
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.tool.PropertiesTools
import java.io.File

@Suppress("DEPRECATION")
class SettingsActivity : Activity() {

    private lateinit var prefs: android.content.SharedPreferences
    private lateinit var p: PropertiesTools

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 setContentView 之前设置主题
        prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
        if (prefs.getBoolean("dark_mode", false)) {
            setTheme(android.R.style.Theme_DeviceDefault_NoActionBar)
        }
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        p = PropertiesTools(File("$filesDir/settings.properties"))

        findViewById<ImageButton>(R.id.btn_back).setOnClickListener { finish() }

        // 夜间模式：切换后重建 Activity 以应用主题
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

        // 顶部安全距离
        val sbOffset = findViewById<SeekBar>(R.id.sb_top_offset)
        val tvOffset = findViewById<TextView>(R.id.tv_top_offset_value)
        sbOffset.progress = prefs.getInt("top_offset_dp", 0)
        tvOffset.text = "${sbOffset.progress}dp"
        sbOffset.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, v: Int, fromUser: Boolean) { tvOffset.text = "${v}dp" }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) {
                val dp = sb?.progress ?: 0
                prefs.edit().putInt("top_offset_dp", dp).apply()
                MainActivity.wm?.get()?.setTopOffset(dp)
            }
        })

        // 清理缓存：显示实际大小
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

        // 漫画页间距
        val sbSpacing = findViewById<SeekBar>(R.id.sb_manga_spacing)
        val tvSpacing = findViewById<TextView>(R.id.tv_manga_spacing_value)
        sbSpacing.progress = p["mangaSpacing"].toIntOrNull() ?: 0
        tvSpacing.text = "${sbSpacing.progress}dp"
        sbSpacing.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, v: Int, fromUser: Boolean) { tvSpacing.text = "${v}dp" }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) { p["mangaSpacing"] = "${sb?.progress ?: 0}" }
        })
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
