package top.fumiama.copymangaweb.activity

import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.bumptech.glide.Glide
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.data.Episode
import top.fumiama.copymangaweb.tool.CartoonApi

class CartoonDetailActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_PATH_WORD = "path_word"
        const val EXTRA_NAME = "name"
        const val EXTRA_COVER = "cover"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_cartoon_detail)

        val pathWord = intent.getStringExtra(EXTRA_PATH_WORD) ?: return
        val nameHint = intent.getStringExtra(EXTRA_NAME) ?: ""
        val coverHint = intent.getStringExtra(EXTRA_COVER) ?: ""

        val isDark = getSharedPreferences("app_settings", MODE_PRIVATE).getBoolean("dark_mode", false)
        if (isDark) window.decorView.setBackgroundColor(Color.BLACK)

        val btnBack = findViewById<ImageButton>(R.id.btnBack)
        val tvTitle = findViewById<TextView>(R.id.tvTitle)
        val ivCover = findViewById<ImageView>(R.id.ivCover)
        val tvName = findViewById<TextView>(R.id.tvName)
        val tvYear = findViewById<TextView>(R.id.tvYear)
        val tvCount = findViewById<TextView>(R.id.tvCount)
        val tvTags = findViewById<TextView>(R.id.tvTags)
        val tvBrief = findViewById<TextView>(R.id.tvBrief)
        val llEpisodes = findViewById<LinearLayout>(R.id.llEpisodes)
        val tvEpisodesEmpty = findViewById<TextView>(R.id.tvEpisodesEmpty)
        val progress = findViewById<ProgressBar>(R.id.progressBar)

        btnBack.setOnClickListener { finish() }

        // Show hint data immediately while loading
        tvTitle.text = nameHint
        tvName.text = nameHint
        if (coverHint.isNotEmpty()) {
            Glide.with(this).load(coverHint).placeholder(android.R.color.darker_gray).into(ivCover)
        }

        progress.visibility = View.VISIBLE

        lifecycleScope.launch {
            // Load detail and episodes in parallel
            val detailDeferred = async { CartoonApi.getDetail(pathWord) }
            val episodesDeferred = async { CartoonApi.getEpisodes(pathWord) }

            val detail = detailDeferred.await()
            val episodes = episodesDeferred.await()

            progress.visibility = View.GONE

            detail?.cartoon?.let { c ->
                tvTitle.text = c.name
                tvName.text = c.name
                Glide.with(this@CartoonDetailActivity)
                    .load(c.cover)
                    .placeholder(android.R.color.darker_gray)
                    .into(ivCover)
                tvYear.text = c.years?.let { "首播：${it.take(4)}年" } ?: ""
                tvCount.text = "共 ${episodes?.total ?: "?"} 集"
                tvTags.text = c.theme?.joinToString(" · ") ?: ""
                tvBrief.text = c.brief ?: ""
            }

            if (episodes == null || episodes.list.isEmpty()) {
                tvEpisodesEmpty.visibility = View.VISIBLE
            } else {
                bindEpisodes(llEpisodes, episodes.list)
            }
        }
    }

    private fun bindEpisodes(container: LinearLayout, list: List<Episode>) {
        val inflater = LayoutInflater.from(this)
        // Sort by name so EP order is natural
        val sorted = list.sortedWith(compareBy { ep ->
            val num = Regex("\\d+").find(ep.name)?.value?.toIntOrNull() ?: Int.MAX_VALUE
            num
        })
        sorted.forEach { ep ->
            val v = inflater.inflate(R.layout.item_episode, container, false)
            v.findViewById<TextView>(R.id.tvEpisodeName).text = ep.name
            v.findViewById<TextView>(R.id.tvEpisodeDate).text = ep.datetime_updated?.take(10) ?: ""
            v.setOnClickListener {
                Toast.makeText(this, "视频播放功能将在登录功能完成后支持", Toast.LENGTH_SHORT).show()
            }
            container.addView(v)
        }
    }
}
