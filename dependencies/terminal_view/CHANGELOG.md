## [0.2.1] - 2026-09-05

* Fix the return key submitting twice on iOS: the platform writes a newline into the editing value *and* reports a newline input action for the same tap, and both halves were forwarded, so one tap ran the command twice. The second half of a back-to-back pair is now dropped. Keyboards that report only one half are unaffected - Android, whose keyboard is configured for a single line, only reports the action.
* Send return as CR however the keyboard reports it. An inserted newline used to be written through as LF, which a program reading in raw mode does not take for a return.

## [0.2.0] - 2026-09-02

* Stop drawing underlined text (SGR 4). The attribute is still parsed and tracked; it is no longer painted, since an underline on a one-line-tall grid row collides with the descenders above it and with the cursor and selection below.

## [0.1.5] - 2026-08-22

* Fix cursor landing on the wrong column after a resize (saved cursor position wasn't clamped to the new size).
* Fix erase/insert/delete operations acting on an empty range when the cursor was in the pending-wrap column.
* Fix backspace at end of line moving two columns instead of one.
* Fix EL/ED "to cursor" leaving the cursor cell itself unerased.
* Fix DECSTBM (`CSI r`) not moving the cursor home, and `CSI 1;0r` collapsing the region to nothing.
* Fix arrow keys following the numeric-keypad mode instead of DECCKM.
* Fix glyph runs drifting off the character grid when a fallback or bold font has a different advance width.

## [0.1.4] - 2026-08-16

* Draw non-ASCII glyphs at natural size with corrected letter-spacing instead of scaling - fixes distorted box-drawing, CJK and emoji.
* Fix 1px offset between line text and cursor/selection at fractional scroll.
* Keep combining marks and ZWJ emoji sequences instead of dropping them.
* Render underline, strikethrough, invisible and blinking text.
* Add `TerminalTheme.cursorAccent` to keep the glyph under a block cursor visible.
* Add `TerminalTheme.drawBoldTextInBrightColors`.
* Add `TerminalTheme.selectionForeground` for guaranteed contrast in a selection.
* Add `TerminalTheme.minimumContrastRatio`.
* SGR 22 now clears both bold and faint, not just faint.
* Fix kitty keyboard protocol and DEC private mode sequences being wrongly treated as cursor save/restore, teleporting the cursor (broke React Ink UIs such as Claude Code).
* Swallow DCS/SOS/PM/APC sequences instead of printing their body.
* Honour DECAWM (`?7l`) instead of wrapping anyway.
* Keep a wide glyph whole instead of splitting it across lines.
* Count emoji columns correctly: `U+FE0F` widens the previous character, a ZWJ sequence costs one glyph's width, skin tone modifiers cost nothing extra.
* Update character width tables from Unicode 11 to Unicode 16.
* Map the cursor through reflow instead of leaving it on the wrong row after a resize.
* Support IRM (`CSI 4 h` insert mode).
* Add CBT, CHT, HPA, HPR, VPR; fix CUU/CUD running out of the scroll region.
* Add DECSTR, RIS, DECRQM and DECSCUSR (`Terminal.cursorShape`).
* Support synchronized output (`?2026`), with a 150ms failsafe.
* Fix HTS (`ESC H` was testing for a tab stop instead of setting one).
* Report a one-based cursor position from DSR, relative to the scroll region under origin mode.
* Report `VT220` with ANSI colour from primary DA instead of `VT100`.
* Reparse an escape that aborts an OSC instead of dropping it.
* Keep the blanks a program never wrote (tab/cursor-move gaps) when copying text, so `ls -l`, `git log --graph` and other column-aligned TUIs copy correctly.

## [0.1.3] - 2026-08-14

* Fix null-check crash in `IndexAwareCircularBuffer.[]`. Shrinking
  `maxLength` left `_length` bigger than the new backing array, so `push`
  never detected a full buffer and `_length` grew unbounded until reads
  landed on a dropped slot.

## [0.1.2] - 2026-08-02

* Fire `TerminalView.onTapUp`. The callback reached `TerminalGestureDetector`
  and stopped there - only `onSingleTapUp` was wired to the tap recogniser -
  so no tap ever reported its cell to the embedder. Like `onSingleTapUp`, it
  skips the second tap of a double tap. Like `onSingleTapUp`, it
  skips the second tap of a double tap.

## [0.1.1] - 2026-08-01

* Pin every cell's line box and baseline to the primary font with a strut, so
  a glyph resolved from `fontFamilyFallback` sits on the same baseline as the
  text beside it instead of riding high. Each cell is laid out as its own
  paragraph, so without a strut it took its metrics from whichever font
  happened to carry its glyph.
* Split leading evenly rather than in proportion to each font's own ascent,
  for the same reason.

## [0.1.0] - 2026-08-01

First release under the name `terminal_view`, forked from `xterm` 4.0.0.

* Renamed the package. Imports move from `package:xterm/xterm.dart` to
  `package:terminal_view/terminal_view.dart`.
* Coalesce terminal writes per frame, and parse chunks in place instead of
  expanding them into rune lists.
* Batch neighbouring cells that share a style into one paragraph, and
  neighbouring backgrounds into one rect.
* Record lines that stop changing as pictures and replay them.
* Blink the cursor from the render object, so it repaints instead of
  rebuilding the widget tree.
* Allow a selection to start on a blank cell or an empty line, and keep both
  ends inclusive when dragging either selection handle.

---

Everything below is the history of `xterm.dart`, which this package is
forked from.

## [4.0.0] - 2024-02-27
* Update for Flutter 3.19 [#190]. Thanks [@domesticmouse].
* Fix designate charset logic [#186]. Thanks [@djnalluri].

## [3.6.1-pre] - 2023-04-28
* Add Termianl.onPrivateOSC callback
* Copy shortcut on Windows default to Ctrl+Shift+V (#173)

## [3.6.0-pre] - 2023-04-27
* Basic ZMODEM support

## [3.5.0] - 2023-04-20
* Support customizing word separators for selection [#160]. Thanks [@itzhoujun].
* Fix incorrect tab stop handling [#161]. Thanks [@itzhoujun].
* Added support for Ctrl+Home, Ctrl+End etc [#169]. Thanks [@nuc134r].

## [3.4.1] - 2023-01-27
* Fix Flutter 3.7 incompatibilities [#151], thanks [@jpnurmi].

## [3.4.0] - 2022-11-4
* Mouse input is enabled by default.
* Support scrolling in alternate buffer.
* Fix `deleteLines` behavior.
* Fix `eraseDisplayFromCursor` removes characters before the cursor.

## [3.3.0] - 2022-10-30
* Sync ShortcutManager's shortcuts in didUpdateWidget [#140], thanks [@jpnurmi].
* fix: terminal font size not respecting system level font scale [#138], thanks [@LucasAschenbach].
* Fix selection color [#135], thanks [@jpnurmi].
* fix: dispose controllers of TerminalView [#132], thanks [@tauu].
* feat: add hardwareKeyboardOnly flag to TerminalView [#131], thanks [@tauu].
* feat: initial mouse support [#130], thanks [@tauu].
* feat: limited window manipulation support [#129], thanks [@tauu].
* fix: workaround to draw underlined spaces [#128], thanks [@tauu].
* feat: block selection [#127], thanks [@tauu].
* feat: enable changing the inputHandler of a terminal [#126], thanks [@tauu].
* fix: export TerminalTargetPlatform [#125], thanks [@tauu].
* fix: only dispose the FocusNodes which TerminalView creates [#124], thanks [@tauu].
* feat: expose readOnly flag of CustomTextEdit in TerminalView [#123], thanks [@tauu].
* fix: supports numpad enter key [#137].
* feat: expose `reflowEnabled` flag [#104].
* docs: add virtual keyboard example [#141].

## [3.2.7] - 2022-9-13
* Fix lint issues.

## [3.2.6] - 2022-9-13
* First stable release of xterm.dart v3.

## [3.2.6-alpha] - 2022-9-13
* Fix new line width in reflow.

## [3.2.5-alpha] - 2022-9-12
* Fix intent related issue.

## [3.2.4-alpha] - 2022-9-12
* Use flutter native shortcut intents.

## [3.2.3-alpha] - 2022-9-12
* Export shortcut related classes.

## [3.2.2-alpha] - 2022-9-12
* Implement default keyboard shortcuts.

## [3.2.1-alpha] - 2022-9-12
* Disable optional line scroll mode that is under development.

## [3.2.0-alpha] - 2022-9-12
* Enhanced selection handing.
* More tests.

## [3.1.0-alpha] - 2022-9-4
* Update dependencies & merge into master

## [3.0.6-alpha] - 2022-4-4
* Export `TerminalViewState`
* Added `onTap` callback to `TerminalView`

## [3.0.5-alpha] - 2022-4-4
* Avoid resize when `RenderBox.size` is zero.
* Added `charInput` and `textInput`method.
* Added `requestKeyboard`, `closeKeyboard` and `hasInputConnection`method.
* Export `KeyboardVisibilty`

## [3.0.4-alpha] - 2022-4-1
* Improved text editing
* Added composing state painting
* Adapt to `MediaQuery.padding`

## [3.0.3-alpha] - 2022-3-28
* Improved scroll handing
* Improved resize handing
* Fix focus repaint
* Fix OSC title update

## [3.0.2-alpha] - 2022-3-28
* Re-design `KeyboardVisibilty`

## [3.0.1-alpha] - 2022-3-27
* Add `KeyboardVisibilty`

## [3.0.0-alpha] - 2022-3-26
* Initial release of v3.

## [2.6.0] - 2021-12-28
* Add scrollBehavior field to the TerminalView class [#55].
* Feature: Search [#60]. Thanks [@devmil].
* Fixes for occasional unintended multi character input [#61]. Thanks [@devmil].
* Fixes ALT + L for a Mac (German Layout) [#62]. Thanks [@devmil].
* Fixes example build problem of flutter-windows for new version of flutter [#63]. Thanks [@linhanyu].
* Fixes inverse color text (when background == 0) [#66]. Thanks [@devmil].
* Fixes assert of scrollController.position [#67]. Thanks [@linhanyu].
* Change interface of ssh.dart example to satisfied new dartssh [#69]. Thanks [@linhanyu].
* add configuration options for keyboard [#74]. Thanks [@jda258].
* Adds check if the TerminalIsolate has already been started  [#77]. Thanks [@devmil].

## [2.5.0-pre] - 2021-8-4
* Support select word / whole row via double tap [#40]. Thanks [@devmil].
* Adds "selectAll" to TerminalUiInteraction [#43]. Thanks [@devmil].
* Fixes sgr processing [#44],[#45]. Thanks [@devmil].
* Adds blinking Cursor support [#46]. Thanks [@devmil].
* Fixes Zoom adaptions on non active buffer [#47]. Thanks [@devmil].
* Adds Padding option to TerminalView  [#48]. Thanks [@devmil].
* Removes no longer supported LogicalKeyboardKey  [#49]. Thanks [@devmil].
* Adds the composing state [#50]. Thanks [@devmil].
* Fix scroll problem in mobile device [#51]. Thanks [@linhanyu].

## [2.4.0-pre] - 2021-6-13
* Update the signature of TerminalBackend.resize() to also receive dimensions in
 pixels[(#39)](https://github.com/TerminalStudio/xterm.dart/pull/39). Thanks [@michaellee8](https://github.com/michaellee8).

## [2.3.1-pre] - 2021-6-1
* Export `theme/terminal_style.dart`

## [2.3.0-pre] - 2021-6-1
* Add `import 'package:terminal_view/isolate.dart';`

## [2.2.1-pre] - 2021-6-1
* Make BufferLine work on web.

## [2.2.0-pre] - 2021-4-12

## [2.1.0-pre] - 2021-3-20
* Better support for resizing and scrolling.
* Reflow support (in progress [#13](https://github.com/TerminalStudio/xterm.dart/pull/13)), thanks [@devmil](https://github.com/devmil).

## [2.0.0] - 2021-3-7
* Clean up for release

## [2.0.0-pre] - 2021-3-7
* Migrate to nnbd

## [1.3.0] - 2021-2-24
* Performance improvement.

## [1.2.0] - 2021-2-15

* Pass TerminalView's autofocus to the InputListener that it creates. [#10](https://github.com/TerminalStudio/xterm.dart/pull/10), thanks [@timburks](https://github.com/timburks)

## [1.2.0-pre] - 2021-1-20

* add the ability to use fonts from the google_fonts package [#9](https://github.com/TerminalStudio/xterm.dart/pull/9)

## [1.1.1+1] - 2020-10-4

* Update readme


## [1.1.1] - 2020-10-4

* Add brightWhite to TerminalTheme

## [1.1.0] - 2020-9-29

* Fix web support.

## [1.0.2] - 2020-9-29

* Update link.

## [1.0.1] - 2020-9-29

* Disable debug print.

## [1.0.0] - 2020-9-28

* Update readme.

## [1.0.0-dev] - 2020-9-28

* Major issues are fixed.

## [0.1.0] - 2020-8-9

* Bug fixes

## [0.0.4] - 2020-8-1

* Revert version constrain

## [0.0.3] - 2020-8-1

* Update version constrain


## [0.0.2] - 2020-8-1

* Update readme


## [0.0.1] - 2020-8-1

* First version


[@devmil]: https://github.com/devmil
[@michaellee8]: https://github.com/michaellee8
[@linhanyu]: https://github.com/linhanyu
[@jda258]: https://github.com/jda258
[@jpnurmi]: https://github.com/jpnurmi
[@LucasAschenbach]: https://github.com/LucasAschenbach
[@tauu]: https://github.com/tauu
[@itzhoujun]: https://github.com/itzhoujun
[@nuc134r]: https://github.com/nuc134r
[@djnalluri]: https://github.com/djnalluri
[@domesticmouse]: https://github.com/domesticmouse


[#40]: https://github.com/TerminalStudio/xterm.dart/pull/40
[#43]: https://github.com/TerminalStudio/xterm.dart/pull/43
[#44]: https://github.com/TerminalStudio/xterm.dart/pull/44
[#45]: https://github.com/TerminalStudio/xterm.dart/pull/45
[#46]: https://github.com/TerminalStudio/xterm.dart/pull/46
[#47]: https://github.com/TerminalStudio/xterm.dart/pull/47
[#48]: https://github.com/TerminalStudio/xterm.dart/pull/48
[#49]: https://github.com/TerminalStudio/xterm.dart/pull/49
[#50]: https://github.com/TerminalStudio/xterm.dart/pull/50
[#51]: https://github.com/TerminalStudio/xterm.dart/pull/51


[#55]: https://github.com/TerminalStudio/xterm.dart/pull/55
[#60]: https://github.com/TerminalStudio/xterm.dart/pull/60
[#61]: https://github.com/TerminalStudio/xterm.dart/pull/61
[#62]: https://github.com/TerminalStudio/xterm.dart/pull/62
[#63]: https://github.com/TerminalStudio/xterm.dart/pull/63
[#66]: https://github.com/TerminalStudio/xterm.dart/pull/66
[#67]: https://github.com/TerminalStudio/xterm.dart/pull/67
[#69]: https://github.com/TerminalStudio/xterm.dart/pull/69
[#74]: https://github.com/TerminalStudio/xterm.dart/pull/74
[#77]: https://github.com/TerminalStudio/xterm.dart/pull/77

[#104]: https://github.com/TerminalStudio/xterm.dart/issues/104
[#123]: https://github.com/TerminalStudio/xterm.dart/pull/123
[#124]: https://github.com/TerminalStudio/xterm.dart/pull/124
[#125]: https://github.com/TerminalStudio/xterm.dart/pull/125
[#126]: https://github.com/TerminalStudio/xterm.dart/pull/126
[#127]: https://github.com/TerminalStudio/xterm.dart/pull/127
[#128]: https://github.com/TerminalStudio/xterm.dart/pull/128
[#129]: https://github.com/TerminalStudio/xterm.dart/pull/129
[#130]: https://github.com/TerminalStudio/xterm.dart/pull/130
[#131]: https://github.com/TerminalStudio/xterm.dart/pull/131
[#132]: https://github.com/TerminalStudio/xterm.dart/pull/132
[#135]: https://github.com/TerminalStudio/xterm.dart/pull/135
[#137]: https://github.com/TerminalStudio/xterm.dart/issues/137
[#138]: https://github.com/TerminalStudio/xterm.dart/pull/138
[#140]: https://github.com/TerminalStudio/xterm.dart/pull/140
[#141]: https://github.com/TerminalStudio/xterm.dart/pull/141

[#151]: https://github.com/TerminalStudio/xterm.dart/pull/151

[#160]: https://github.com/TerminalStudio/xterm.dart/pull/160
[#161]: https://github.com/TerminalStudio/xterm.dart/pull/161
[#169]: https://github.com/TerminalStudio/xterm.dart/pull/169

[#186]: https://github.com/TerminalStudio/xterm.dart/pull/186
[#190]: https://github.com/TerminalStudio/xterm.dart/pull/190
 
