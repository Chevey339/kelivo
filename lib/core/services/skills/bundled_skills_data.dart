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
  conductingDeepResearch,
];

// ---------------------------------------------------------------------------
// Skill: conducting-deep-research
// ---------------------------------------------------------------------------

const conductingDeepResearch = (
  'conducting-deep-research',
  {
    'SKILL.md': r'''---
name: conducting-deep-research
description: Conducts comprehensive deep research on any topic using iterative search, multi-draft synthesis, cross-source verification, and structured report generation. Uses web search and a file system to create and maintain working documents throughout the research lifecycle. Use when the user needs thorough, evidence-grounded research, literature reviews, investigative reports, or policy analysis.
---

# Conducting Deep Research

You are an expert research agent with access to web search tools and a file system. Your workflow mirrors that of a professional researcher: plan, investigate, draft, verify, structure, report, and re-verify. You create files at each stage to track progress, maintain an audit trail, and iteratively refine the final output.

Copy this checklist and track your progress:

```
Research Progress:
- [ ] Phase 1 — Planning: Create research plan
- [ ] Phase 2 — Investigation: Search and collect sources
- [ ] Phase 3 — Drafting: Write initial synthesis
- [ ] Phase 4 — Cross-Verification: Fact-check sources
- [ ] Phase 5 — Outline: Build report framework
- [ ] Phase 6 — Report: Generate final report
- [ ] Phase 7 — Final Check: Re-verify everything
```

---

## Phase 1: Planning

**Goal:** Understand the topic, define research questions, and create a search strategy.

### Step 1.1 — Analyze the request

Read the user's research topic carefully. Identify:

- **Core subject:** What is the main topic?
- **Scope:** What are the boundaries (time period, geography, domain)?
- **Key questions:** What specific questions need answers?
- **Intended audience:** Who will read the report (academic, executive, general)?
- **Depth:** Is this a quick brief, a comprehensive review, or a deep investigative report?

### Step 1.2 — Create the research plan file

Create `research-plan.md` in the working directory with this structure:

```markdown
# Research Plan: [Topic]

## Research Questions
1. [Primary question]
2. [Secondary question]
3. [Tertiary question]

## Key Search Areas
- [Area 1]
- [Area 2]
- [Area 3]

## Search Strategy
- Initial queries: [3-5 broad search terms]
- Deep-dive queries: [Specific queries for each area]
- Verification queries: [Queries designed to check facts]

## Target Sources
- [Type of sources to prioritize, e.g., academic papers, news, official data]
```

Update `research-plan.md` as the research evolves — mark off completed items.

---

## Phase 2: Investigation

**Goal:** Execute the search strategy, collect sources, and record findings.

### Step 2.1 — Conduct initial broad search

Run 3-5 broad search queries to map the landscape. For each query:

1. Execute the web search
2. Read the top results
3. Note key findings, statistics, claims, and citations

### Step 2.2 — Conduct deep-dive searches

For each key area identified in the research plan, run 2-3 specific searches. Prioritize:

- Primary sources (official data, original research papers)
- Authoritative secondary sources (reputable analyses, reviews)
- Diverse perspectives (including dissenting or contrarian views)

### Step 2.3 — Create the sources brief

Create `sources-brief.md` to track what you've found:

```markdown
# Sources Brief: [Topic]

## Key Sources Found

### Source 1: [Title]
- **URL:** [Link]
- **Type:** [Academic/News/Official/Other]
- **Key Claims:** [Summary]
- **Reliability Notes:** [Any concerns about bias, currency, methodology]

### Source 2: [Title]
...
```

Add sources as you find them. Include at minimum: title, URL, type, key claims, and a brief reliability assessment.

---

## Phase 3: Drafting

**Goal:** Synthesize findings into a coherent first draft.

### Step 3.1 — Review all collected material

Read through your `research-plan.md` and `sources-brief.md`. Identify:

- **Key themes** that emerge across sources
- **Points of consensus** (where sources agree)
- **Points of disagreement** (where sources conflict)
- **Gaps** (questions that remain unanswered)

### Step 3.2 — Write the draft

Create `draft-report.md` with an initial synthesis:

```markdown
# Draft Report: [Topic]

## Executive Summary
[1-2 paragraph overview of key findings]

## Key Themes

### Theme 1: [Name]
- Evidence from sources: [citations]
- Conflicting views: [if any]

### Theme 2: [Name]
...

## Preliminary Conclusions
[Initial conclusions based on available evidence]

## Gaps and Uncertainties
- [What is still unknown or unclear]

## Sources Referenced
- [List of sources used]
```

The draft does not need to be perfectly polished. It is a working document.

---

## Phase 4: Cross-Verification

**Goal:** Critically evaluate all sources and claims. Identify weaknesses.

### Step 4.1 — Create the verification file

Create `cross-verification.md`:

```markdown
# Cross-Verification: [Topic]

## Claims Audit

### Claim 1: [Specific claim from draft]
- **Sources supporting:** [list]
- **Sources contradicting:** [list]
- **Confidence:** [High/Medium/Low]
- **Notes:** [Methodological concerns, bias, currency issues]

### Claim 2: [Specific claim]
...

## Source Quality Assessment

### Source 1: [Title]
- **Recency:** [Date published]
- **Authority:** [Is the source an expert or official body?]
- **Bias:** [Any detected bias or conflicts of interest]
- **Methodology:** [Sound/questionable/unclear]
- **Verdict:** [Trustworthy/Use with caution/Unreliable]

### Source 2: [Title]
...

## Verification Searches
Run targeted searches specifically designed to verify or refute key claims. Document the results here.
```

### Step 4.2 — Run verification searches

For each major claim with Medium or Low confidence, run a verification search. Update the verification file with results.

### Step 4.3 — Assess source quality

For each key source, assess recency, authority, bias, and methodology. Flag any unreliable sources.

**Detailed methodology for source assessment:** See [research-methodology.md](research-methodology.md)

---

## Phase 5: Outline

**Goal:** Design the structure of the final report.

### Step 5.1 — Create the report outline

Create `report-outline.md`:

```markdown
# Report Outline: [Topic]

## Proposed Structure

1. **Title**
2. **Executive Summary**
3. **Introduction**
   - Context and background
   - Research questions
   - Methodology note
4. **Section 1: [Main theme]**
   - Sub-topic A
   - Sub-topic B
5. **Section 2: [Main theme]**
   ...
6. **Cross-Cutting Analysis**
   - Points of consensus
   - Points of disagreement
7. **Conclusions and Recommendations**
8. **References**
9. **Appendix: Methodology and Search Strategy**
```

Adjust the structure based on what the research has revealed.

---

## Phase 6: Report

**Goal:** Produce the complete, polished final report.

### Step 6.1 — Write the final report

Create `final-report.md` — the finished product. Use the outline as your guide and the draft as your raw material. Requirements:

- **Format:** Professional markdown
- **Citations:** Every factual claim must include a citation to its source. Use inline citation markers like `[Source: Title](URL)` or numbered references.
- **Balance:** Present multiple perspectives where disagreements exist
- **Clarity:** Write for the intended audience identified in Phase 1
- **Transparency:** Acknowledge limitations and uncertainties

**Report template options:** See [report-templates.md](report-templates.md) for academic, executive, and investigative templates.

---

## Phase 7: Final Check

**Goal:** Re-verify the final report before delivery.

### Step 7.1 — Create the final verification log

Append to `cross-verification.md` or create a new section:

```markdown
## Final Verification

### Citation Audit
- [ ] Every factual claim has a source citation
- [ ] All URLs are correctly formatted
- [ ] Sources are correctly attributed

### Fact-Check Pass
Re-verify the 3-5 most critical claims in the report with fresh searches.

### Completeness Check
- [ ] All research questions from Phase 1 are addressed
- [ ] Gaps identified in the draft are noted in the report
- [ ] The report has an introduction, body, and conclusion
- [ ] Contradictory evidence is acknowledged
```

### Step 7.2 — Conduct final checks

1. **Re-search** the most significant claims to confirm they remain current
2. **Audit citations** — every claim should trace to a source
3. **Check completeness** — does the report answer the original research questions?

### Step 7.3 — Report summary

Upon completion, present a brief summary to the user:

```
## Research Complete

**Topic:** [Topic]
**Sources consulted:** [Number]
**Report length:** [Approximate word count]
**Confidence level:** [High/Medium — and why]
**Key limitation:** [If any significant gap remains]

The final report is in `final-report.md`.
All working documents are preserved:
- `research-plan.md`
- `sources-brief.md`
- `draft-report.md`
- `cross-verification.md`
- `report-outline.md`
```

---

## Working Principles

### Be iterative
Research is not linear. If new searches reveal contradictions, update earlier files. The checklist is a guide, not a cage.

### Be transparent
Document uncertainty. If a claim cannot be confidently verified, say so. If sources disagree, present both sides.

### Be thorough
Do not stop at the first answer. Search for counterarguments. Look for sources that challenge your emerging conclusions.

### Be efficient
Do not over-search. Once you have sufficient high-quality sources to support each section of the outline, move to drafting. You can always search more during verification.

### Use progressive disclosure
The files `research-methodology.md`, `report-templates.md`, and `verification-protocol.md` contain detailed reference material. Read them when you need deeper guidance on methodology, templates, or verification standards.

---

## Related Files

- **Research methodology details:** See [research-methodology.md](research-methodology.md)
- **Report templates:** See [report-templates.md](report-templates.md)
- **Verification standards:** See [verification-protocol.md](verification-protocol.md)
''',
    'research-methodology.md': r'''# Research Methodology Reference

## Source Quality Framework

### The CRAAP Test
Use this framework to evaluate each source:

| Criterion | Questions to Ask |
|-----------|------------------|
| **Currency** | When was this published? Has it been updated? Is the information still current for your topic? |
| **Relevance** | Does this directly address your research question? Who is the intended audience? |
| **Authority** | Who is the author/publisher? What are their credentials? Are they qualified on this topic? |
| **Accuracy** | Is the information supported by evidence? Can it be verified elsewhere? |
| **Purpose** | Why does this source exist? Is it to inform, persuade, sell, or entertain? Are there biases? |

### Source Tier System

| Tier | Description | Examples |
|------|-------------|----------|
| **Tier 1** | Peer-reviewed, primary research | Academic journals, official government data |
| **Tier 2** | Authoritative secondary sources | Major news organizations, expert analyses, institutional reports |
| **Tier 3** | Useful but lower authority | Blog posts, opinion pieces, non-expert commentary |
| **Tier 4** | Unreliable | Unsubstantiated claims, anonymous sources, known misinformation |

### Handling Disagreements Between Sources

When sources conflict:
1. Check the **evidence base** — does one source cite data and the other not?
2. Check **recency** — newer data may supersede older findings
3. Check for **methodological differences** — different methods may produce different results
4. Check **funding and bias** — who paid for each study?
5. Present both views in the report with an assessment of each

## Search Strategy Patterns

### Broad-to-Narrow
Start with general queries to map the landscape, then progressively narrow.

**Example:**
1. "AI regulation overview 2025" (broad)
2. "EU AI Act implementation status 2025" (narrower)
3. "EU AI Act compliance costs small business 2025" (specific)

### Snowball Method
Use one good source to find more:
- Check its references/citations
- Search for the authors' other work
- Search for related papers that cite this one

### Adversarial Search
Deliberately search for arguments against your emerging conclusions:
- "[claim] criticism"
- "[claim] counterargument"
- "[claim] debate"
''',
    'verification-protocol.md': r'''# Verification Protocol

## Claim Confidence Levels

| Level | Meaning |
|-------|---------|
| **High** | Multiple reliable, independent sources agree. No significant controversy. |
| **Medium** | Supported by some sources but with caveats. Some disagreement exists. |
| **Low** | Single source only. Questionable methodology. Significant disagreement. |
| **Unverified** | Claimed but not yet checked against any source. |

## Cross-Verification Checklist

For each major claim in the report:

1. **Triangulation** — Can this claim be confirmed by at least two independent sources?
2. **Recency check** — Is the supporting source current enough for this claim?
3. **Context check** — Is the claim being quoted in context, or cherry-picked?
4. **Numerical sanity check** — If numbers are cited, are they plausible?
5. **Original source check** — If a news article cites a study, read the actual study

## Citation Standards

- Every factual assertion must cite a source
- Citations should include: source title or author, publication, date, and URL
- Direct quotes must be in quotation marks with page/paragraph reference when possible
- Statistics must include the original source, not just a secondary mention
''',
  },
);
