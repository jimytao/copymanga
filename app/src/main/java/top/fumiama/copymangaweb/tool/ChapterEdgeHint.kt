package top.fumiama.copymangaweb.tool

/** 边界换章 Toast 文案（对齐 Flutter _applyEdgeOutcome）。 */
object ChapterEdgeHint {
    const val AT_END = "已经到头了~"

    fun message(goNext: Boolean, scrollStyle: Boolean): String {
        val dir = if (goNext) "下" else "上"
        val verb = if (scrollStyle) "滑动" else "按下"
        return "再次${verb}加载${dir}一章"
    }
}
