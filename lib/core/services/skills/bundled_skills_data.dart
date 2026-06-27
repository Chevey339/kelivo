// Built-in default skills that ship with the application.
//
// Each entry is a (directory name, file name → content) mapping.
// These are installed on first app startup and behave like any other skill
// (fully deletable by the user).
//
// To add a new default skill, add an entry to [bundledDefaultSkills].
// ignore_for_file: lines_longer_than_80_chars

/// Represents a bundled skill's file tree: skillName → { filePath → content }.
typedef BundledSkill = (String name, Map<String, String> files);

/// The list of all built-in default skills.
const List<BundledSkill> bundledDefaultSkills = [
  brainstorm,
];

// ---------------------------------------------------------------------------
// Skill: brainstorm
// ---------------------------------------------------------------------------

const brainstorm = (
  'brainstorm',
  {
    'SKILL.md': r'''---
name: brainstorm
description: Guide users through structured creative thinking and brainstorming sessions. Use when users say "I need ideas", "help me think", "give me some inspiration", "I'm stuck", "brainstorm with me", or any scenario involving creative ideation, problem-solving, planning, naming, or exploring possibilities.
---

# Brainstorming & Creative Ideation

## Overview

This skill transforms the conversation into a structured creative thinking session. It uses proven ideation frameworks to help users move from vague curiosity to concrete, actionable ideas through guided dialogue.

**Core design pattern**: Inversion + Pipeline hybrid
- **Inversion** — First, ask clarifying questions before jumping into solutions
- **Pipeline** — Then, guide the user through progressive stages: Diverge → Explore → Converge → Execute

---

## Workflow

### Phase 1: Context Gathering (Inversion)

Before generating any ideas, gather context. Ask **one question at a time** — wait for the user's response before proceeding. This creates a natural conversational rhythm.

| Step | Question |
|------|----------|
| Q1 | "What's the goal or problem you're trying to solve? What does success look like?" |
| Q2 | "Who is this for? (specific audience, yourself, or a general idea?)" |
| Q3 | "Do you have any constraints? (budget, time, resources, technical limits?)" |
| Q4 | "What have you already tried or considered?" |
| Q5 | "What's your preferred style? (practical & grounded, wild & exploratory, or balanced?)" |

> **Important**: Do NOT ask all questions at once. One at a time. Adapt and follow up naturally based on their answers.

---

### Phase 2: Framework Selection

Based on the user's responses, select the most appropriate framework:

| If the user needs to... | Recommended Framework | Reference |
|-------------------------|----------------------|-----------|
| Improve an existing idea/product/service | **SCAMPER** | `references/scamper.md` |
| Examine a decision from all angles | **Six Thinking Hats** | `references/six-thinking-hats.md` |
| Break out of a mental rut | **Reverse Thinking** | `references/reverse-thinking.md` |
| Solve a human-centered problem | **Design Thinking** | `references/design-thinking.md` |
| Explore a broad topic with many branches | **Mind Mapping** | `references/mind-mapping.md` |

If unsure, default to **SCAMPER** — it's the most versatile and widely applicable.

---

### Phase 3: Divergent Thinking (Ideation)

Guide the user through the chosen framework. Follow these rules:

1. **Quantity over quality** — Encourage as many ideas as possible without judgment
2. **Build on each other** — Use the user's previous ideas as springboards
3. **No bad ideas** — Explicitly welcome wild or impractical ideas at this stage
4. **Keep a running list** — Summarize ideas generated so far

Load the relevant reference file from `references/` and follow its prompts step by step.

---

### Phase 4: Convergent Thinking (Filtering)

After generating sufficient ideas (typically 8–15+), help the user narrow down:

1. **Cluster** similar ideas into themes/categories
2. **Evaluate** each cluster against the user's goals and constraints (from Phase 1)
3. **Ask the user to pick 2–3 favorites** and explain why they stand out
4. **For each favorite, discuss:**
   - What would it take to make this happen?
   - What's the biggest risk or challenge?
   - What's the simplest first step?

---

### Phase 5: Actionable Output

Summarize the session with a clear, structured output:

```
## Brainstorming Summary

**Goal**: [restate the user's goal]

### Top Ideas

1. **[Idea Name]**
   - Why it works: [1 sentence]
   - First step: [1 actionable step]
   - Confidence: High / Medium / Needs more thought

2. [Idea 2]
   ...

### If You Want More...
- Try combining [Idea 1] with [Idea 3]
- Flip the problem around: what if [opposite scenario]?
```

---

## Tone & Style Guidelines

- **Be encouraging and curious** — "That's interesting! What if we took that further?"
- **Use analogies and examples** to spark the user's imagination
- **Pace yourself** — don't overwhelm with too many options at once
- **Match the user's energy** — serious when they're serious, playful when they're playful
- **Celebrate small wins** — when the user says "ooh that's good!", build on that energy
- **Use emojis sparingly** — a warm tone is more important than decorations

---

## When NOT to use this skill

- The user has a simple factual question ("What's the capital of France?")
- The user wants a direct answer or specific data
- The user is frustrated and needs quick help, not exploration
- The user explicitly says "just tell me the answer"

---

## Example Session Opener

> **User**: "I want to start a side business but have no idea what to do."
>
> **AI**: "That's a great place to start! Let me ask you a couple of things to help narrow it down.
>
> First up — what kind of skills or interests do you already have? Things you genuinely enjoy doing or are good at?"
>
> *[Then proceed to Phase 2 based on the answer]*
''',
    'references/scamper.md': r'''# SCAMPER Framework

SCAMPER is a creative thinking technique that helps generate ideas by asking seven types of questions about an existing product, service, or concept.

## The Seven Techniques

### S — Substitute
- What can be substituted?
- Can we replace X with something else?
- What if we used a different material, person, process, or place?

### C — Combine
- What can be combined?
- Can we merge two ideas, products, or features?
- What if we combined this with something completely unrelated?

### A — Adapt
- What can be adapted from other domains?
- Is there something similar we can learn from?
- How would a different industry solve this?

### M — Modify / Magnify
- What can be modified?
- What if we made it bigger, smaller, stronger, lighter?
- Can we change its shape, color, or form?

### P — Put to Other Uses
- How else can this be used?
- Who else might find this useful?
- What if we used it in a completely different context?

### E — Eliminate
- What can be removed or simplified?
- What happens if we take away X?
- What's the absolute minimum viable version?

### R — Reverse / Rearrange
- What if we did the opposite?
- Can we change the order or sequence?
- What if we turned it upside down?

## How to Apply

1. Start with the user's existing idea/concept as the baseline
2. Walk through each relevant technique one at a time
3. Don't rush through all seven — pick the 3-4 most relevant based on context
4. For each technique, let the user respond before moving on
''',
    'references/six-thinking-hats.md': r'''# Six Thinking Hats Framework

The Six Thinking Hats method, developed by Edward de Bono, helps examine a problem from six distinct perspectives. Each "hat" represents a different mode of thinking.

## The Six Hats

### Blue Hat — Process & Overview
- What's the big picture?
- What do we want to achieve?
- What's the agenda for this thinking session?

### White Hat — Facts & Data
- What information do we have?
- What information is missing?
- What are the objective, verifiable facts?

### Red Hat — Feelings & Intuition
- What's your gut feeling about this?
- What emotions come up?
- No need to justify — just express feelings.

### Black Hat — Caution & Risks
- What could go wrong?
- What are the potential problems?
- What are the weaknesses or pitfalls?

### Yellow Hat — Optimism & Benefits
- What are the positive aspects?
- Why might this work?
- What are the hidden opportunities?

### Green Hat — Creativity & New Ideas
- What new ideas can we explore?
- What are alternative approaches?
- What if anything were possible?

## How to Facilitate

1. Start with **Blue Hat** to set the agenda
2. Guide the user through each hat **one at a time**
3. Common sequence: Blue -> White -> Red -> Black -> Yellow -> Green -> Blue
4. End with **Blue Hat** again to summarize and decide next steps
5. Allow the user to fully explore each perspective before switching
''',
    'references/reverse-thinking.md': r'''# Reverse Thinking Framework

Reverse Thinking (also called inversion) helps break mental blocks by approaching the problem from the opposite direction.

## Core Technique

Instead of asking "How do I achieve X?", ask these inverted questions:

| Traditional Question | Reverse Question |
|--------------------|-----------------|
| "How do I succeed?" | "How would I guarantee failure?" |
| "What should I do?" | "What should I avoid at all costs?" |
| "What's the best approach?" | "What's the worst possible approach?" |

## Application Steps

### Step 1: Define the Problem
Restate the user's goal clearly in one sentence.

### Step 2: Flip It
Ask: "What if we wanted the exact opposite outcome?"

### Step 3: Generate Opposite Ideas
- What would create the opposite result?
- What actions would guarantee disaster?
- List all the ways to make it fail

### Step 4: Invert Again
Take each "disaster idea" and flip it into a positive solution.

### Step 5: Synthesize
Combine the inverted ideas with conventional approaches.

## Conversation Flow Example

> **AI**: "Instead of asking 'how do I get more users?', let's flip it. How would you drive away every single user?"
>
> **User**: "Make the app slow and confusing..."
>
> **AI**: "Great! So the inverted solution would be: make it fast and intuitive. What else?"
''',
    'references/design-thinking.md': r'''# Design Thinking Framework

Design Thinking is a human-centered approach to creative problem-solving with five phases.

## The Five Phases

### Phase 1: Empathize — Understand the User
- Who are the people affected by this problem?
- What do they feel, need, and experience?
- What would a day in their life look like?

### Phase 2: Define — Frame the Problem
- Restate the problem from the user's perspective
- Use the format: "How might we... [solve this]?"
- What's the core challenge beneath the surface?

### Phase 3: Ideate — Generate Solutions
- Use SCAMPER or other techniques to brainstorm
- Encourage wild ideas (they often lead to practical ones)
- Aim for quantity — 10+ ideas before filtering

### Phase 4: Prototype — Create Simple Versions
- What's the simplest version of this idea?
- How can we test the core assumption with minimal effort?
- What would a rough draft or mockup look like?

### Phase 5: Test — Learn and Iterate
- How would we know if this works?
- What's the smallest experiment we can run?
- What did we learn that changes our approach?

## Adapting for Chat Sessions

In a conversation setting, focus on **Phases 1-3** (Empathize -> Define -> Ideate), as Phases 4-5 typically require real-world execution. End the session with actionable next steps the user can take on their own.
''',
    'references/mind-mapping.md': r'''# Mind Mapping Framework

Mind Mapping helps explore a topic by branching out from a central concept into related subtopics and details. It's ideal for broad, open-ended topics.

## How to Facilitate

### Step 1: Central Topic
Start with the user's core idea or question as the center.

> "What's the central topic we're exploring?"

### Step 2: Main Branches
Ask: "What are the main categories or aspects of this topic?"
- Aim for 5-7 main branches
- Use keywords, not full sentences

### Step 3: Sub-branches
For each main branch, ask: "What are the specific elements within this category?"
- Go 2-3 levels deep
- Keep it organic — don't force symmetry

### Step 4: Find Connections
Ask: "Are there interesting connections between branches?"
- Ideas that span multiple categories are often the most innovative

### Step 5: Identify Patterns
Look for:
- **Which branch has the most ideas?** — likely the user's passion area
- **Which branch has the fewest?** — a potential blind spot
- **What cross-connections emerge?** — these are often goldmines

## Example of a Mind Map in Text

```
            [Cooking Hobby]
          /        |        \
    Recipes     Tools     Techniques
    /    \       /  \        /    \
 Quick  Gourmet  Knife  Pots  Baking  Grilling
```

## Tips

- Let the user guide the branching direction
- If they get stuck on one branch, move to another
- Revisit and add to branches as new ideas emerge
- Don't be afraid to start a new branch midway through
''',
  },
);
