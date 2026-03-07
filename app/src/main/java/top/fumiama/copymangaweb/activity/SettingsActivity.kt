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
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
        p = PropertiesTools(File("$filesDir/settings.properties"))

        findViewById<ImageButton>(R.id.btn_back).setOnClickListener { finish() }

        setupDarkMode()
        setupHideStatusBar()
        setupTopOffset()
        setupEnableCache()
        setupClearCache()
        setupShowPageNum()
        setupMangaSpacing()
    }

    private fun setupDarkMode() {
        val sw = findViewById<Switch>(R.id.sw_dark_mode)
        sw.isChecked = prefs.getBoolean("dark_mode", false)
        sw.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener { _, on ->
            prefs.edit().putBoolean("dark_mode", on).apply()
            MainActivity.wm?.get()?.applyDarkMode(on)
        })
    }

    private fun setupHideStatusBar() {
        val sw = findViewById<Switch>(R.id.sw_hide_statusbar)
        sw.isChecked = prefs.getBoolean("hide_status_bar", false)
        sw.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener { _, on ->
            prefs.edit().putBoolean("hide_status_bar", on).apply()
            MainActivity.wm?.get()?.setStatusBarHidden(on)
        })
    }

    private fun setupTopOffset() {
        val sb = findViewById<SeekBar>(R.id.sb_top_offset)
        val tv = findViewById<TextView>(R.id.tv_top_offset_value)
        val saved = prefs.getInt("top_offset_dp", 0)
        sb.progress = saved
        tv.text = "${saved}dp"
        sb.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                tv.text = "${progress}dp"
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                val dp = seekBar?.progress ?: 0
                prefs.edit().putInt("top_offset_dp", dp).apply()
                MainActivity.wm?.get()?.setTopOffset(dp)
            }
        })
    }

    private fun setupEnableCache() {
        val sw = findViewById<Switch>(R.id.sw_enable_cache)
        sw.isChecked = prefs.getBoolean("enable_cache", true)
        sw.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener { _, on ->
            prefs.edit().putBoolean("enable_cache", on).apply()
            Toast.makeText(this, "重启应用后生效", Toast.LENGTH_SHORT).show()
        })
    }

    private fun setupClearCache() {
        val btn = findViewById<Button>(R.id.btn_clear_cache)
        val tv = findViewById<TextView>(R.id.tv_cache_size)
        btn.setOnClickListener {
            MainActivity.wm?.get()?.let { ma ->
                ma.mBinding.w.clearCache(true)
                ma.mBinding.wh.clearCache(true)
            }
            tv.text = "已清理"
            Toast.makeText(this, "缓存已清理", Toast.LENGTH_SHORT).show()
        }
    }

    private fun setupShowPageNum() {
        val sw = findViewById<Switch>(R.id.sw_show_page_num)
        sw.isChecked = p["showPageNum"] != "false"
        sw.setOnCheckedChangeListener(CompoundButton.OnCheckedChangeListener { _, on ->
            p["showPageNum"] = if (on) "true" else "false"
        })
    }

    private fun setupMangaSpacing() {
        val sb = findViewById<SeekBar>(R.id.sb_manga_spacing)
        val tv = findViewById<TextView>(R.id.tv_manga_spacing_value)
        val saved = p["mangaSpacing"].toIntOrNull() ?: 0
        sb.progress = saved
        tv.text = "${saved}dp"
        sb.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                tv.text = "${progress}dp"
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                val dp = seekBar?.progress ?: 0
                p["mangaSpacing"] = dp.toString()
            }
        })
    }
}
