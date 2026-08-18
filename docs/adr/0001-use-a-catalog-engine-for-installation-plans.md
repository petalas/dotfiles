# Use a catalog engine for installation plans

The visual installer and Zsh updater need one canonical view of steps, groups, applications, prerequisites, defaults, and platform adapters before optional dependencies are available. We will keep that information as strict declarative catalog data and place observation, plan resolution, and adapter dispatch behind a Bash subprocess with `inspect`, `prepare`, and `execute` operations, avoiding shared Bash/Zsh source code and duplicated package ownership. See [ADR-0002](0002-use-a-state-aware-visual-run.md) for the compiled visual frontend and removal boundary added later.

## Considered options

A sourceable shell catalog was rejected because it spreads parsing and compatibility constraints across Bash and Zsh callers. Per-application manifests were rejected because ordering, validation, and platform knowledge would become scattered and the resulting module would be shallow.

## Consequences

The catalog is canonical. Platform package lists and selected Brewfiles are produced from it; a full tracked Brewfile may remain only as a generated, drift-checked compatibility artifact. Existing installer functions remain adapters when they contain behavior beyond plain package installation.
