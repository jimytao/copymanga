package top.fumiama.copymangaweb.tool

/**
 * 一次 pointer 手势内只放行一次越界计数，避免同一次拖动的连续 overscroll 重复触发。
 * 对齐 Flutter EdgeGestureGate。
 */
class EdgeGestureGate {
    private var consumed = true

    fun beginGesture() {
        consumed = false
    }

    fun allow(): Boolean {
        if (consumed) return false
        consumed = true
        return true
    }
}

/**
 * 越界 overscroll 是否计为一次章节边界手势。
 * 必须先确认方向对应边界，再消耗 [gate]，避免方向抖动白白吞掉本手势配额。
 */
fun tryAcceptEdgeOverscroll(
    overscroll: Float,
    atChapterEdge: (towardEnd: Boolean) -> Boolean,
    gate: EdgeGestureGate,
    minAbs: Float = 6f,
): Boolean {
    if (kotlin.math.abs(overscroll) < minAbs) return false
    val towardEnd = overscroll > 0
    if (!atChapterEdge(towardEnd)) return false
    return gate.allow()
}
