package top.fumiama.copymangaweb.tool

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EdgeGestureGateTest {

    @Test
    fun sameGesture_allowsOnlyOnce() {
        val gate = EdgeGestureGate()
        gate.beginGesture()
        assertTrue(gate.allow())
        assertFalse(gate.allow())
        assertFalse(gate.allow())
    }

    @Test
    fun newGesture_allowsAgain() {
        val gate = EdgeGestureGate()
        gate.beginGesture()
        assertTrue(gate.allow())
        gate.beginGesture()
        assertTrue(gate.allow())
        assertFalse(gate.allow())
    }
}

class TryAcceptEdgeOverscrollTest {

    @Test
    fun notAtEdge_doesNotConsumeGate() {
        val gate = EdgeGestureGate()
        gate.beginGesture()
        assertFalse(
            tryAcceptEdgeOverscroll(
                overscroll = 12f,
                atChapterEdge = { false },
                gate = gate,
            ),
        )
        assertTrue(
            tryAcceptEdgeOverscroll(
                overscroll = 12f,
                atChapterEdge = { true },
                gate = gate,
            ),
        )
    }

    @Test
    fun atEdge_sameGestureOnlyOnce() {
        val gate = EdgeGestureGate()
        gate.beginGesture()
        assertTrue(
            tryAcceptEdgeOverscroll(
                overscroll = 12f,
                atChapterEdge = { true },
                gate = gate,
            ),
        )
        assertFalse(
            tryAcceptEdgeOverscroll(
                overscroll = 12f,
                atChapterEdge = { true },
                gate = gate,
            ),
        )
    }

    @Test
    fun tinyOverscroll_rejectedWithoutConsumingGate() {
        val gate = EdgeGestureGate()
        gate.beginGesture()
        assertFalse(
            tryAcceptEdgeOverscroll(
                overscroll = 4f,
                atChapterEdge = { true },
                gate = gate,
            ),
        )
        assertTrue(
            tryAcceptEdgeOverscroll(
                overscroll = 12f,
                atChapterEdge = { true },
                gate = gate,
            ),
        )
    }

    @Test
    fun defaultThresholdSix_allowsJustAbove() {
        val gate = EdgeGestureGate()
        gate.beginGesture()
        assertTrue(
            tryAcceptEdgeOverscroll(
                overscroll = 6.5f,
                atChapterEdge = { true },
                gate = gate,
            ),
        )
    }

    @Test
    fun negativeOverscroll_towardStart() {
        val gate = EdgeGestureGate()
        gate.beginGesture()
        var seenTowardEnd: Boolean? = null
        assertTrue(
            tryAcceptEdgeOverscroll(
                overscroll = -10f,
                atChapterEdge = { towardEnd ->
                    seenTowardEnd = towardEnd
                    true
                },
                gate = gate,
            ),
        )
        assertFalse(seenTowardEnd!!)
    }
}
