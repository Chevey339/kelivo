Source: [reqable/re-editor](https://github.com/reqable/re-editor), pub.dev release 0.10.0, MIT.

The library is vendored to keep wrapped text visible at the top edge after returning from a distant scroll position. `_CodeFieldRender._updateDisplayRenderParagraphs` does not correct the scroll offset for estimated offscreen heights when the viewport is already at its top edge. Kelivo's long message editor otherwise uses the original library and keeps its native paragraph editor for bidi text, non-LF line endings and accessibility navigation.

The mobile cursor reveal timer is canceled when blinking stops or the editor is disposed. Autocomplete callbacks are not scheduled when no autocomplete widget exists.

Complete `TextInputClient.updateEditingValue` messages are applied as well as delta messages, so Android hardware input and IMEs that submit complete states do not silently lose edits.

Native selection/composing-only updates modify metadata without calling the text replacement path. In plain-text mode the native buffer contains the full range of physical lines touched by the selection, with selection direction and offsets preserved. A collapsed caret still sends only its current line. Supplying the complete selected text lets Flutter distinguish replacing a cross-line selection with the base line from merely collapsing the selection; neither action is guessed from the caret position. Offsets are mapped through the native text window. The same distinction applies to delta batches after smart-delta normalization; a batch containing actual text edits still applies them. Merely moving the caret to the virtual-prefix boundary cannot trigger a backspace.

Plain IME states replace the affected physical lines atomically, including a cross-line selection replaced by a single line, or a batch that both commits a composing word and inserts a newline. The native text window already contains both unselected endpoints; they are not appended again. The final selection and composing range are retained instead of discarding the other deltas in the batch. Native composing rectangles use the controller's line-local offsets instead of remote offsets that also include the mobile prefix or other selected lines.

This checkout serves Kelivo's plain message editor. Its native input configuration keeps the original multiline keyboard, autocorrection and smart punctuation. `CodeLineOptions.plainText` disables automatic code indentation and paired-symbol deletion, retaining literal text editing.

Plain messages also treat copy/cut with a collapsed selection as no-ops, preserving both the document and existing clipboard. The default code mode retains its whole-line copy/cut behavior.

An already focused node attaches its input connection after mounting, including when a paste switches from the paragraph editor to the line editor.

Plain input also forwards the app's submit action, keyboard shortcuts and keyboard media insertion contract. A read-only transition closes the input connection; native editing callbacks cannot alter locked drafts. Mobile hardware key handling uses `onKeyEvent` and lets the app handle a key first.

Composing-range changes invalidate visible paragraphs, including committing unchanged text. Kelivo keeps Flutter's composing underline in its plain spans. Clipboard completions cannot mutate a disposed controller.

Paragraph layouts are retained only while used by the current viewport. This reuses unchanged visible lines without retaining every old text version or every previously scrolled line. The temporary preferred-line-height painter is disposed after measuring. Render diagnostics expose cached and visible paragraph counts.

Desktop selection overlays dismiss their toolbar when the editor is disposed. The deferred native composing-rectangle update is canceled when superseded or when the input connection closes, including switching between message renderers during undo/redo.

`NonCodeChunkAnalyzer` skips isolate analysis when the document has no collapsed chunks, avoiding whole-document serialization for an always-empty result. Folded documents still use the original expansion validation.

Copy-on-write segments retain their cached line counts when they share unchanged lines. Adding or replacing a line updates that count by the changed subtree's count instead of recounting the segment.

The fork also uses URI-based part declarations and current Flutter color APIs, removes the unused trace part, and updates inherited declarations for analysis on the pinned SDK. The former opacity and alpha operations keep their exact 8-bit values (`0.4` remains alpha `102`); this cleanup does not alter painting colors.
