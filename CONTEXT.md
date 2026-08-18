# Machine Setup

This context describes how the dotfiles installation process is assembled for different machines and use cases.

## Language

**Installation catalog**:
The canonical set of stable installation steps, dependency groups, applications, prerequisites, defaults, and platform availability from which installation plans are resolved.
_Avoid_: Brewfile, package list, installer registry

**Installation plan**:
The ordered set of setup steps, dependency groups, and individual applications selected for a machine before installation begins.
_Avoid_: Install configuration, setup recipe

**Dependency group**:
A stable cross-platform category of related applications that can be selected as a unit while allowing its members to be customized. Its identity is shared across platforms even when membership or availability differs.
_Avoid_: Package group, preset

**Foundation**:
The visible, mandatory dependency group containing the minimum software required for the installation machinery and managed environment to function safely.
_Avoid_: Core profile, base preset

**Application**:
An individually selectable capability owned by one dependency group, with platform-specific packages or installers treated as its implementation. Selecting an application also selects any prerequisites it needs.
_Avoid_: Package, formula, cask

**Application provider**:
A coherent platform-specific way to satisfy an application through payload, support resources, and managed effects. Providers may be alternatives; every required action within the chosen provider must agree before it is complete.
_Avoid_: Package, adapter, installation method

**Support resource**:
A package source, tap, repository, or other shared catalog action needed by an application provider without itself establishing application presence.
_Avoid_: Dependency, payload

**Managed effect**:
A catalog-declared alias, launcher, service setting, group membership, or configuration change that forms part of an application provider without being its installed payload.
_Avoid_: Side effect, support resource

**Required application**:
An application shown within its ordinary dependency group but locked on because the managed environment always depends on it. Bun, Node, and Rust are required applications.
_Avoid_: Foundation package

**Application observation**:
The current machine facts for an application, expressed independently as platform availability, application presence, installation custody, removal capability, and required or optional policy. It does not express the outcome wanted from the next run.
_Avoid_: Application status, selection state

**Application presence**:
Whether an available application's complete payload is absent, partial, present, or unknown after inspection. An inspection failure is unknown, never absent.
_Avoid_: Installed flag

**Installation custody**:
How confidently present payload is attributable: managed by an exact catalog-declared mechanism or receipt, deliberately provided externally, unverified, or mixed. A command found on `PATH` does not by itself establish managed custody.
_Avoid_: Ownership, provenance

**Removal capability**:
Whether exact or force removal has a supported recipe and whether current catalog policy or retained dependents block it. It is independent of application presence and installation custody.
_Avoid_: Uninstallable flag

**Force removal**:
An explicit one-run, best-effort removal outcome for a catalog application that may use a cleanup recipe without verified installation custody while retaining dependency and user-data safeguards.
_Avoid_: Purge, forced package removal

**Cleanup recipe**:
An ordered, catalog-declared set of reviewed methods and bounded targets that Force removal may try for one application. It may remove dedicated managed support artifacts but never user data or shared prerequisites.
_Avoid_: Uninstaller, cleanup script

**Desired outcome**:
The instruction a visual run assigns to an application: ensure present, leave unchanged, remove exactly, or force removal. Only wanted or not-wanted intent survives into selection defaults; destructive outcomes belong to one confirmed run.
_Avoid_: Selection state, action

**Retained application**:
A present, partial, or unknown application not selected for removal, whether or not it remains wanted for reconciliation. Its transitive prerequisites cannot be removed without also removing the retained application.
_Avoid_: Selected application, installed dependent

**Visual run**:
The default installation mode in which a terminal selector builds and confirms an installation plan before execution becomes unattended.
_Avoid_: Interactive install, TUI mode

**Planning tree**:
The stable visual projection of dependency groups as roots and their catalog-order applications as leaves. A desired outcome assigned to a group root is applied separately to every eligible application in that subtree; shared prerequisite relationships remain a graph and are not represented as tree parentage.
_Avoid_: Dependency tree, outcome lane

**Unattended full install**:
An explicitly requested installation mode that selects every available step and application and executes without opening the visual selector.
_Avoid_: Default install, non-interactive mode

**Confirmation boundary**:
The one-way transition from visual review and differentiated confirmation into execution that accepts no further input. Wanted or not-wanted defaults are saved and one-run destructive outcomes are sealed immediately before crossing it.
_Avoid_: Submit step, install prompt

**Execution phase**:
The post-confirmation portion of a run in which the resolved plan executes in order without terminal input, continuing independent work while recording failures and blocked dependents.
_Avoid_: Background mode, batch mode

**Run report**:
A permission-restricted, non-replayable record of a confirmed run's destructive targets, attempted methods, operation results, and post-operation observations.
_Avoid_: Plan record, execution plan, log

**Reconciliation**:
Installing or restoring a selected application or managed state that is missing from the machine. Deselected applications are not reconciled.
_Avoid_: Update, upgrade

**Upgrade**:
Refreshing software or managed state that already exists on the machine, regardless of whether it remains selected for reconciliation.
_Avoid_: Reconciliation, installation

**Plan record**:
A versioned, dependency-free file containing installation-plan intent as step choices, group choices, and application overrides. It can initialize a visual run or be resolved against the current catalog for explicit replay.
_Avoid_: Profile, lockfile, package snapshot

**Installation receipt**:
Durable evidence that a direct application provider installed a particular version, payload, and set of managed effects. A receipt grants installation custody only while its evidence still matches the catalog and machine.
_Avoid_: Plan record, lockfile

**Prepared run**:
The non-replayable expansion of desired outcomes into validated providers, targets, ordering, blockers, privileges, and review content for one execution.
_Avoid_: Plan record, installation plan

**Logical operation**:
A schedulable unit of inspection, installation, removal, managed effect, or verification in a prepared run. Retries are attempts within one logical operation, and a shared transaction remains one operation regardless of how many applications observe it.
_Avoid_: Command, process, task

**Settled operation**:
A logical operation that reached any terminal outcome, including success, failure, partial completion, blocking, skipping, or cancellation. Overall progress measures settled operations rather than elapsed time or successful operations.
_Avoid_: Completed operation, percent complete

**Selection defaults**:
The most recently confirmed plan record, used to initialize a later visual run without being required to run it.
_Avoid_: Profile, preset
