package top.fumiama.copymangaweb.tool

import android.content.Intent
import android.widget.Toast
import top.fumiama.copymangaweb.activity.MainActivity.Companion.wm
import top.fumiama.copymangaweb.activity.ViewMangaActivity
import java.io.File
import java.lang.ref.WeakReference

class PagesManager(w: WeakReference<ViewMangaActivity>) {
    val v = w.get()
    private var isEndL = false
    private var isEndR = false
    fun toPreviousPage(){ toPage(v?.r2l==true) }
    fun toNextPage(){ toPage(v?.r2l!=true) }
    fun openAdjacentChapter(goNext: Boolean) {
        wm?.get()?.mBinding?.w?.apply { post {
            loadUrl("javascript:invoke.clickClass(\"comicControlBottomTopClick\",${if(goNext)1 else 0});")
        } }
        v?.tt?.canDo = false
        v?.finish()
    }
    private fun judgePrevious() = (v?.pageNum ?: 0) > 1
    private fun judgeNext() = (v?.pageNum ?: 0) < (v?.count ?: 0)
    private fun toPage(goNext:Boolean){
        if (v?.clicked == false) {
            if (if(goNext)judgeNext() else judgePrevious()) {
                if(goNext) {
                    v.scrollForward()
                    isEndR = false
                } else {
                    v.scrollBack()
                    isEndL = false
                }
            } else {
                val chapterUrl = if(goNext) v?.nextChapterUrl else v?.previousChapterUrl
                if (chapterUrl != null) {
                    if (if(goNext)isEndR else isEndL) {
                        openAdjacentChapter(goNext)
                    } else doubleTapToast(goNext)
                } else {
                    val newZipPosition = (v?.zipPosition ?: 0) + (if(goNext) 1 else -1)
                    if(v?.dlZip2View == true && newZipPosition >= 0 && newZipPosition <
                        (v.zipList?.size ?: 0)){
                        if (if(goNext)isEndR else isEndL){
                            val newTitle = v.zipList?.get(newZipPosition) ?: "null"
                            val newFile = File(v.cd, newTitle)
                            v.startActivity(
                                Intent(v, ViewMangaActivity::class.java)
                                    .putExtra(ViewMangaActivity.EXTRA_TITLE, newTitle)
                                    .putExtra(ViewMangaActivity.EXTRA_ZIP_FILE_PATH, newFile.absolutePath)
                                    .putExtra(ViewMangaActivity.EXTRA_ZIP_POSITION, newZipPosition)
                                    .putExtra(ViewMangaActivity.EXTRA_ZIP_LIST, v.zipList)
                                    .putExtra(ViewMangaActivity.EXTRA_CD_PATH, v.cd?.absolutePath)
                                    .putExtra(ViewMangaActivity.EXTRA_PAGE_NUMBER, if(!goNext) -2 else -1)
                            )
                            v.tt.canDo = false
                            v.finish()
                        }else doubleTapToast(goNext)
                    }
                    else Toast.makeText(
                        v?.applicationContext,
                        "已经到头了~",
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
        } else v?.hideSettings()
    }
    fun manageInfo(){
        if (v?.clicked == false) v.showSettings() else v?.hideSettings()
    }
    private fun doubleTapToast(goNext: Boolean){
        val hint = if(goNext) "下" else "上"
        Toast.makeText(
            v?.applicationContext,
            "再次按下加载${hint}一章",
            Toast.LENGTH_SHORT
        ).show()
        if(goNext) isEndR = true
        else isEndL = true
    }
}