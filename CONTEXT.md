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

**Required application**:
An application shown within its ordinary dependency group but locked on because the managed environment always depends on it. Bun, Node, and Rust are required applications.
_Avoid_: Foundation package

**Visual run**:
The default installation mode in which a terminal selector builds and confirms an installation plan before execution becomes unattended.
_Avoid_: Interactive install, TUI mode

**Unattended full install**:
An explicitly requested installation mode that selects every available step and application and executes without opening the visual selector.
_Avoid_: Default install, non-interactive mode

**Confirmation boundary**:
The one-way transition from terminal-based plan selection and review into execution that accepts no further input. A confirmed visual plan is saved immediately before crossing it.
_Avoid_: Submit step, install prompt

**Execution phase**:
The post-confirmation portion of a run in which the resolved plan executes in order without terminal input, continuing independent work while recording failures and blocked dependents.
_Avoid_: Background mode, batch mode

**Reconciliation**:
Installing or restoring a selected application or managed state that is missing from the machine. Deselected applications are not reconciled.
_Avoid_: Update, upgrade

**Upgrade**:
Refreshing software or managed state that already exists on the machine, regardless of whether it remains selected for reconciliation.
_Avoid_: Reconciliation, installation

**Plan record**:
A versioned, dependency-free file containing installation-plan intent as step choices, group choices, and application overrides. It can initialize a visual run or be resolved against the current catalog for explicit replay.
_Avoid_: Profile, lockfile, package snapshot

**Selection defaults**:
The most recently confirmed plan record, used to initialize a later visual run without being required to run it.
_Avoid_: Profile, preset
