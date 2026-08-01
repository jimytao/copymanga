package top.fumiama.copymangaweb.tool

/** 章节边界二次确认结果（对齐 Flutter ChapterEdgeOutcome）。 */
enum class ChapterEdgeOutcome {
    CONFIRM_NEEDED,
    OPEN_CHAPTER,
    AT_END,
}

/**
 * 章节边界二次确认状态机（对齐原生旧 isEndL/isEndR 与 Flutter ChapterEdgeGuard）。
 * 纯逻辑，无 Android 依赖，可供 JVM 单测。
 */
class ChapterEdgeGuard {
    private var hintNext = false
    private var hintPrev = false

    fun onEdge(goNext: Boolean, hasAdjacent: Boolean): ChapterEdgeOutcome {
        if (!hasAdjacent) return ChapterEdgeOutcome.AT_END
        if (if (goNext) hintNext else hintPrev) {
            if (goNext) hintNext = false else hintPrev = false
            return ChapterEdgeOutcome.OPEN_CHAPTER
        }
        if (goNext) hintNext = true else hintPrev = true
        return ChapterEdgeOutcome.CONFIRM_NEEDED
    }

    fun clear() {
        hintNext = false
        hintPrev = false
    }

    fun clearSide(goNext: Boolean) {
        if (goNext) hintNext = false else hintPrev = false
    }
}
