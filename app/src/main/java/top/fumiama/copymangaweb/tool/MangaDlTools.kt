package top.fumiama.copymangaweb.tool

import top.fumiama.copymangaweb.R
import top.fumiama.copymangaweb.activity.DlActivity
import java.io.File
import java.lang.Thread.sleep
import java.lang.ref.WeakReference
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class MangaDlTools(activity: DlActivity) {
    var exit = false
    private val sem = Semaphore(1)
    private val da = WeakReference(activity)
    private val d get() = da.get()
    private val p = PropertiesTools(File("${d?.filesDir}/chapters.hash"))
    private var imgUrlsList: Array<Array<String>?>? = null
    private var chaptersCount = 0

    init {
        wmdlt = WeakReference(this)
    }

    fun getImgsCountByHash(hash: String): Int? {
        val idx = p[hash].toIntOrNull() ?: return null
        return imgUrlsList?.getOrNull(idx)?.size
    }

    fun allocateChapterUrls(count: Int){
        imgUrlsList = arrayOfNulls(count)
        chaptersCount = 0
    }

    fun dlChapterUrl(url: String){
        if (!sem.tryAcquire(30, TimeUnit.SECONDS)) return
        da.get()?.apply {
            p[url.substringAfterLast("/")] = (chaptersCount++).toString()
            runOnUiThread { mBinding.dwh.apply { post { loadUrl(url) } } }
        }
    }

    fun setChapterImages(hash: String, imgUrls: Array<String>) {
        val idx = p[hash].toIntOrNull()
        if (idx != null) imgUrlsList?.takeIf { idx in it.indices }?.set(idx, imgUrls)
        sem.release()
    }

    fun awaitAllUrlsCollected(timeoutSec: Long = 30): Boolean {
        return if (sem.tryAcquire(timeoutSec, TimeUnit.SECONDS)) {
            sem.release()
            true
        } else false
    }

    fun dlChapterAndPackIntoZip(zipf: File, hash: String) {
        val idx = p[hash].toIntOrNull() ?: return
        imgUrlsList?.getOrNull(idx)?.let { images ->
            val dl = DownloadTools()
            zipf.parentFile?.let { if (!it.exists()) it.mkdirs() }
            if (zipf.exists()) zipf.delete()
            zipf.createNewFile()
            // WebP 已是压缩格式，使用 STORED 方式直接存储，避免 DEFLATE level 9 的无效 CPU 消耗
            val zip = ZipOutputStream(zipf.outputStream())
            zip.setMethod(ZipOutputStream.STORED)
            var succeed = true
            for (i in images.indices) {
                var tryTimes = 3
                var data: ByteArray? = null
                while (data == null && tryTimes-- > 0) {
                    data = d?.toolsBox?.resolution?.wrap(images[i])?.let { u ->
                        dl.getHttpContent(u, UrlManager.activeUrl, d?.getString(R.string.pc_ua))
                    }
                    if (data == null) {
                        onDownloadedListener?.handleMessage(i + 1)
                        sleep(2000)
                    }
                }
                val s = data != null
                if (!s) { succeed = false } else {
                    // STORED 方式必须提前设置 size 和 CRC
                    val entryCrc = CRC32().also { it.update(data!!) }
                    val entry = ZipEntry("$i.webp").apply {
                        method = ZipEntry.STORED
                        size = data!!.size.toLong()
                        compressedSize = data!!.size.toLong()
                        crc = entryCrc.value
                    }
                    zip.putNextEntry(entry)
                    zip.write(data!!)
                    zip.closeEntry()
                }
                onDownloadedListener?.handleMessage(s, i + 1)
                if (exit) break
            }
            zip.close()
            onDownloadedListener?.handleMessage(succeed)
        }
    }

    var onDownloadedListener: OnDownloadedListener? = null

    interface OnDownloadedListener {
        fun handleMessage(succeed: Boolean)
        fun handleMessage(succeed: Boolean, pageNow: Int)
        fun handleMessage(pageNow: Int)
    }

    companion object {
        var wmdlt: WeakReference<MangaDlTools>? = null
    }
}