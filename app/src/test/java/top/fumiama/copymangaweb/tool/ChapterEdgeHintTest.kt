package top.fumiama.copymangaweb.tool

import org.junit.Assert.assertEquals
import org.junit.Test

class ChapterEdgeHintTest {

    @Test
    fun pressStyle_nextAndPrev() {
        assertEquals("再次按下加载下一章", ChapterEdgeHint.message(goNext = true, scrollStyle = false))
        assertEquals("再次按下加载上一章", ChapterEdgeHint.message(goNext = false, scrollStyle = false))
    }

    @Test
    fun scrollStyle_nextAndPrev() {
        assertEquals("再次滑动加载下一章", ChapterEdgeHint.message(goNext = true, scrollStyle = true))
        assertEquals("再次滑动加载上一章", ChapterEdgeHint.message(goNext = false, scrollStyle = true))
    }

    @Test
    fun atEndMessage() {
        assertEquals("已经到头了~", ChapterEdgeHint.AT_END)
    }
}
