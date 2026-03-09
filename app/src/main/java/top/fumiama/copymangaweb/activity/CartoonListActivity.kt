package top.fumiama.copymangaweb.activity

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.DividerItemDecoration
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import kotlinx.coroutines.launch
import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.data.CartoonBrief
import top.fumiama.copymangaweb.tool.CartoonApi

class CartoonListActivity : AppCompatActivity() {

    private val items = mutableListOf<CartoonBrief>()
    private var currentKeyword = ""
    private var currentOffset = 0
    private var totalCount = 0
    private val pageSize = 24

    private lateinit var rv: RecyclerView
    private lateinit var progress: ProgressBar
    private lateinit var tvEmpty: TextView
    private lateinit var llLoadMore: LinearLayout
    private lateinit var adapter: CartoonAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_cartoon_list)

        rv = findViewById(R.id.rvCartoons)
        progress = findViewById(R.id.progressBar)
        tvEmpty = findViewById(R.id.tvEmpty)
        llLoadMore = findViewById(R.id.llLoadMore)
        val etSearch = findViewById<EditText>(R.id.etSearch)
        val btnSearch = findViewById<ImageButton>(R.id.btnSearch)
        val btnBack = findViewById<ImageButton>(R.id.btnBack)
        val btnLoadMore = findViewById<Button>(R.id.btnLoadMore)

        adapter = CartoonAdapter(items) { item ->
            startActivity(
                Intent(this, CartoonDetailActivity::class.java)
                    .putExtra(CartoonDetailActivity.EXTRA_PATH_WORD, item.path_word)
                    .putExtra(CartoonDetailActivity.EXTRA_NAME, item.name)
                    .putExtra(CartoonDetailActivity.EXTRA_COVER, item.cover)
            )
        }
        rv.layoutManager = LinearLayoutManager(this)
        rv.addItemDecoration(DividerItemDecoration(this, DividerItemDecoration.VERTICAL))
        rv.adapter = adapter

        btnBack.setOnClickListener { finish() }

        val doSearch = {
            val kw = etSearch.text.toString().trim()
            currentKeyword = kw
            currentOffset = 0
            items.clear()
            adapter.notifyDataSetChanged()
            loadData()
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(etSearch.windowToken, 0)
        }

        btnSearch.setOnClickListener { doSearch() }
        etSearch.setOnEditorActionListener { _, actionId, event ->
            if (actionId == EditorInfo.IME_ACTION_SEARCH ||
                (event?.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_DOWN)) {
                doSearch(); true
            } else false
        }

        btnLoadMore.setOnClickListener {
            currentOffset += pageSize
            loadData()
        }

        loadData()
    }

    private fun loadData() {
        progress.visibility = View.VISIBLE
        llLoadMore.visibility = View.GONE
        tvEmpty.visibility = View.GONE

        lifecycleScope.launch {
            val result = if (currentKeyword.isEmpty()) {
                CartoonApi.getCartoons(offset = currentOffset, limit = pageSize)
            } else {
                CartoonApi.searchCartoons(currentKeyword, offset = currentOffset)
            }

            progress.visibility = View.GONE

            if (result == null) {
                if (items.isEmpty()) {
                    tvEmpty.text = "加载失败，请检查网络"
                    tvEmpty.visibility = View.VISIBLE
                }
                return@launch
            }

            totalCount = result.total
            val startPos = items.size
            items.addAll(result.list)
            if (startPos == 0) adapter.notifyDataSetChanged()
            else adapter.notifyItemRangeInserted(startPos, result.list.size)

            if (items.isEmpty()) {
                tvEmpty.text = "未找到相关动漫"
                tvEmpty.visibility = View.VISIBLE
            } else if (items.size < totalCount) {
                llLoadMore.visibility = View.VISIBLE
            }
        }
    }

    inner class CartoonAdapter(
        private val data: List<CartoonBrief>,
        private val onClick: (CartoonBrief) -> Unit
    ) : RecyclerView.Adapter<CartoonViewHolder>() {

        override fun onCreateViewHolder(parent: android.view.ViewGroup, viewType: Int): CartoonViewHolder {
            val v = layoutInflater.inflate(R.layout.item_cartoon, parent, false)
            return CartoonViewHolder(v)
        }

        override fun onBindViewHolder(holder: CartoonViewHolder, position: Int) {
            val item = data[position]
            holder.tvName.text = item.name
            holder.tvInfo.text = buildString {
                item.years?.let { append(it.take(4)).append("年  ") }
                item.count?.let { append("共${it}集") }
            }
            item.popular?.let { holder.tvPopular.text = "热度 ${it}" }
            Glide.with(this@CartoonListActivity)
                .load(item.cover)
                .placeholder(android.R.color.darker_gray)
                .into(holder.ivCover)
            holder.itemView.setOnClickListener { onClick(item) }
        }

        override fun getItemCount() = data.size
    }

    class CartoonViewHolder(v: View) : RecyclerView.ViewHolder(v) {
        val ivCover: android.widget.ImageView = v.findViewById(R.id.ivCover)
        val tvName: TextView = v.findViewById(R.id.tvName)
        val tvInfo: TextView = v.findViewById(R.id.tvInfo)
        val tvPopular: TextView = v.findViewById(R.id.tvPopular)
    }
}
