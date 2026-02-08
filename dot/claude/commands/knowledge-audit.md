Audit this project's documentation against the three-layer knowledge system standard.

## Quick Check (Do This First)

Run these 4 fast checks on the project root CLAUDE.md. If ALL pass, report "Knowledge system is active. All quick checks passed." and stop — do NOT run the full audit.

1. **Routing table exists**: Grep CLAUDE.md for a markdown table with file-pattern entries — look for lines matching `\|.*\*.*\|` (table rows containing glob patterns like `apps/mobile/**`)
2. **Knowledge System section exists**: Grep CLAUDE.md for `Knowledge System` as a heading
3. **Capture process exists**: Grep CLAUDE.md for `When You Struggle` as a heading
4. **Single-source-of-truth rule stated**: Grep CLAUDE.md for `ONE authoritative doc`

If any check fails, report which ones failed and proceed with the full audit below.

## Full Audit

### 1. CLAUDE.md Routing Table
- Does the project root CLAUDE.md exist?
- Does it have a "Required Reading" section with a **file-pattern → doc** routing table?
- Are the routing entries specific file patterns (e.g., `apps/mobile/**`) rather than vague categories (e.g., "Mobile UI")?
- Are there at least 5 routing entries covering the major areas of the codebase?

### 2. Knowledge System Section
- Does CLAUDE.md have a "Knowledge System" section explaining the three-layer approach (routing table, code breadcrumbs, domain docs)?
- Does it state the single-source-of-truth rule (each fact lives in ONE authoritative doc)?

### 3. Capture Process
- Does CLAUDE.md have a "When You Struggle" section with a numbered step-by-step process?
- Does it include a knowledge-type → authoritative-doc ownership table?
- Does the process include the step about adding routing entries for uncovered file patterns?
- Does the process include the step about considering code prevention (wrappers, type guards, lint rules)?

### 4. Deduplication
- Check if any MEMORY.md exists for this project under ~/.claude/projects/. If so, does it duplicate content from project docs, or does it use pointers?
- Are there multiple CLAUDE.md files in the repo (subdirectories)? If so, do they use routing-table format pointing to authoritative docs rather than duplicating content?

### 5. Code Breadcrumbs
- Search for `// @doc:` comments in the codebase. Are there any? (Having zero is fine for new adoption — just note it.)

### 6. Domain Docs
- Does the project have docs/ or similar documentation directory?
- Is there a LEARNINGS.md or equivalent for capturing gotchas?
- Is there a LEARNINGS_ARCHIVE.md or equivalent for graduated/one-time entries?

## Output Format

Report findings as a checklist with pass/fail for each item. Then provide an overall compliance rating:

- **Compliant**: All checks pass
- **Partially compliant**: Has some structure but missing key components
- **Not set up**: No knowledge system in place

If not fully compliant, ask the user: "This project is [rating]. Want me to set up the three-layer knowledge system?" and if they agree, follow the Setup Process below. Do NOT make changes without approval.

---

## Setup Process (After Audit)

When the user agrees to set up the knowledge system, follow these steps in order.

### Step 1: Analyze the Codebase

Before creating anything, gather information:

1. List existing docs: `find . -name "*.md" -path "*/docs/*" -maxdepth 3` and read their headings
2. Map the project structure: identify top-level directories, major subsystems, and any monorepo packages
3. Find existing CLAUDE.md files: `find . -name "CLAUDE.md"` — these may already contain conventions to preserve
4. Identify file patterns: determine the 5-15 most commonly edited areas and what doc each maps to
5. Check for existing LEARNINGS/gotcha files: they may exist under a different name

### Step 2: Add Knowledge System Sections to CLAUDE.md

Add three sections to the existing project CLAUDE.md. Do NOT rewrite the entire file — preserve all existing content and insert the new sections in logical locations.

**Placement guidance:**
- "Knowledge System" section: after any project overview or documentation index, before conventions
- "Required Reading Before Editing" routing table: inside or near a Conventions section
- "When You Struggle" + ownership table: immediately after the routing table

Use the Templates below, adapting them to the project's actual docs and structure.

### Step 3: Create Domain Docs (if missing)

- Create `docs/LEARNINGS.md` using the template below if no equivalent exists
- Create `docs/LEARNINGS_ARCHIVE.md` using the template below if no equivalent exists
- Do NOT create other docs proactively — they should emerge organically as knowledge is captured

### Step 4: Structure MEMORY.md (if it exists)

If a MEMORY.md exists for this project under `~/.claude/projects/`, restructure it to have:
- A "Pointers" section with references to project docs (not duplicated content)
- A "Unique Knowledge" section for things not captured in any project doc

If no MEMORY.md exists, do not create one — it will be created naturally as sessions produce unique knowledge.

### Step 5: Verify

After making changes, re-run the quick check to confirm all 4 criteria pass:
1. Routing table with glob patterns exists
2. "Knowledge System" heading exists
3. "When You Struggle" heading exists
4. "ONE authoritative doc" phrase exists

---

## Templates

Adapt these to the project. Replace bracketed placeholders with actual values.

### Template: Knowledge System Section

````markdown
## Knowledge System

This project uses a three-layer system to prevent repeating mistakes:

1. **Routing table** (this file, "Required Reading" section) — maps file patterns to docs you must read first
2. **Code breadcrumbs** (`// @doc: path#section`) — in-file pointers to relevant docs, discovered when reading source
3. **Domain docs** (`docs/*.md`) — authoritative knowledge, read on demand via layers 1-2

**Rules:**
- Each fact lives in ONE authoritative doc. Other references are pointers only — no duplication.
- When you struggle, document immediately (see [When You Struggle](#when-you-struggle-mandatory)).
- If a gotcha can be prevented by code (wrapper, type guard, lint rule), implement the code fix. Once proven, archive the doc entry.
````

### Template: Required Reading Routing Table

Generate entries by matching major directories and file patterns to their corresponding docs. Every project should have at least 5 entries. Common patterns:

````markdown
### Required Reading Before Editing

Before modifying code, find the matching file pattern and **read the linked doc first** — do not guess:

| File pattern you are editing | Read first |
|------------------------------|-----------|
| `src/[subsystem]/**` | [DOC_NAME](path/to/doc.md) |
| `**/*.test.*` | [TESTING.md](docs/TESTING.md) |
| `[config/deploy files]` | [relevant doc](path/to/doc.md) |
| `[components/ui dir]/**` | Do NOT edit — [managed by X]. Use [correct command] |
| Weird bug or unexpected behavior | [LEARNINGS.md](docs/LEARNINGS.md) — search for the symptom |
````

**Tips for generating routing entries:**
- One entry per major directory or subsystem
- One entry for test files (if testing docs exist)
- One entry for config/deployment files (if deployment docs exist)
- Always include the LEARNINGS.md catch-all as the last row
- Subdirectory CLAUDE.md files that are auto-loaded should be noted as "(auto-loaded)"
- Use specific glob patterns (`src/api/**`), not vague categories ("API code")
- Include prohibition entries for auto-managed directories (e.g., shadcn components)

### Template: When You Struggle + Ownership Table

````markdown
### When You Struggle (Mandatory)

If a fix takes more than one attempt, follow these steps BEFORE moving on:

1. **Check if it's already documented** — grep `docs/` for the key terms
2. **If documented**: improve the entry if it wasn't clear enough to prevent this
3. **If new**: add it to the ONE authoritative doc (see table below)
4. **Add a routing entry** to this table if it doesn't already cover this file pattern
5. **Consider code prevention**: can a wrapper, type guard, lint rule, or validator prevent this? If yes, implement it

| Knowledge type | Authoritative location |
|----------------|----------------------|
| [category, e.g., "Architecture/design"] | [doc](path/to/doc.md) |
| [category, e.g., "Testing patterns"] | [doc](path/to/doc.md) |
| Library quirks, build/deploy | [LEARNINGS.md](docs/LEARNINGS.md) |
| One-time migrations | [LEARNINGS_ARCHIVE.md](docs/LEARNINGS_ARCHIVE.md) |
````

**Tips for the ownership table:**
- Every project needs at least "Library quirks / build / deploy" -> LEARNINGS.md
- Every project needs "One-time migrations" -> LEARNINGS_ARCHIVE.md
- Add 2-4 more categories based on the project's existing docs
- Each doc should own exactly one knowledge type (no overlaps)

### Template: LEARNINGS.md

````markdown
# Learnings

> Patterns, gotchas, and insights discovered while building [PROJECT_NAME].
> This is a living document. Add new learnings as you discover them.

---

## General

*(No entries yet — add learnings as they are discovered.)*

---

## Adding New Learnings

When you discover something worth capturing:

1. Find the appropriate category (or create one)
2. Add a clear heading
3. Use the template below

### Entry Template

```
### Title

**Context**: What situation led to this discovery

**Learning**: The key insight
```
````

### Template: LEARNINGS_ARCHIVE.md

````markdown
# Learnings Archive

> Completed one-time migrations and historical learnings that are no longer actively relevant.
> Moved here to keep [LEARNINGS.md](./LEARNINGS.md) focused on recurring patterns.

---

*(No archived entries yet.)*
````

### Template: MEMORY.md Structure

When a MEMORY.md exists or needs restructuring:

````markdown
# Memory

## Pointers (authoritative docs live in the project — don't duplicate here)
- [Brief description]: see [doc path]

## Unique Knowledge (not in project docs)

### [Topic]
- [Knowledge not captured in any project doc]
````

---

## Subdirectory CLAUDE.md Guidance

Subdirectory CLAUDE.md files are auto-loaded by Claude Code when working in that directory. Use them sparingly.

### When to Create One

Create a subdirectory CLAUDE.md when a directory:
- Is a **semi-independent subsystem** with its own tech stack or patterns (e.g., a backend in a monorepo, a mobile app)
- Has **critical gotchas** that cause silent failures and must be seen before any edit
- Would need **5+ routing entries** in the root CLAUDE.md all pointing to the same subdirectory context

### When NOT to Create One

- The directory only needs 1-2 routing entries in the root table
- The content is about style preferences (put in root CLAUDE.md or a style guide doc)
- The directory is for documentation, config, or scripts

### What to Include

A subdirectory CLAUDE.md should be **short** (15-30 lines):

1. **One-line purpose** — what this directory is and when to read this file
2. **Mini routing table** — 3-8 entries for files within this subdirectory, pointing to domain docs
3. **Critical gotchas** — only things that cause silent failures, runtime crashes, or data loss

### What NOT to Include

- Full API references or extended examples (put in a domain doc, link from here)
- Anything already in the root CLAUDE.md routing table (no duplication)
- General project conventions (those belong in root CLAUDE.md)
