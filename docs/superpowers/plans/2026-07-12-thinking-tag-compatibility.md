# Thinking Tag Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parse complete `<thinking>...</thinking>` blocks as legacy inline reasoning without changing structured reasoning behavior.

**Architecture:** Extend the existing legacy tag regular expression rather than adding provider-specific or streaming logic. Lock the behavior with focused parser tests for success and boundary cases.

**Tech Stack:** Dart, Flutter test

---

### Task 1: Add regression coverage

**Files:**
- Test: `test/thinking_tag_regex_test.dart`

- [ ] **Step 1: Add the failing and boundary tests**

```dart
test('extracts closed thinking block', () {
  const input = '<thinking>reasoning here</thinking>answer';
  final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

  expect(parsed.visibleContent, 'answer');
  expect(parsed.thinkingTexts, const ['reasoning here']);
});

test('extracts mixed-case thinking block', () {
  const input = '<THINKING>reasoning here</THINKING>answer';
  final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

  expect(parsed.visibleContent, 'answer');
  expect(parsed.thinkingTexts, const ['reasoning here']);
});

test('keeps unclosed thinking tag visible', () {
  const input = '<thinking>partial reasoning';
  final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

  expect(parsed.visibleContent, input);
  expect(parsed.thinkingTexts, isEmpty);
});

test('keeps mismatched long thinking tags visible', () {
  const input = '<thinking>reasoning</think>answer';
  final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

  expect(parsed.visibleContent, input);
  expect(parsed.thinkingTexts, isEmpty);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/thinking_tag_regex_test.dart`

Expected: the complete lowercase and mixed-case `<thinking>` extraction tests fail because the parser leaves the input visible.

### Task 2: Implement the minimal parser change

**Files:**
- Modify: `lib/features/chat/utils/thinking_tag_parser.dart`
- Test: `test/thinking_tag_regex_test.dart`

- [ ] **Step 1: Extend the existing tag expression**

```dart
static final RegExp _openTagRe = RegExp(
  r'<(think|thinking|thought)>',
  caseSensitive: false,
);
```

- [ ] **Step 2: Format the changed Dart files**

Run: `dart format lib/features/chat/utils/thinking_tag_parser.dart test/thinking_tag_regex_test.dart`

Expected: both files are formatted successfully.

- [ ] **Step 3: Run the focused test and verify GREEN**

Run: `flutter test test/thinking_tag_regex_test.dart`

Expected: all `ThinkingTagParser` tests pass.

### Task 3: Validate and publish

**Files:**
- Review: `lib/features/chat/utils/thinking_tag_parser.dart`
- Review: `test/thinking_tag_regex_test.dart`
- Review: `docs/superpowers/specs/2026-07-12-thinking-tag-compatibility-design.md`
- Review: `docs/superpowers/plans/2026-07-12-thinking-tag-compatibility.md`

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`

Expected: exit code 0 with no analysis issues.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`

Expected: exit code 0 with all tests passing.

- [ ] **Step 3: Review the final diff**

Run: `git diff --check && git status -sb && git diff upstream/master...HEAD`

Expected: only the parser, focused test, design, and plan are included; no whitespace errors are reported.

- [ ] **Step 4: Commit the implementation**

```bash
git add lib/features/chat/utils/thinking_tag_parser.dart test/thinking_tag_regex_test.dart docs/superpowers/plans/2026-07-12-thinking-tag-compatibility.md
git commit -m "fix: parse legacy thinking tags"
```

- [ ] **Step 5: Push and open a draft pull request**

```bash
git push -u origin codex/support-thinking-tag
gh pr create --repo Chevey339/kelivo --base master --head Agoniedi:codex/support-thinking-tag --draft
```

Expected: GitHub returns a draft pull request URL targeting `Chevey339/kelivo:master`.

