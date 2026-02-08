Audit this project's knowledge system and migrate from older versions if needed.

## Quick Check (Do This First)

Run these 2 checks on the project root CLAUDE.md. If BOTH pass, report "Knowledge system is current. All checks passed." and stop — do NOT run the full audit.

1. **Routing table exists**: CLAUDE.md has a "Required Reading" heading (or similar) with a markdown table mapping file patterns to docs
2. **Capture process exists**: CLAUDE.md has a "When You Struggle" heading

If either fails, proceed with Full Audit.

## Full Audit

### 1. Routing Table
- Does the project root CLAUDE.md exist?
- Does it have a routing table mapping **file-pattern globs** (e.g., `src/api/**`) to docs?
- Are there enough entries to cover the major areas of the codebase?
- Does it have a catch-all row for unexpected bugs pointing to LEARNINGS.md or equivalent?

### 2. Capture Process
- Does CLAUDE.md have a "When You Struggle" section with a numbered process?
- Does it include: check existing docs → add to doc → add routing entry → consider code prevention?
- Does it include a quality bar? (Only capture project-specific knowledge, not general programming knowledge)

### 3. Domain Docs
- Does the project have a docs/ directory or equivalent?
- Is there a LEARNINGS.md or equivalent for capturing gotchas?

### 4. CLAUDE.md Size Check
- Is the CLAUDE.md acting as an **index** (routing table + pointers to docs) or does it contain large blocks of inline content (code examples, detailed troubleshooting tables, deployment instructions)?
- If it contains inline content that belongs in domain docs, flag it. CLAUDE.md should be under ~120 lines for most projects.

### 5. Active Warnings (Optional)
- Does the CLAUDE.md have an `## Active Warnings` section for temporary cross-cutting concerns? (Not required, but recommend if the project doesn't have one.)

## Output Format

Report as a checklist with pass/fail. Overall rating:

- **Compliant**: All checks pass
- **Partially compliant**: Has some structure but missing components
- **Not set up**: No knowledge system in place

If not fully compliant, ask: "Want me to set up / update the knowledge system?" Follow Setup or Migration as appropriate. Do NOT make changes without approval.

---

## Migration (Old System → Current)

When legacy artifacts are detected, offer to migrate. Describe what you'll change and get approval first.

### LEARNINGS_ARCHIVE.md → Delete
- If it has real content (not just template placeholder), move entries to LEARNINGS.md under a `## Historical` section
- If it's empty/placeholder, just delete it
- Remove all references from CLAUDE.md (routing table rows, ownership table entries)

### Verbose Knowledge System Section → Simplify
If the Knowledge System section is longer than ~5 lines (explains three layers in detail, restates rules), replace with the short template below.

### Code Breadcrumbs References → Remove
If the Knowledge System section mentions `// @doc:` or `# @doc:` as a core layer, remove it.

### Ownership Table → Make Optional
If there's a knowledge-type → doc ownership table:
- **Keep it** if the project has 3+ domain docs (it helps route new knowledge to the right place)
- **Remove it** if the project only has LEARNINGS.md (the catch-all routing row is sufficient)

### Bloated CLAUDE.md → Trim
If CLAUDE.md contains large inline content blocks (code examples, troubleshooting tables, deployment details, environment variable tables), offer to move them to the appropriate domain doc and replace with a one-line pointer in the routing table.

After migration, re-run the quick check to confirm compliance.

---

## Setup Process (New Projects)

When the user agrees to set up the knowledge system, follow these steps.

### Step 1: Analyze the Codebase

1. Map project structure: top-level directories, major subsystems, monorepo packages
2. Find existing CLAUDE.md files and docs — preserve existing content
3. Identify the 5-15 most commonly edited file patterns
4. Check for existing LEARNINGS/gotcha docs (may exist under a different name)

### Step 2: Add Sections to CLAUDE.md

Add to the existing CLAUDE.md (don't rewrite the whole file):

1. **Knowledge System** (3-5 lines) — short explanation, pointer to routing table
2. **Routing table** — file-pattern → doc mappings
3. **When You Struggle** — capture process with quality bar
4. **Active Warnings** — empty section for temporary cross-cutting concerns

Use the Templates below, adapted to the project.

### Step 3: Create LEARNINGS.md (if missing)

Create `docs/LEARNINGS.md` only if no equivalent gotcha/learnings doc exists. Use the Context/Gotcha/Fix entry format (see template). Do NOT create other docs proactively — they emerge organically.

### Step 4: Verify

Re-run the quick check to confirm both criteria pass.

---

## Templates

Adapt to the project. Replace bracketed placeholders.

### Template: Knowledge System Section

````markdown
## Knowledge System

This project uses a routing table (below) to map file patterns to docs you must read before editing. When you struggle with something, capture what you learned (see [When You Struggle](#when-you-struggle-mandatory)).
````

### Template: Routing Table

````markdown
### Required Reading Before Editing

| File pattern you are editing | Read first |
|------------------------------|-----------|
| `src/[subsystem]/**` | [DOC_NAME](path/to/doc.md) |
| `**/*.test.*` | [TESTING.md](docs/TESTING.md) |
| `[config/deploy files]` | [relevant doc](path/to/doc.md) |
| `[managed-dir]/**` | Do NOT edit — managed by [tool]. Use [command] instead |
| Weird bug or unexpected behavior | [LEARNINGS.md](docs/LEARNINGS.md) — search for the symptom |
````

**Tips:**
- One entry per major directory or subsystem
- Always include LEARNINGS.md catch-all as the last row
- Use specific glob patterns (`src/api/**`), not vague categories ("API code")
- Include prohibition entries for auto-managed directories

### Template: When You Struggle

````markdown
### When You Struggle (Mandatory)

If a fix takes more than one attempt:

1. **Check if documented** — search `docs/` for the key terms
2. **If documented**: improve the entry if it wasn't clear enough
3. **If new**: add to the appropriate doc (or LEARNINGS.md if unsure). Use the entry format below. Only capture things **specific to this project** or that contradict reasonable assumptions — not general programming knowledge.
4. **Add a routing entry** if no file pattern covers this area yet
5. **Consider code prevention**: can a wrapper, type guard, lint rule, or validator prevent this?
6. **Prune while you're there**: if you spot any outdated entries in the doc, fix or remove them
````

### Template: Active Warnings

````markdown
## Active Warnings

<!-- Temporary alerts for cross-cutting concerns. Remove when resolved. -->

*(None currently.)*
````

### Template: LEARNINGS.md Entry Format

When adding entries to LEARNINGS.md, use this format:

````markdown
### [Short descriptive title]

**Context**: What you were doing when you hit this.
**Gotcha**: What went wrong or what's surprising.
**Fix**: The correct approach (1-3 lines).
````

Keep entries concise. Code blocks only when essential (e.g., the correct incantation isn't obvious from prose). If an entry reads like a tutorial for general programming concepts, it doesn't belong here.

### Template: Ownership Table (Optional — for projects with 3+ domain docs)

````markdown
| Knowledge type | Authoritative location |
|----------------|----------------------|
| [category] | [doc](path/to/doc.md) |
| Library quirks, build/deploy | [LEARNINGS.md](docs/LEARNINGS.md) |
````

---

## Subdirectory CLAUDE.md Guidance

Create a subdirectory CLAUDE.md only when a directory is a semi-independent subsystem with its own patterns, or has critical gotchas that must be seen before any edit.

Keep them short (15-30 lines): one-line purpose, mini routing table (3-8 entries), critical gotchas only. Don't duplicate root CLAUDE.md content.
