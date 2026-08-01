package top.fumiama.copymangaweb.tool

/** 阅读器点击分区（对齐 Flutter ReaderTapZone）。 */
enum class ReaderTapZone {
    PREV,
    NEXT,
    MENU,
    NONE,
}

/**
 * 纯函数点击分区。
 * @param xFrac / [yFrac] 相对控件宽高的 0..1 坐标
 * @param mode `h` 横向 / `v` 纵向 / `w` 条漫
 */
object ReaderTapClassifier {
    fun classify(xFrac: Float, yFrac: Float, mode: String, r2l: Boolean): ReaderTapZone {
        return when (mode) {
            "w" -> ReaderTapZone.MENU
            "v" -> classifyVertical(xFrac, yFrac)
            else -> classifyHorizontal(xFrac, r2l)
        }
    }

    private fun classifyHorizontal(xFrac: Float, r2l: Boolean): ReaderTapZone {
        return when {
            xFrac <= 1f / 3f -> if (r2l) ReaderTapZone.NEXT else ReaderTapZone.PREV
            xFrac >= 2f / 3f -> if (r2l) ReaderTapZone.PREV else ReaderTapZone.NEXT
            else -> ReaderTapZone.MENU
        }
    }

    private fun classifyVertical(xFrac: Float, yFrac: Float): ReaderTapZone {
        when {
            yFrac <= 1f / 3f -> return ReaderTapZone.PREV
            yFrac >= 2f / 3f -> return ReaderTapZone.NEXT
        }
        // 中 1/3：仅中央菜单矩形；左右剩余无效（防误触）
        val inMenuX = kotlin.math.abs(xFrac - 0.5f) < 0.38f / 2f
        val inMenuY = kotlin.math.abs(yFrac - 0.5f) < 0.32f / 2f
        return if (inMenuX && inMenuY) ReaderTapZone.MENU else ReaderTapZone.NONE
    }
}
