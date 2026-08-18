# Use a state-aware visual run for installation and removal

The installation catalog previously resolved wanted/not-wanted choices through a hand-written selector and could only install. Machine presence, installation custody, destructive intent, operation progress, and post-operation results were not represented independently. Safe removal also requires a confirmation boundary bound to the prepared run rather than replayable installation defaults.

## Decision

Use a repository-owned Go helper built with Bubble Tea v2, Bubbles v2, and Lip Gloss v2 for visual planning, prepared-run review and Enter confirmation, and progress rendering. Show applications as a stable, group-filtered tree: catalog groups are collapsible roots and catalog-order applications are leaves, with Ensure present, Leave unchanged, and Remove outcome counts above it. Outcome changes update nodes in place rather than moving applications between filtered lanes, preserving spatial context while making scheduled state transitions immediate. Applying an outcome to a group root updates every eligible leaf in that subtree through the same per-application safety checks. Keep inspection, preparation, catalog validation, dependency ordering, adapter execution, receipts, and run reports behind the `lib/install-plan` subprocess through `inspect`, `prepare`, and `execute` operations.

Remove is one desired outcome with automatic method selection. An absent application already satisfies Remove, so selecting it cancels any pending Ensure transition without requiring or preparing a removal method. For present, partial, or unknown applications, prefer exact removal when an exact package registration or validated direct-install receipt identifies the managed mechanism. When exact removal is unavailable, fall back automatically to the application's `catalog/removals.tsv` cleanup recipe; every target remains bounded and reviewed, and the confirming review discloses the fallback. Retained dependents block prerequisite removal, package-manager dependency protections remain active, and user data and shared prerequisites are never cleanup targets. If neither an exact mechanism nor a cleanup recipe is available, reject Remove contextually.

The complete available-application transition table is:

| Current presence | Ensure present | Leave unchanged | Remove |
|---|---|---|---|
| Absent | `absent -> present` | `absent` | `absent` (satisfied; no adapter) |
| Partial | `partial -> present` | `partial` | `partial -> removed` |
| Present | `present` | `present` | `present -> removed` |
| Unknown | `unknown -> present` | `unknown` | `unknown -> removed` |

An unavailable application renders `unavailable`; only Leave is accepted. Required policy permits only Ensure. A retained dependent blocks removal of its prerequisite at every observed presence. For non-absent optional applications, Remove is accepted with exact capability, cleanup capability, or both (exact wins), and rejected with neither. These rules apply identically to leaf and group-subtree edits.

Persist only version-1 wanted/not-wanted plan records. Choice collection exits Plan directly so the engine can prepare the exact run; do not show a preliminary choice review that duplicates the meaningful prepared review. The prepared-run review is the sole confirmation screen: Enter writes a SHA-256 approval for the exact version-2 artifact displayed, while Esc cancels; no typed application name or removal phrase is required. Do not persist destructive outcomes. Execution derives its final removal result from reinspection and writes a permission-restricted, non-replayable report.

Run the unattended engine in a new Unix session without a controlling terminal. Closing stdin is insufficient because a descendant can reopen `/dev/tty`, race the progress renderer for terminal replies, and wait indefinitely. Keep stdout, stderr, and structured events on separate pipes. Write timestamped copies of all three streams plus start/finish records to a mode-0600 latest-run log under the state directory (falling back to a mode-0600 temporary file), and display that path during progress. Do not impose a generic wall-clock timeout or blindly retry arbitrary adapters: preserve real exit statuses and post-operation inspection, while package/network adapters retain their bounded, operation-specific retry or repair policies.

Distribute pinned prebuilt helper binaries for macOS and Linux on amd64 and arm64. Verify the selected artifact against the tracked SHA-256 manifest. Build locally only when artifact acquisition fails and a compatible Go toolchain already exists; never install Go to launch visual mode. Fail visual mode closed when neither route succeeds.

## Consequences

The old selector and its input contract are removed. Existing public entry points, version-1 plan records, unattended/replay behavior, catalog IDs, generated Brewfile, supported operating systems, and Bash/Zsh boundaries remain compatible. Visual execution now has a compiled runtime artifact and release workflow, while unattended execution remains shell-only.

Cleanup coverage is explicit catalog data and therefore reviewable, but incomplete coverage is reported after a rejected removal rather than being inferred from `PATH`. Existing direct installations remain unverified until a future successful managed install creates a matching receipt. Legacy outcome selections and prepared runs that encode `force` remain accepted as cleanup-fallback requests, but new visual selections expose and write only Remove. Removal can settle as partial or blocked and can continue independent graph branches; command success alone does not establish successful removal.
