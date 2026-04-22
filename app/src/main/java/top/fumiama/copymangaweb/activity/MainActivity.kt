package top.fumiama.copymangaweb.activity

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.webkit.ValueCallback
import android.webkit.WebView
import androidx.activity.OnBackPressedCallback
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.fumiama.copymangaweb.BuildConfig
import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.activity.DlActivity.Companion.json
import top.fumiama.copymangaweb.activity.template.ToolsBoxActivity
import top.fumiama.copymangaweb.activity.viewmodel.MainViewModel
import top.fumiama.copymangaweb.databinding.ActivityMainBinding
import top.fumiama.copymangaweb.handler.MainHandler
import top.fumiama.copymangaweb.tool.MangaDlTools.Companion.wmdlt
import top.fumiama.copymangaweb.tool.SetDraggable
import top.fumiama.copymangaweb.tool.Updater
import top.fumiama.copymangaweb.tool.UrlManager
import top.fumiama.copymangaweb.web.JS
import top.fumiama.copymangaweb.web.JSHidden
import top.fumiama.copymangaweb.web.WebChromeClient
import java.lang.ref.WeakReference

class MainActivity: ToolsBoxActivity() {
    var uploadMessageAboveL: ValueCallback<Array<Uri>>? = null
    var saveUrlsOnly = false
    lateinit var mBinding: ActivityMainBinding
    private val mViewModel = MainViewModel()
    private var isStatusBarHidden = false
    private lateinit var gestureDetector: GestureDetector

    @SuppressLint("JavascriptInterface")
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        mBinding = ActivityMainBinding.inflate(layoutInflater)
        mBinding.mainViewModel = mViewModel
        mBinding.lifecycleOwner = this
        setContentView(mBinding.root)

        ViewCompat.setOnApplyWindowInsetsListener(mBinding.root) { v, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            val cutout    = insets.getInsets(WindowInsetsCompat.Type.displayCutout())
            val navBar    = insets.getInsets(WindowInsetsCompat.Type.navigationBars())
            val gesture   = hasGestureBar()

            val topPad    = if (isStatusBarHidden) 0 else maxOf(statusBar.top, cutout.top)
            val bottomPad = if (gesture) navBar.bottom else 0
            val leftPad   = maxOf(cutout.left,  if (gesture) navBar.left  else 0)
            val rightPad  = maxOf(cutout.right, if (gesture) navBar.right else 0)

            v.setPadding(leftPad, topPad, rightPad, bottomPad)
            insets
        }

        wm = WeakReference(this)
        mh = MainHandler(Looper.myLooper()!!)
        toolsBox.netInfo.let {
            if(it == "无网络" || it == "错误") {
                setFab2DlList()
                return@let
            }

            lifecycleScope.launch {
                // 首次启动：并发探测最快地址后再加载；后续启动：立即用缓存地址，后台更新
                if (!UrlManager.hasCachedUrl(this@MainActivity)) {
                    withContext(Dispatchers.IO) { UrlManager.probe(this@MainActivity) }
                } else {
                    UrlManager.init(this@MainActivity)
                    launch(Dispatchers.IO) { UrlManager.probe(this@MainActivity) }
                }

                launch(Dispatchers.IO) { goCheckUpdate(false) }

                WebView.setWebContentsDebuggingEnabled(true)
                mBinding.w.apply { post {
                    setWebViewClient("i.js")
                    webChromeClient = WebChromeClient()
                    loadJSInterface(JS())
                    loadUrl(UrlManager.activeUrl)
                } }

                mBinding.wh.apply { post {
                    settings.userAgentString = getString(R.string.pc_ua)
                    webChromeClient = WebChromeClient()
                    setWebViewClient("h.js")
                    loadJSInterface(JSHidden())
                } }
            }
        }
        SetDraggable().with(this).onto(mBinding.fab)

        val prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
        if (prefs.getBoolean("dark_mode", false)) {
            window.statusBarColor = android.graphics.Color.BLACK
            mBinding.root.setBackgroundColor(android.graphics.Color.BLACK)
        }
        if (prefs.getBoolean("hide_status_bar", false)) { isStatusBarHidden = true; toggleStatusBar() }

        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDoubleTap(e: MotionEvent): Boolean { toggleStatusBar(); return true }
        })
        mBinding.w.setOnTouchListener { _, event -> gestureDetector.onTouchEvent(event); false }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (mBinding.w.canGoBack()) {
                    mBinding.w.goBack()
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
    }

    private fun toggleStatusBar() {
        isStatusBarHidden = !isStatusBarHidden
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (isStatusBarHidden) window.insetsController?.hide(WindowInsets.Type.statusBars())
            else window.insetsController?.show(WindowInsets.Type.statusBars())
        } else {
            @Suppress("DEPRECATION")
            if (isStatusBarHidden) window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
            else window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        }
        ViewCompat.requestApplyInsets(mBinding.root)
    }

    private fun hasGestureBar(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val id = resources.getIdentifier("config_navBarInteractionMode", "integer", "android")
        return id > 0 && resources.getInteger(id) == 2
    }

    fun setStatusBarHidden(hidden: Boolean) { if (hidden != isStatusBarHidden) toggleStatusBar() }

    fun setTopOffset(dp: Int) {
        val px = (dp * resources.displayMetrics.density).toInt()
        mBinding.w.post { mBinding.w.setPadding(0, px, 0, 0) }
        mBinding.wh.post { mBinding.wh.setPadding(0, px, 0, 0) }
    }

    fun applyDarkMode(enabled: Boolean) {
        val js = if (enabled)
            "javascript:(function(){var e=document.getElementById('_dk');if(!e){e=document.createElement('style');e.id='_dk';document.head.appendChild(e);}e.textContent='html{filter:invert(1) hue-rotate(180deg)!important}img,video{filter:invert(1) hue-rotate(180deg)!important}'})();"
        else
            "javascript:(function(){var e=document.getElementById('_dk');if(e)e.remove();})();"
        mBinding.w.post { mBinding.w.loadUrl(js) }
        window.statusBarColor = if (enabled) android.graphics.Color.BLACK else android.graphics.Color.TRANSPARENT
        mBinding.root.setBackgroundColor(if (enabled) android.graphics.Color.BLACK else android.graphics.Color.WHITE)
    }

    fun openSettings() { startActivity(Intent(this, SettingsActivity::class.java)) }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FILE_CHOOSER_RESULT_CODE) {  //处理返回的图片，并进行上传
            if (uploadMessageAboveL == null || resultCode != RESULT_OK) return
            data?.let {
                onActivityResultAboveL(requestCode, resultCode, it)
            }
        }
    }

    private fun onActivityResultAboveL(requestCode: Int, resultCode: Int, intent: Intent) {
        if (requestCode != FILE_CHOOSER_RESULT_CODE ||
            uploadMessageAboveL == null ||
            resultCode != RESULT_OK
        ) return
        intent.clipData?.let { clipData ->
            var results = arrayOf<Uri>()
            for (i in 0..clipData.itemCount) {
                val item = clipData.getItemAt(i)
                results += item.uri
            }
            if (intent.dataString != null) {
                uploadMessageAboveL?.onReceiveValue(results)
                uploadMessageAboveL = null
            }
        }
    }

    private suspend fun goCheckUpdate(ignoreSkip: Boolean) {
        Updater(
            WeakReference(this),
            toolsBox,
            ignoreSkip,
            getPreferences(MODE_PRIVATE).getInt("skipVersion", 0)
        ).check(BuildConfig.VERSION_CODE)
    }

    fun loadHiddenUrl(u: String) {
        mBinding.wh.apply { post { loadUrl(u) } }
    }

    fun updateLoadProgress(p: Int) {
        lifecycleScope.launch { mViewModel.updateLoadProgress(p) }
    }

    fun setFab(content: String) {
        json = content
        lifecycleScope.launch {
            withContext(Dispatchers.Main) {
                mViewModel.showDlList.value = false
                mViewModel.setFabVisibility(true)
            }
        }
    }

    fun setFab2DlList() {
        lifecycleScope.launch {
            withContext(Dispatchers.Main) {
                mViewModel.showDlList.value = true
                mViewModel.setFabVisibility(true)
            }
        }
    }

    fun hideFab() {
        lifecycleScope.launch { mViewModel.setFabVisibility(false) }
    }

    fun onFabClicked(v: View) {
        DlListActivity.currentDir = getExternalFilesDir("")
        startActivity(
            Intent(this, (if(mViewModel.showDlList.value == true) DlListActivity::class else DlActivity::class).java)
                .putExtra("title", "我的下载")
        )
    }

    fun openImageChooserActivity() {
        // 调用自己的图库
        startActivityForResult(
            Intent.createChooser(
                Intent(Intent.ACTION_GET_CONTENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("image/*"), "Image Chooser"
            ), FILE_CHOOSER_RESULT_CODE
        )
    }

    fun callViewManga(content: String) {
        lifecycleScope.launch { withContext(Dispatchers.IO) {
            val listChapter = content.split('\n')
            if(!saveUrlsOnly) {
                val imgs = Array(maxOf(0, listChapter.size - 3)) { listChapter[it + 3] }
                withContext(Dispatchers.Main) {
                    startActivity(
                        Intent(this@MainActivity, ViewMangaActivity::class.java)
                            .putExtra(ViewMangaActivity.EXTRA_TITLE, listChapter[0].substringBeforeLast(' '))
                            .putExtra(ViewMangaActivity.EXTRA_NEXT_CHAPTER_URL, listChapter[1].let { if(it == "null") null else it })
                            .putExtra(ViewMangaActivity.EXTRA_PREV_CHAPTER_URL, listChapter[2].let { if(it == "null") null else it })
                            .putExtra(ViewMangaActivity.EXTRA_IMG_URLS, imgs)
                    )
                }
            } else {
                var imgs = arrayOf<String>()
                for(i in 3 until listChapter.size) imgs += listChapter[i]
                wmdlt?.get()?.setChapterImages(listChapter[0].substringAfterLast(' '), imgs)
            }
        } }
    }

    companion object {
        const val FILE_CHOOSER_RESULT_CODE = 1
        var wm: WeakReference<MainActivity>? = null
        var mh: MainHandler? = null
    }
}