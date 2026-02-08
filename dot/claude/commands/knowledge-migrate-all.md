Find all projects that need knowledge system migration and report their status.

## Instructions

Scan for CLAUDE.md files in common project directories. For each one found, run the quick check from `/knowledge-audit` and report the results.

### Step 1: Find Projects

Search these directories (skip any that don't exist):
- `~/git/`
- `~/projects/`
- `~/work/`
- `~/src/`

Find all `CLAUDE.md` files at the root of git repositories (look for directories containing both `.git` and `CLAUDE.md`).

### Step 2: Quick Check Each Project

For each project found, run the 2 quick checks:
1. Has a "Required Reading" heading (or similar) with a routing table
2. Has a "When You Struggle" heading

### Step 3: Report

Output a summary table:

```
| Project | Status | Issues |
|---------|--------|--------|
| ~/git/foo | Current | — |
| ~/git/bar | Needs update | No capture process |
| ~/git/baz | Setup needed | No routing table |
```

Then list the projects that need attention with the specific `/knowledge-audit` actions that would apply to each:
- **Needs update**: projects missing components — run `/knowledge-audit` in the project to update
- **Setup needed**: projects with no knowledge system — run `/knowledge-audit` in the project to set up

Do NOT make any changes — this is a read-only discovery command.
