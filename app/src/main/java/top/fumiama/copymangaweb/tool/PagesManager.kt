package top.fumiama.copymangaweb.tool

import android.content.Intent
import android.widget.Toast
import top.fumiama.copymangaweb.activity.MainActivity.Companion.wm
import top.fumiama.copymangaweb.activity.ViewMangaActivity
import java.io.File
import java.lang.ref.WeakReference

class PagesManager(
    w: WeakReference<ViewMangaActivity>,
    private val edgeGuard: ChapterEdgeGuard = ChapterEdgeGuard(),
) {
    val v = w.get()

    /** 屏幕左区热区（名称保留兼容）；内部按 r2l 映射到阅读顺序。 */
    fun toPreviousPage() {
        turnReading(goNext = v?.r2l == true, scrollStyle = false)
    }

    /** 屏幕右区热区（名称保留兼容）；内部按 r2l 映射到阅读顺序。 */
    fun toNextPage() {
        turnReading(goNext = v?.r2l != true, scrollStyle = false)
    }

    /**
     * 按阅读顺序翻页/边界换章。
     * 音量键、滑动越界、以及经 [ReaderTapClassifier] 得到的 PREV/NEXT 应走此入口。
     */
    fun turnReading(goNext: Boolean, scrollStyle: Boolean = false) {
        toPage(goNext, scrollStyle)
    }

    fun clearEdgeHints() = edgeGuard.clear()

    fun openAdjacentChapter(goNext: Boolean) {
        edgeGuard.clear()
        val ma = wm?.get()
        val prefetched = if (goNext) ma?.consumePrefetchedData() else null
        if (prefetched != null) {
            // 预取命中只换阅读器数据；不在后台点表页（盖住时 clickClass 易把 H5 打回首页）
            ma?.callViewMangaFromPrefetch(prefetched)
        } else {
            ma?.isPrefetching = false
            ma?.mBinding?.w?.apply { post {
                loadUrl("javascript:invoke.clickClass(\"comicControlBottomTopClick\",${if (goNext) 1 else 0});")
            } }
        }
        v?.tt?.canDo = false
        v?.finish()
    }

    private fun judgePrevious() = (v?.pageNum ?: 0) > 1
    private fun judgeNext() = (v?.pageNum ?: 0) < (v?.count ?: 0)

    /** 条漫用几何边界；横/纵用页码。 */
    private fun canMove(goNext: Boolean): Boolean {
        val act = v ?: return false
        if (act.isWebtoonMode) {
            return if (goNext) !act.atWebtoonChapterEdge(towardEnd = true)
            else !act.atWebtoonChapterEdge(towardEnd = false)
        }
        return if (goNext) judgeNext() else judgePrevious()
    }

    private fun toPage(goNext: Boolean, scrollStyle: Boolean) {
        if (v?.clicked == false) {
            if (canMove(goNext)) {
                if (goNext) {
                    v.scrollForward()
                    edgeGuard.clearSide(true)
                } else {
                    v.scrollBack()
                    edgeGuard.clearSide(false)
                }
            } else {
                applyEdge(goNext, scrollStyle)
            }
        } else v?.hideSettings()
    }

    private fun applyEdge(goNext: Boolean, scrollStyle: Boolean) {
        val act = v ?: return
        val chapterUrl = if (goNext) act.nextChapterUrl else act.previousChapterUrl
        val hasUrl = chapterUrl != null
        val zipPos = act.zipPosition + (if (goNext) 1 else -1)
        val hasZip = act.dlZip2View && zipPos >= 0 && zipPos < (act.zipList?.size ?: 0)
        val hasAdjacent = hasUrl || hasZip

        when (edgeGuard.onEdge(goNext, hasAdjacent = hasAdjacent)) {
            ChapterEdgeOutcome.AT_END -> toast(ChapterEdgeHint.AT_END)
            ChapterEdgeOutcome.CONFIRM_NEEDED ->
                toast(ChapterEdgeHint.message(goNext, scrollStyle))
            ChapterEdgeOutcome.OPEN_CHAPTER -> {
                if (hasUrl) {
                    openAdjacentChapter(goNext)
                } else if (hasZip) {
                    openZipAdjacent(goNext, zipPos)
                } else {
                    toast(ChapterEdgeHint.AT_END)
                }
            }
        }
    }

    private fun openZipAdjacent(goNext: Boolean, newZipPosition: Int) {
        val act = v ?: return
        val newTitle = act.zipList?.get(newZipPosition) ?: "null"
        val newFile = File(act.cd, newTitle)
        act.startActivity(
            Intent(act, ViewMangaActivity::class.java)
                .putExtra(ViewMangaActivity.EXTRA_TITLE, newTitle)
                .putExtra(ViewMangaActivity.EXTRA_ZIP_FILE_PATH, newFile.absolutePath)
                .putExtra(ViewMangaActivity.EXTRA_ZIP_POSITION, newZipPosition)
                .putExtra(ViewMangaActivity.EXTRA_ZIP_LIST, act.zipList)
                .putExtra(ViewMangaActivity.EXTRA_CD_PATH, act.cd?.absolutePath)
                .putExtra(ViewMangaActivity.EXTRA_PAGE_NUMBER, if (!goNext) -2 else -1)
        )
        act.tt.canDo = false
        edgeGuard.clear()
        act.finish()
    }

    fun manageInfo() {
        if (v?.clicked == false) v.showSettings() else v?.hideSettings()
    }

    private fun toast(msg: String) {
        Toast.makeText(v?.applicationContext, msg, Toast.LENGTH_SHORT).show()
    }
}
