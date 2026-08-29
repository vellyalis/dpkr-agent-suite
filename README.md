# DPKR Agent Suite

Current bundle: **1.0.3** (`FrontierLoop 0.8.2` + `Native UI Governance 1.0.4`).

The paired distribution for **FrontierLoop + Native UI Governance + the matching
global `AGENTS.md`**. The three parts are intentionally installed together:

- FrontierLoop owns engineering judgment, responsibility, debugging, performance,
  migration, verification, and safe delivery.
- Native UI Governance owns native visual direction, UI-system implementation,
  real-rendered visual QA, and purposeful motion.
- `payload/AGENTS.md` is the shared global router/constitution that makes both
  plugin families activate through the intended lazy body-load path.

The suite does not duplicate either plugin's Skill bodies. The individual plugin
repositories remain canonical owners; this repository only installs, registers,
updates, and verifies them as one bundle.

## Windows quick install

Requirements: Git, PowerShell 7+, and Codex CLI when Codex registration is desired. The normal installer verifies Codex itself; Taddkorro uses the same materialized Skill bodies.

```powershell
git clone https://github.com/vellyalis/dpkr-agent-suite.git "$env:USERPROFILE\plugins\dpkr-agent-suite"
cd "$env:USERPROFILE\plugins\dpkr-agent-suite"
.\install.ps1
```

On a clean profile that command installs everything. If
`%USERPROFILE%\.codex\AGENTS.md` already exists with different content, the
installer fails closed instead of replacing unrelated instructions. To explicitly
adopt the bundled global file, run:

```powershell
.\install.ps1 -ReplaceGlobalAgents
```

The prior file is copied to a timestamped backup before replacement.

## What gets registered

### Codex

- Both canonical plugin sources are registered in
  `%USERPROFILE%\.agents\plugins\marketplace.json` as local Personal Plugins.
- Each plugin carries `.codex-plugin/plugin.json`.
- 27 shared Skills are materialized under `%USERPROFILE%\.agents\skills`.
- The paired global router is installed at `%USERPROFILE%\.codex\AGENTS.md`.

### Taddkorro

- Each canonical plugin carries `taddkorro.plugin.json` with its Skill root.
- The same 27 canonical Skill bodies are materialized under `.agents\skills`,
  which is Taddkorro's cross-tool discovery surface.
- Materialized directories are real directories, not junctions, so Taddkorro can
  read the body inside its instruction-resolution boundary.
- Catalog discovery is not treated as activation proof; the bundled `AGENTS.md`
  requires the matching `SKILL.md` body to be read before its procedure is used.

## Verify

```powershell
.\verify.ps1
```

The verifier checks both component verifiers, Codex and Taddkorro manifests,
marketplace ownership, the exact global `AGENTS.md`, all materialized Skills,
the versioned caches, and Codex CLI's own `plugin marketplace/list` runtime
state. A marketplace file that exists but is not actually recognized by Codex
does not pass.

## Update

```powershell
.\update.ps1
```

This fast-forwards the suite checkout when possible and installs the component
versions pinned by the updated `suite.json`. Dirty or divergent Git trees fail
closed; the updater does not reset, clean, stash, or force-checkout user work.

## Source ownership

```text
GitHub FrontierLoop                  GitHub native-ui-governance
        |                                      |
        v                                      v
~/plugins/frontier-loop             ~/plugins/native-ui-governance
        |                                      |
        +---------- verified installers -------+
                           |
              ~/.codex/plugins/cache/personal/...
                           |
                  ~/.agents/skills/*

dpkr-agent-suite owns only:
  - version pins
  - marketplace registration
  - bundled global AGENTS.md
  - orchestration / verification
```

No daemon, watcher, database, background updater, or second Skill owner is added.
