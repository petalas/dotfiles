- Always use the ?? operator instead of || for setting default values (for example empty arrays)

## Three-Layer Knowledge System (Standard for All Projects)

Every project should use this system to prevent repeating mistakes across sessions. When starting work on a project that doesn't follow this system, ask the user if they want to set it up.

### The Three Layers

1. **Routing table** (CLAUDE.md, auto-loaded) — file-pattern → doc mappings telling the agent which doc to read before editing which files
2. **Code breadcrumbs** (`// @doc: path#section`) — in-file pointers to relevant docs, discovered when reading source. Add organically as files are touched.
3. **Domain docs** (docs/*.md) — authoritative knowledge, read on demand via layers 1-2

### Rules

- Each fact lives in ONE authoritative doc. Other references are pointers only — no duplication.
- MEMORY.md should contain pointers to project docs + unique knowledge only. Never duplicate project doc content here.
- If a gotcha can be prevented by code (wrapper, type guard, lint rule), implement the code fix. Once proven, archive the doc entry.

### When You Struggle (5-Step Capture Process)

If a fix takes more than one attempt:

1. **Check if documented** — grep docs/ for key terms
2. **If documented**: improve the entry if it wasn't clear enough
3. **If new**: add to the ONE authoritative doc
4. **Add a routing entry** to CLAUDE.md if no file pattern covers this area yet
5. **Consider code prevention**: wrapper, type guard, lint rule, or validator

### What a Compliant Project CLAUDE.md Should Have

- A **Knowledge System** section explaining the three layers
- A **Required Reading** routing table mapping file patterns to docs
- A **When You Struggle** section with the 5-step capture process
- A knowledge-type → authoritative-doc ownership table

### Checking Compliance

Use the `/knowledge-audit` slash command to check any project. Do NOT proactively audit on every session start — only when asked or when you notice the project lacks a routing table.

### Setting Up a New Project

When a project lacks the knowledge system and the user agrees to set it up:

1. **Analyze the codebase** — scan for `docs/`, existing CLAUDE.md files, project structure, and common file patterns
2. **Add three sections to the project CLAUDE.md** — "Knowledge System" (three-layer explanation), "Required Reading Before Editing" (routing table with file-pattern globs), and "When You Struggle" (capture process + ownership table)
3. **Create `docs/LEARNINGS.md`** if no equivalent exists — for capturing gotchas
4. **Create `docs/LEARNINGS_ARCHIVE.md`** if no equivalent exists — for graduated entries
5. **Structure MEMORY.md** as pointers + unique knowledge only (if it exists; don't create proactively)

Run `/knowledge-audit` for templates and detailed step-by-step guidance.
