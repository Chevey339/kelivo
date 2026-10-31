package com.psyche.kelivo.input

import android.content.ClipboardManager
import android.content.Context
import android.text.Selection
import android.view.View
import android.view.inputmethod.ExtractedTextRequest
import android.view.inputmethod.InputConnection
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE)
class MirrorConnectionSelectionTest {
    private fun connection(text: String, cursor: Int) = MirrorConnection(
        View(RuntimeEnvironment.getApplication()), "selection", text, cursor, cursor,
    ) { }

    @Test fun extractionNeverPresentsAWindowAsTheFullDocument() {
        for (length in listOf(20, 2048, 3600, 1000000)) {
            val document = connection("文".repeat(length), length / 2)
            val snapshot = document.getExtractedText(ExtractedTextRequest(), 0)
            if (length <= 2048) {
                assertEquals(document.editable.toString(), snapshot!!.text.toString())
                assertEquals(0, snapshot.startOffset)
                assertEquals(length / 2, snapshot.selectionStart)
                assertEquals(length / 2, snapshot.selectionEnd)
            } else {
                assertNull(snapshot)
            }
            assertNull(document.getExtractedText(
                ExtractedTextRequest(), InputConnection.GET_EXTRACTED_TEXT_MONITOR))
            assertTrue(document.performContextMenuAction(android.R.id.selectAll))
            assertEquals(0, Selection.getSelectionStart(document.editable))
            assertEquals(length, Selection.getSelectionEnd(document.editable))
        }
    }

    @Test fun selectAllCopyCutAndPasteKeepTheWholeDocument() {
        val text = "第一行 abc\n第二行 def\n".repeat(600)
        val document = connection(text, 4000)
        val clipboard = RuntimeEnvironment.getApplication()
            .getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

        // iFlytek issues the standard select-all action when extraction is
        // unavailable, rather than deriving a range from a partial snapshot.
        assertNull(document.getExtractedText(ExtractedTextRequest(), 0))
        assertTrue(document.performContextMenuAction(android.R.id.selectAll))
        assertTrue(document.performContextMenuAction(android.R.id.copy))
        assertEquals(text, clipboard.primaryClip!!.getItemAt(0).text.toString())

        assertTrue(document.performContextMenuAction(android.R.id.cut))
        assertEquals("", document.editable.toString())
        assertEquals(text, clipboard.primaryClip!!.getItemAt(0).text.toString())
        val empty = document.getExtractedText(ExtractedTextRequest(), 0)!!
        assertEquals("", empty.text.toString())
        assertEquals(0, empty.selectionStart)
        assertEquals(0, empty.selectionEnd)
        assertTrue(document.performContextMenuAction(android.R.id.paste))
        assertEquals(text, document.editable.toString())
        assertEquals(text.length, Selection.getSelectionEnd(document.editable))
    }
}
