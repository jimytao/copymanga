package top.fumiama.copymangaweb.tool

import org.junit.Assert.assertEquals
import org.junit.Test

class ReaderTapClassifierTest {

    @Test
    fun horizontal_ltr_leftPrev_rightNext() {
        assertEquals(
            ReaderTapZone.PREV,
            ReaderTapClassifier.classify(0.1f, 0.5f, mode = "h", r2l = false),
        )
        assertEquals(
            ReaderTapZone.NEXT,
            ReaderTapClassifier.classify(0.9f, 0.5f, mode = "h", r2l = false),
        )
        assertEquals(
            ReaderTapZone.MENU,
            ReaderTapClassifier.classify(0.5f, 0.5f, mode = "h", r2l = false),
        )
    }

    @Test
    fun horizontal_r2l_swapsLeftRight() {
        assertEquals(
            ReaderTapZone.NEXT,
            ReaderTapClassifier.classify(0.1f, 0.5f, mode = "h", r2l = true),
        )
        assertEquals(
            ReaderTapZone.PREV,
            ReaderTapClassifier.classify(0.9f, 0.5f, mode = "h", r2l = true),
        )
    }

    @Test
    fun vertical_topPrev_bottomNext_centerMenu() {
        assertEquals(
            ReaderTapZone.PREV,
            ReaderTapClassifier.classify(0.5f, 0.1f, mode = "v", r2l = false),
        )
        assertEquals(
            ReaderTapZone.NEXT,
            ReaderTapClassifier.classify(0.5f, 0.9f, mode = "v", r2l = false),
        )
        assertEquals(
            ReaderTapZone.MENU,
            ReaderTapClassifier.classify(0.5f, 0.5f, mode = "v", r2l = true),
        )
    }

    @Test
    fun vertical_midBand_sidesAreNone() {
        assertEquals(
            ReaderTapZone.NONE,
            ReaderTapClassifier.classify(0.05f, 0.5f, mode = "v", r2l = false),
        )
        assertEquals(
            ReaderTapZone.NONE,
            ReaderTapClassifier.classify(0.95f, 0.5f, mode = "v", r2l = false),
        )
    }

    @Test
    fun webtoon_onlyMenuAnywhere() {
        assertEquals(
            ReaderTapZone.MENU,
            ReaderTapClassifier.classify(0.1f, 0.1f, mode = "w", r2l = false),
        )
        assertEquals(
            ReaderTapZone.MENU,
            ReaderTapClassifier.classify(0.9f, 0.9f, mode = "w", r2l = true),
        )
    }
}
