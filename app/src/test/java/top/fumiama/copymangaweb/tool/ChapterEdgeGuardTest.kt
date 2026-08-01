package top.fumiama.copymangaweb.tool

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 对齐 Flutter chapter_edge_guard_test.dart — 边界二次确认状态机。
 */
class ChapterEdgeGuardTest {

    @Test
    fun hasAdjacent_firstConfirm_secondOpens() {
        val guard = ChapterEdgeGuard()
        assertEquals(
            ChapterEdgeOutcome.CONFIRM_NEEDED,
            guard.onEdge(goNext = true, hasAdjacent = true),
        )
        assertEquals(
            ChapterEdgeOutcome.OPEN_CHAPTER,
            guard.onEdge(goNext = true, hasAdjacent = true),
        )
    }

    @Test
    fun noAdjacent_atEnd_doesNotArmHint() {
        val guard = ChapterEdgeGuard()
        assertEquals(
            ChapterEdgeOutcome.AT_END,
            guard.onEdge(goNext = true, hasAdjacent = false),
        )
        assertEquals(
            ChapterEdgeOutcome.CONFIRM_NEEDED,
            guard.onEdge(goNext = true, hasAdjacent = true),
        )
    }

    @Test
    fun nextAndPrevHintsAreIndependent() {
        val guard = ChapterEdgeGuard()
        assertEquals(
            ChapterEdgeOutcome.CONFIRM_NEEDED,
            guard.onEdge(goNext = true, hasAdjacent = true),
        )
        assertEquals(
            ChapterEdgeOutcome.CONFIRM_NEEDED,
            guard.onEdge(goNext = false, hasAdjacent = true),
        )
        assertEquals(
            ChapterEdgeOutcome.OPEN_CHAPTER,
            guard.onEdge(goNext = false, hasAdjacent = true),
        )
        assertEquals(
            ChapterEdgeOutcome.OPEN_CHAPTER,
            guard.onEdge(goNext = true, hasAdjacent = true),
        )
    }

    @Test
    fun clear_requiresConfirmAgain() {
        val guard = ChapterEdgeGuard()
        guard.onEdge(goNext = true, hasAdjacent = true)
        guard.clear()
        assertEquals(
            ChapterEdgeOutcome.CONFIRM_NEEDED,
            guard.onEdge(goNext = true, hasAdjacent = true),
        )
    }

    @Test
    fun clearSide_onlyClearsThatDirection() {
        val guard = ChapterEdgeGuard()
        guard.onEdge(goNext = true, hasAdjacent = true)
        guard.onEdge(goNext = false, hasAdjacent = true)
        guard.clearSide(goNext = true)
        assertEquals(
            ChapterEdgeOutcome.CONFIRM_NEEDED,
            guard.onEdge(goNext = true, hasAdjacent = true),
        )
        assertEquals(
            ChapterEdgeOutcome.OPEN_CHAPTER,
            guard.onEdge(goNext = false, hasAdjacent = true),
        )
    }
}
