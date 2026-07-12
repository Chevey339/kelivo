# Thinking Tag Compatibility Design

## Problem

Some Kiro-compatible proxies return legacy inline reasoning as
`<thinking>...</thinking>` inside the assistant text. Kelivo's fallback parser
currently recognizes `<think>` and `<thought>`, so the Kiro tags remain visible
in the final answer.

## Mini Control Contract

- **Primary Setpoint:** Treat a complete `<thinking>...</thinking>` block as
  legacy inline reasoning.
- **Acceptance:** The focused parser test extracts the reasoning text and keeps
  the remaining answer visible.
- **Guardrails:** Preserve the existing behavior for incomplete, mismatched,
  full-width, and plain-text inputs.
- **Boundary:** Change only the legacy tag parser and its focused test file.
- **Risks:** A model intentionally emitting a complete `<thinking>` example may
  be interpreted as reasoning, matching the existing behavior for `<think>` and
  `<thought>` examples.

## Design

Extend the parser's existing opening-tag expression with `thinking`. Continue
deriving the closing tag from the matched tag name so matching remains
case-insensitive and mismatched tags remain visible.

Do not add provider detection or a streaming state machine. The fallback parser
only runs when the message has no structured reasoning, so native Anthropic and
OpenAI-compatible reasoning fields retain priority.

## Test Scenarios

- Happy path: extract a complete lowercase `<thinking>` block.
- Compatibility: extract a complete mixed-case `<THINKING>` block.
- Boundary: keep an unclosed `<thinking>` block visible.
- Failure path: keep mismatched `<thinking>...</think>` tags visible.
- Regression: retain all existing `<think>`, `<thought>`, full-width, and plain
  text behavior.

