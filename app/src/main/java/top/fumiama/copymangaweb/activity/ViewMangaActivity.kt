package top.fumiama.copymangaweb.activity

import android.animation.ObjectAnimator
import android.annotation.SuppressLint
import android.app.Dialog
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.app.AlertDialog
import android.text.InputType
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.SeekBar
import android.widget.Toast
import android.widget.ImageView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.viewpager2.widget.ViewPager2
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.Target
import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.activity.MainActivity.Companion.wm
import top.fumiama.copymangaweb.activity.template.ToolsBoxActivity
import top.fumiama.copymangaweb.databinding.ActivityViewmangaBinding
import top.fumiama.copymangaweb.handler.TimeThread
import top.fumiama.copymangaweb.tool.PagesManager
import top.fumiama.copymangaweb.tool.PropertiesTools
import top.fumiama.copymangaweb.tool.ToolsBox
import top.fumiama.copymangaweb.view.ScaleImageView
import java.io.File
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.Date
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream

class ViewMangaActivity : ToolsBoxActivity() {
    lateinit var handler: Handler
    lateinit var tt: TimeThread
    lateinit var mBinding: ActivityViewmangaBinding

    var count = 0
    var clicked = false
    var r2l = true
    var infoDrawerDelta = 0f

    // 从 Intent extras 读取的实例字段（替代原来的 companion object 静态字段）
    var titleText = "Null"
    var nextChapterUrl: String? = null
    var previousChapterUrl: String? = null
    var imgUrls = arrayOf<String>()
    var zipPosition = 0
    var zipList: Array<String>? = null
    var cd: File? = null
    private var mangaZip: File? = null
    val dlZip2View get() = mangaZip != null
    private val volTurnPage get() = p["volturn"] == "true"

    private var dialog: Dialog? = null
    private lateinit var p: PropertiesTools
    private var isInSeek = false
    private var currentItem = 0
    private var webtoonPage = 1
    private var notUseVP = true
    private val isWebtoon: Boolean get() = !notUseVP && p["readMode"] == "w"
    private var isPageTurning = false
    var pageNum = 1
        get() {
            field = getPageNumber()
            return field
        }
        set(value) {
            if (count == 0) return
            val clamped = value.coerceIn(1, count)
            if (!notUseVP && isPageTurning) return
            setPageNumber(clamped)
            if (notUseVP) {
                try {
                    loadOneImg()
                } catch (e: java.lang.Exception) {
                    e.printStackTrace()
                    toolsBox.toastError("页数${currentItem}不合法")
                }
            }
            field = getPageNumber()
        }

    @SuppressLint("SetTextI18n")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mBinding = ActivityViewmangaBinding.inflate(layoutInflater)
        setContentView(mBinding.root)
        va = WeakReference(this)

        // 从 Intent extras 读取数据（替代原来的 companion object 静态字段传参）
        titleText = intent.getStringExtra(EXTRA_TITLE) ?: "Null"
        nextChapterUrl = intent.getStringExtra(EXTRA_NEXT_CHAPTER_URL)
        previousChapterUrl = intent.getStringExtra(EXTRA_PREV_CHAPTER_URL)
        imgUrls = intent.getStringArrayExtra(EXTRA_IMG_URLS) ?: emptyArray()
        zipPosition = intent.getIntExtra(EXTRA_ZIP_POSITION, 0)
        zipList = intent.getStringArrayExtra(EXTRA_ZIP_LIST)
        cd = intent.getStringExtra(EXTRA_CD_PATH)?.let { File(it) }
        mangaZip = intent.getStringExtra(EXTRA_ZIP_FILE_PATH)?.let { File(it) }
        val pn = intent.getIntExtra(EXTRA_PAGE_NUMBER, -1)

        if (getSharedPreferences("app_settings", MODE_PRIVATE).getBoolean("dark_mode", false)) {
            mBinding.vcp.setBackgroundColor(android.graphics.Color.BLACK)
        }
        p = PropertiesTools(File("$filesDir/settings.properties"))
        r2l = p["r2l"] == "true"
        notUseVP = p["noAnimation"] == "true"
        handler = MyHandler(toolsBox)
        tt = TimeThread(handler, 22)
        tt.canDo = true
        tt.start()
        dialog = Dialog(this)
        dialog?.apply {
            setContentView(R.layout.dialog_unzipping)
            show()
        }
        mBinding.oneinfo.inftitle.ttitle.apply { post { text = titleText } }
        Log.d("MyVM", "dlZip2View: $dlZip2View, mangaZip: $mangaZip")
        if(dlZip2View && mangaZip?.exists() != true) toolsBox.toastError("已经到头了~")
        else Thread {
            try {
                count = if (dlZip2View) countZipItems() else imgUrls.size
            } catch (e: Exception) {
                e.printStackTrace()
                runOnUiThread { toolsBox.toastError("分析图片url错误") }
            }
            runOnUiThread {
                try {
                    prepareItems()
                    if(pn > 0) {
                        pageNum = pn
                    } else if(pn == -2){
                        pageNum = count
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    toolsBox.toastError("准备控件错误")
                } finally {
                    dialog?.dismiss()
                    dialog = null
                }
            }
        }.start()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) window.setDecorFitsSystemWindows(false)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        var flag = false
        if(volTurnPage) when(keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                scrollBack()
                flag = true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                scrollForward()
                flag = true
            }
        }
        return if(flag) true else super.onKeyDown(keyCode, event)
    }

    private fun getPageNumber(): Int {
        if (isWebtoon) return webtoonPage
        return if (r2l && !notUseVP) count - mBinding.vp.currentItem
        else (if (notUseVP) currentItem else mBinding.vp.currentItem) + 1
    }

    private fun setPageNumber(num: Int) {
        if (isWebtoon) {
            webtoonPage = num
            mBinding.vrv.post { mBinding.vrv.scrollToPosition(num - 1) }
            return
        }
        if (r2l && !notUseVP) mBinding.vp.apply { post { currentItem = count - num } }
        else if (notUseVP) currentItem = num - 1 else mBinding.vp.currentItem = num - 1
    }

    private fun getImgBitmap(position: Int): Bitmap? {
        if (position >= count || position < 0) return null
        return ZipFile(mangaZip).use { zip ->
            BitmapFactory.decodeStream(zip.getInputStream(zip.getEntry("${position}.webp")))
        }
    }

    private fun loadOneImg() {
        if(dlZip2View) mBinding.vone.onei.apply { post { setImageBitmap(getImgBitmap(currentItem)) } }
        else {
            Glide.with(this@ViewMangaActivity)
                .load(toolsBox.resolution.wrap(imgUrls[currentItem]))
                .placeholder(R.drawable.ic_dl)
                .dontAnimate()
                .into(mBinding.vone.onei)
            for (idx in (currentItem + 1)..(currentItem + 10)) {
                if (idx in 0 until count) {
                    Glide.with(this@ViewMangaActivity).load(toolsBox.resolution.wrap(imgUrls[idx])).preload()
                }
            }
        }
        updateSeekBar()
    }

    private fun setIdPosition(position: Int) {
        infoDrawerDelta = position.toFloat()
        mBinding.infcard.root.apply { post { translationY = infoDrawerDelta } }
    }

    @SuppressLint("SetTextI18n")
    private fun prepareItems() {
        prepareVP()
        prepareInfoBar(count)
        if (notUseVP) loadOneImg() else prepareIdBtVH()
        mBinding.infcard.root.post { setIdPosition(mBinding.infcard.root.height) }
        prepareIdBtVolTurn()
        prepareIdBtVP()
        prepareIdBtLR()
        prepareChapterNavButtons()
    }

    private fun prepareChapterNavButtons() {
        mBinding.infcard.idbtnPrevChapter.apply { post {
            isEnabled = previousChapterUrl != null
            alpha = if (previousChapterUrl != null) 1f else 0.4f
            setOnClickListener {
                previousChapterUrl?.let {
                    PagesManager(WeakReference(this@ViewMangaActivity)).openAdjacentChapter(false)
                }
            }
        } }
        mBinding.infcard.idbtnNextChapter.apply { post {
            isEnabled = nextChapterUrl != null
            alpha = if (nextChapterUrl != null) 1f else 0.4f
            setOnClickListener {
                nextChapterUrl?.let {
                    PagesManager(WeakReference(this@ViewMangaActivity)).openAdjacentChapter(true)
                }
            }
        } }
    }

    private fun prepareIdBtLR() {
        mBinding.infcard.idtblr.apply { post {
            isChecked = r2l
            setOnClickListener {
                val currentPage = pageNum
                r2l = mBinding.infcard.idtblr.isChecked
                p["r2l"] = if (r2l) "true" else "false"
                if (!notUseVP && !isWebtoon) {
                    mBinding.vp.post {
                        mBinding.vp.adapter = ViewData(mBinding.vp).RecyclerViewAdapter()
                        mBinding.vp.offscreenPageLimit = 5
                        setPageNumber(currentPage)
                    }
                }
            }
        } }
    }

    private fun prepareIdBtVP() {
        mBinding.infcard.idtbvp.apply { post {
            isChecked = notUseVP
            setOnClickListener {
                if (mBinding.infcard.idtbvp.isChecked) p["noAnimation"] = "true"
                else p["noAnimation"] = "false"
                Toast.makeText(this@ViewMangaActivity, "下次浏览生效", Toast.LENGTH_SHORT).show()
            }
        } }
    }

    private fun prepareVP() {
        if (notUseVP) {
            mBinding.vp.apply { post { visibility = View.INVISIBLE } }
            mBinding.vone.root.apply { post { visibility = View.VISIBLE } }
            mBinding.vrv.apply { post { visibility = View.INVISIBLE } }
        } else if (isWebtoon) {
            mBinding.vp.apply { post { visibility = View.INVISIBLE } }
            mBinding.vone.root.apply { post { visibility = View.INVISIBLE } }
            mBinding.vrv.apply { post {
                visibility = View.VISIBLE
                setupWebtoonRv()
            } }
        } else {
            mBinding.vp.apply { post {
                visibility = View.VISIBLE
                adapter = ViewData(this).RecyclerViewAdapter()
                offscreenPageLimit = 5
                registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                    override fun onPageScrollStateChanged(state: Int) {
                        isPageTurning = state != ViewPager2.SCROLL_STATE_IDLE
                    }
                    override fun onPageSelected(position: Int) {
                        updateSeekBar()
                        super.onPageSelected(position)
                    }
                })
                if (p["readMode"] == "v") orientation = ViewPager2.ORIENTATION_VERTICAL
                if (r2l) currentItem = count - 1
            } }
            mBinding.vone.root.apply { post { visibility = View.INVISIBLE } }
            mBinding.vrv.apply { post { visibility = View.INVISIBLE } }
        }
    }

    private fun updateSeekBar() {
        if (!isInSeek) hideSettings()
        updateSeekText()
        updateSeekProgress()
    }

    @SuppressLint("SetTextI18n")
    private fun prepareInfoBar(size: Int) {
        mBinding.oneinfo.root.apply { post { alpha = 0F } }
        mBinding.oneinfo.infseek.apply { post {
            visibility = View.INVISIBLE
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(p0: SeekBar?, p1: Int, isHuman: Boolean) {
                    if (isHuman) {
                        val target = (p1 * size / 100).coerceIn(1, size)
                        if (target == pageNum) return
                        if (notUseVP) {
                            currentItem = target - 1
                            updateSeekText()
                        } else {
                            setPageNumber(target)
                        }
                    }
                }

                override fun onStartTrackingTouch(p0: SeekBar?) {
                    isInSeek = true
                }

                override fun onStopTrackingTouch(p0: SeekBar?) {
                    isInSeek = false
                    if (notUseVP) loadOneImg()
                }
            })
        } }
        mBinding.oneinfo.inftitle.isearch.apply { post {
            visibility = View.INVISIBLE
            setOnClickListener {
                this@ViewMangaActivity.handler.sendEmptyMessage(3)
            }
        } }
        val showPageNum = p["showPageNum"] != "false"
        mBinding.oneinfo.inftxtprogress.apply { post {
            visibility = if (showPageNum) View.VISIBLE else View.GONE
            text = "$pageNum/$size"
            setOnClickListener { showPageInputDialog(size) }
        } }
    }

    private fun prepareIdBtVH() {
        mBinding.infcard.idtbvh.apply { post {
            val cur = p["readMode"] ?: if (p["vertical"] == "true") "v" else "h"
            when (cur) {
                "v" -> { isChecked = true; text = "纵向" }
                "w" -> { isChecked = true; text = "条漫" }
                else -> { text = "横向"; isChecked = false }
            }
            setOnClickListener {
                val next = when (p["readMode"] ?: if (p["vertical"] == "true") "v" else "h") {
                    "h" -> "v"; "v" -> "w"; else -> "h"
                }
                p["readMode"] = next
                when (next) {
                    "v" -> { isChecked = true; text = "纵向" }
                    "w" -> { isChecked = true; text = "条漫" }
                    else -> { text = "横向"; isChecked = false }
                }
                applyReadMode(next)
            }
        } }
    }

    private fun applyReadMode(mode: String) {
        when (mode) {
            "w" -> {
                mBinding.vp.post { mBinding.vp.visibility = View.INVISIBLE }
                mBinding.vone.root.post { mBinding.vone.root.visibility = View.INVISIBLE }
                mBinding.vrv.post {
                    mBinding.vrv.visibility = View.VISIBLE
                    if (mBinding.vrv.adapter == null) setupWebtoonRv()
                }
            }
            "v" -> {
                mBinding.vrv.post { mBinding.vrv.visibility = View.INVISIBLE }
                mBinding.vone.root.post { mBinding.vone.root.visibility = View.INVISIBLE }
                mBinding.vp.post {
                    mBinding.vp.visibility = View.VISIBLE
                    mBinding.vp.orientation = ViewPager2.ORIENTATION_VERTICAL
                    if (mBinding.vp.adapter == null) setupVPAdapter()
                }
            }
            else -> {
                mBinding.vrv.post { mBinding.vrv.visibility = View.INVISIBLE }
                mBinding.vone.root.post { mBinding.vone.root.visibility = View.INVISIBLE }
                mBinding.vp.post {
                    mBinding.vp.visibility = View.VISIBLE
                    mBinding.vp.orientation = ViewPager2.ORIENTATION_HORIZONTAL
                    if (mBinding.vp.adapter == null) setupVPAdapter()
                }
            }
        }
    }

    private fun setupVPAdapter() {
        mBinding.vp.apply {
            adapter = ViewData(this).RecyclerViewAdapter()
            offscreenPageLimit = 5
            registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                override fun onPageScrollStateChanged(state: Int) {
                    isPageTurning = state != ViewPager2.SCROLL_STATE_IDLE
                }
                override fun onPageSelected(position: Int) {
                    updateSeekBar()
                    super.onPageSelected(position)
                }
            })
            if (r2l) currentItem = count - 1
        }
    }

    private fun setupWebtoonRv() {
        mBinding.vrv.layoutManager = LinearLayoutManager(this)
        mBinding.vrv.adapter = WebtoonAdapter()
        mBinding.vrv.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(rv: RecyclerView, newState: Int) {
                if (newState == RecyclerView.SCROLL_STATE_IDLE) {
                    val pos = (rv.layoutManager as? LinearLayoutManager)
                        ?.findFirstVisibleItemPosition() ?: return
                    webtoonPage = (pos + 1).coerceIn(1, count)
                    updateSeekText()
                    updateSeekProgress()
                }
            }
        })
    }

    private fun prepareIdBtVolTurn() {
        mBinding.infcard.idtbvolturn.apply { post {
            isChecked = volTurnPage
            setOnClickListener {
                if (mBinding.infcard.idtbvolturn.isChecked) p["volturn"] = "true"
                else p["volturn"] = "false"
            }
        } }
    }

    private fun countZipItems(): Int {
        var c = 0
        try {
            val exist = mangaZip?.exists() == true
            if (!exist) return 0
            else {
                Log.d("Myvm", "zipf: $mangaZip")
                ZipFile(mangaZip).use { zip ->
                    c = zip.size()
                }
            }
        } catch (e: Exception) {
            runOnUiThread { toolsBox.toastError("读取zip错误!") }
        }
        return c
    }

    fun scrollBack() {
        if (isWebtoon) mBinding.vrv.post { mBinding.vrv.smoothScrollBy(0, -(mBinding.vrv.height * 4 / 5)) }
        else pageNum--
    }

    fun scrollForward() {
        if (isWebtoon) mBinding.vrv.post { mBinding.vrv.smoothScrollBy(0, mBinding.vrv.height * 4 / 5) }
        else pageNum++
    }

    @SuppressLint("SetTextI18n")
    private fun updateSeekText() {
        mBinding.oneinfo.inftxtprogress.apply { post { text = "$pageNum/$count" } }
    }

    private fun updateSeekProgress() {
        mBinding.oneinfo.infseek.apply { post { progress = pageNum * 100 / count } }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        tt.canDo = false
        super.onBackPressed()
    }

    override fun onDestroy() {
        tt.canDo = false
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    inner class ViewData(itemView: View) : RecyclerView.ViewHolder(itemView) {
        inner class RecyclerViewAdapter :
            RecyclerView.Adapter<ViewData>() {
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewData {
                return ViewData(
                    LayoutInflater.from(parent.context)
                        .inflate(R.layout.page_imgview, parent, false)
                )
            }

            @SuppressLint("ClickableViewAccessibility", "SetTextI18n")
            override fun onBindViewHolder(holder: ViewData, position: Int) {
                val pos = if (r2l) count - position - 1 else position
                holder.itemView.findViewById<ScaleImageView>(R.id.onei)?.let { oneImage ->
                    if(dlZip2View) getImgBitmap(pos)?.let {
                        //Glide.with(this@ViewMangaActivity).load(it).placeholder(R.drawable.bg_comment).into(holder.itemView.onei)
                        oneImage.setImageBitmap(it)
                    }
                    else Glide.with(this@ViewMangaActivity)
                        .load(toolsBox.resolution.wrap(imgUrls[pos])).placeholder(R.drawable.ic_dl)
                        .dontAnimate().timeout(10000)
                        .into(oneImage)
                }
            }

            override fun getItemCount(): Int {
                return count
            }
        }
    }

    inner class WebtoonAdapter : RecyclerView.Adapter<WebtoonAdapter.VH>() {
        inner class VH(val iv: ImageView) : RecyclerView.ViewHolder(iv)

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val iv = LayoutInflater.from(parent.context)
                .inflate(R.layout.page_webtoon_imgview, parent, false) as ImageView
            iv.setOnClickListener {
                val pm = PagesManager(WeakReference(this@ViewMangaActivity))
                pm.manageInfo()
            }
            return VH(iv)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            if (dlZip2View) {
                getImgBitmap(position)?.let { holder.iv.setImageBitmap(it) }
            } else {
                Glide.with(this@ViewMangaActivity)
                    .load(toolsBox.resolution.wrap(imgUrls[position]))
                    .placeholder(R.drawable.ic_dl)
                    .override(Target.SIZE_ORIGINAL)
                    .into(holder.iv)
            }
        }

        override fun getItemCount() = count
    }

    fun showSettings() {
        mBinding.oneinfo.infseek.visibility = View.VISIBLE
        mBinding.oneinfo.inftitle.isearch.visibility = View.VISIBLE
        val v = mBinding.oneinfo.root
        ObjectAnimator.ofFloat(
            v,
            "alpha",
            v.alpha,
            1F
        ).setDuration(233).start()
        clicked = true
        handler.sendEmptyMessage(2)
    }

    @SuppressLint("SetTextI18n")
    private fun showPageInputDialog(size: Int) {
        val et = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            setText(pageNum.toString())
            selectAll()
            hint = "1 - $size"
        }
        val dialog = AlertDialog.Builder(this)
            .setTitle("跳转到页码")
            .setView(et)
            .setPositiveButton("跳转") { _, _ -> jumpToPage(et, size) }
            .setNegativeButton("取消", null)
            .create()
        et.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                jumpToPage(et, size)
                dialog.dismiss()
                true
            } else false
        }
        dialog.window?.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        dialog.show()
    }

    private fun jumpToPage(et: EditText, size: Int) {
        val target = et.text.toString().toIntOrNull()?.coerceIn(1, size) ?: return
        if (notUseVP) {
            currentItem = target - 1
            loadOneImg()
        } else {
            setPageNumber(target)
        }
        (getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager)
            ?.hideSoftInputFromWindow(et.windowToken, 0)
    }

    fun hideSettings() {
        val v = mBinding.oneinfo.root
        ObjectAnimator.ofFloat(
            v,
            "alpha",
            v.alpha,
            0F
        ).setDuration(233).start()
        clicked = false
        mBinding.oneinfo.infseek.postDelayed({
            mBinding.oneinfo.infseek.visibility = View.INVISIBLE
            mBinding.oneinfo.inftitle.isearch.visibility = View.INVISIBLE
        }, 300)
        handler.sendEmptyMessage(1)
    }

    class MyHandler(
        private val toolsBox: ToolsBox
    ) : Handler(Looper.myLooper()!!) {
        private var infoShown = false
        private val delta: Float
            get() = va?.get()?.infoDrawerDelta ?: 0f

        @SuppressLint("SimpleDateFormat", "SetTextI18n")
        override fun handleMessage(msg: Message) {
            super.handleMessage(msg)
            when (msg.what) {
                1 -> if (infoShown) {
                    hideInfCard(); infoShown = false
                }
                2 -> if (!infoShown) {
                    showInfCard(); infoShown = true
                }
                3 -> infoShown = if (infoShown) {
                    hideInfCard(); false
                } else {
                    showInfCard(); true
                }
                22 -> (toolsBox.zis as? ViewMangaActivity)?.mBinding?.infcard?.idtime?.apply { post {
                    text = SimpleDateFormat("HH:mm")
                        .format(Date()) + toolsBox.week + toolsBox.netInfo
                } }
            }
        }

        private fun showInfCard() {
            Log.d("MyVM", "showInfCard delta $delta")
            va?.get()?.mBinding?.infcard?.apply {
                ObjectAnimator.ofFloat(idc, "alpha", 0.3F, 0.8F).setDuration(233).start()
                ObjectAnimator.ofFloat(root, "translationY", delta, 0F).setDuration(233).start()
            }
        }

        private fun hideInfCard() {
            Log.d("MyVM", "hideInfCard delta $delta")
            va?.get()?.mBinding?.infcard?.apply {
                ObjectAnimator.ofFloat(idc, "alpha", 0.8F, 0.3F).setDuration(233).start()
                ObjectAnimator.ofFloat(root, "translationY", 0F, delta).setDuration(233).start()
            }
        }
    }

    companion object {
        var va: WeakReference<ViewMangaActivity>? = null

        // Intent extra 键名常量
        const val EXTRA_TITLE = "title"
        const val EXTRA_NEXT_CHAPTER_URL = "nextChapterUrl"
        const val EXTRA_PREV_CHAPTER_URL = "prevChapterUrl"
        const val EXTRA_IMG_URLS = "imgUrls"
        const val EXTRA_ZIP_FILE_PATH = "zipFilePath"
        const val EXTRA_ZIP_POSITION = "zipPosition"
        const val EXTRA_ZIP_LIST = "zipList"
        const val EXTRA_CD_PATH = "cdPath"
        const val EXTRA_PAGE_NUMBER = "pageNumber"
    }
}