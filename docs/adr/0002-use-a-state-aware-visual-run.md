# Use a state-aware visual run for installation and removal

The installation catalog previously resolved wanted/not-wanted choices through a hand-written selector and could only install. Machine presence, installation custody, destructive intent, operation progress, and post-operation results were not represented independently. Safe removal also requires a stronger confirmation boundary than replayable installation defaults.

## Decision

Use a repository-owned Go helper built with Bubble Tea v2, Bubbles v2, and Lip Gloss v2 for visual planning, differentiated confirmation, and progress rendering. Organize applications into Ensure present, Leave unchanged, Remove, and Force removal lanes. Keep inspection, preparation, catalog validation, dependency ordering, adapter execution, receipts, and run reports behind the `lib/install-plan` subprocess through `inspect`, `prepare`, and `execute` operations.

Exact removal requires an exact package registration or a validated direct-install receipt. Force removal may act without custody only through `catalog/removals.tsv`; every target is bounded and reviewed. Retained dependents block prerequisite removal, package-manager dependency protections remain active, and user data and shared prerequisites are never cleanup targets.

Persist only version-1 wanted/not-wanted plan records. Seal a version-2 prepared run with a SHA-256 approval after review; do not persist destructive outcomes. Execution derives its final removal result from reinspection and writes a permission-restricted, non-replayable report.

Distribute pinned prebuilt helper binaries for macOS and Linux on amd64 and arm64. Verify the selected artifact against the tracked SHA-256 manifest. Build locally only when artifact acquisition fails and a compatible Go toolchain already exists; never install Go to launch visual mode. Fail visual mode closed when neither route succeeds.

## Consequences

The old selector and its input contract are removed. Existing public entry points, version-1 plan records, unattended/replay behavior, catalog IDs, generated Brewfile, supported operating systems, and Bash/Zsh boundaries remain compatible. Visual execution now has a compiled runtime artifact and release workflow, while unattended execution remains shell-only.

Cleanup coverage is explicit catalog data and therefore reviewable, but incomplete coverage stays visibly disabled rather than being inferred from `PATH`. Existing direct installations remain unverified until a future successful managed install creates a matching receipt. Removal can settle as partial or blocked and can continue independent graph branches; command success alone does not establish successful removal.
