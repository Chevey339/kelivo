---
name: skill-creator
description: Create or improve skills, turn a conversation into reusable SKILL.md instructions, and validate their behavior. Use when the user asks to build, revise, or test a skill.
---

# Skill Creator

Help the user turn a repeatable task into a skill that works in Kelivo. Write
instructions and explain the result in the user's language.

## Understand the task

Use the current conversation first: extract the goal, inputs, expected output,
important corrections, and tools that actually worked. Ask only for missing
details that would change the skill. A clear request is enough to start drafting.

For an update, read the existing SKILL.md and the resources affected by the
change. Preserve the user's workflow and unrelated content. Treat examples as
examples; only turn a preference into a general rule when the user wants it.

## Write the skill

A skill is a directory with a UTF-8 file named exactly `SKILL.md`. Begin with
YAML frontmatter containing `name` and `description`, followed by Markdown:

```markdown
---
name: meeting-actions
description: Turn meeting notes into decisions, action items, and open questions. Use when the user asks to summarize a meeting or extract follow-up tasks.
---

# Meeting Actions

Read the provided notes and separate decisions, action items, and open questions.
For each action, include the owner and deadline when given; mark missing values
as unspecified. Keep tentative proposals distinct from agreed decisions.
```

Choose a short lowercase name using letters, digits, and hyphens, at most 64
characters. Use the same name for its directory. Write a concise description
that says what the skill does and when to use it; Kelivo shows only the first
200 characters in the model's skill list. Put detailed instructions in the body.

Include the task-specific decisions, output shape, and completion criteria that
improve the result. Keep the entrypoint focused. Add these directories only when
the task needs them:

- `references/`: detailed guidance consulted for a particular case. Link each
  reference from SKILL.md and say when to read it.
- `scripts/`: reusable, deterministic operations. Check the required runtime is
  available and execute new or changed scripts against a small example.
- `assets/`: templates or other files used in the output.

Use relative paths for resources. Avoid private absolute paths, credentials, and
instructions that assume a particular developer's computer. Refer to configured
environment variables by name when credentials are needed. Dependencies belong
in the instructions only if the workflow needs them; a Markdown-only skill
requires neither Python nor Node.js.

## Deliver in Kelivo

Use the tools and path zones shown in the current conversation. Kelivo supports
SKILL.md instructions and supporting files; Codex/Claude-specific CLI commands,
plugin manifests, subagents, and evaluation runners are not prerequisites.

- **Workspace with a working shell:** install directly into Kelivo's skills
  directory using the skills path provided in the workspace context (`/skills`
  in a sandbox, the supplied host path in native mode). For skill creation and
  updates, use `shell`: `write_file` and `edit_file` treat this directory as
  read-only. For a new skill, choose an unused directory matching its name;
  for an update, use the existing directory and preserve unrelated files.
  Write supporting files there with their relative paths intact, then write
  the complete SKILL.md last. Kelivo rescans installed skills after shell
  commands, so saving here installs the skill without a separate import.
- **No workspace or no working shell:** installed skills remain read-only.
  Return the complete SKILL.md in a fenced Markdown block as a draft. Explain
  that direct installation requires a bound workspace with a working shell.

After installation, read back SKILL.md and its referenced files. Link the saved
entrypoint as `kelivo://skills/<skill-directory>/SKILL.md`, using the actual
directory name and URI-encoding each path component. Claim installation only
after saving and verification succeed. New skills are enabled by default; an
assistant or conversation with an explicit skill selection may need the new
skill selected.

## Validate and refine

Before delivery, check that name and description are present, frontmatter closes
before the body, referenced files exist, and the instructions only depend on
available tools or explicitly documented prerequisites. Finish or remove draft
placeholders. Check that the skill directory contains all required files.

Use a representative request to check the intended behavior and a nearby request
that should not trigger the skill. For outputs with objective requirements,
check those requirements; for subjective work, show a sample for user feedback.
Run a small example when the necessary tools and inputs are available. Distinguish
checks actually run from suggested test prompts, and keep any test outputs outside
the skill directory unless they are useful maintained examples.

End with what the skill does, where it was installed or what is needed to install
the draft, and what was verified.
Make later changes from observed behavior and user feedback.
