<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 keese-ai -->

---
scope: reference
category: reference
depends: [../designs/29-conductor-orchestration.md]
related_skills: []
status: current
last_verified: 2026-07-20
---

# koryph orchestration

Parallel agent dispatch, worktree isolation, and merge are delegated entirely to
[koryph](https://koryph.build) — an external, multi-project Go binary, not an in-repo
script. This replaced the hand-rolled `conductor/` system (see
[ADR 29](../designs/29-conductor-orchestration.md) for the requirements it originally
satisfied).

## What this repo owns

Four things, and nothing else of the orchestration mechanism:

1. **`koryph.project.json`** — gate command, area map, protected paths, copyright,
   concurrency limits.
2. **The 7 project-native personas** in `.claude/agents/` (`implementer`,
   `crd-author`, `controller-author`, `olm-author`, `guardrail-author`,
   `rebac-modeler`, `infra-bootstrap`) — these shadow koryph's generic `koryph-*`
   fallbacks by name. Every other role (architect, debugger, explorer, plan-scorer,
   security-reviewer, test-engineer) uses the installed `koryph-*` fallback directly.
3. **Beads as sole work source** (`work_source: "bd"`). No new `docs/plans/phase-*.md`
   files for dispatchable work — file a bead (`/koryph-issue`, `/koryph-plan`).
4. **`AGENTS.md`** — the runtime-neutral operating contract every agent (Claude Code or
   otherwise) follows in this repo.

Everything else — the scheduler, worktree lifecycle, budget/quota governor, merge
engine, epic validation — lives in the `koryph` binary and its per-machine registry at
`~/.koryph/`, shared across every project registered on this machine.

## Registration

This repo is registered as project id `keese` (`~/.koryph/registry.d/keese.json`),
account profile `personal`, identity `cody@mccain.family`. `KORYPH_HOME` (default
`~/.koryph`) is the cross-project registry/governor/hook-script home; it is not part of
this repo and is not committed.

## Deviations from koryph's stock contract

- **MEMORY.md stays in use.** koryph's stock `AGENTS.md` says "no MEMORY.md files, use
  `bd remember`." keese keeps `MEMORY.md` for now — a full migration of its existing
  decision/gotcha log into `bd remember` is a separate, deliberately deferred task.
- **No GitHub posture applied.** Registered with `--no-posture`; `koryph posture apply`
  (branch protection, secret scanning, signed-commit rulesets) is a live change to
  `github.com/keese-ai/keese` settings and is adopted separately, if at all.
- **No `merge_reconcilers` configured yet.** Add one the first time a generated-artifact
  rebase collision (e.g. `bundle/manifests/*.clusterserviceversion.yaml`,
  `config/crd/bases/*.yaml`) actually happens — not speculatively.

## Common commands

```bash
bd ready                                  # what's dispatchable
/koryph-build <bead-id>                    # dispatch one bead
/koryph-loop                               # dispatch a whole wave
koryph merge <branch>                      # land a finished branch by hand
koryph doctor                              # health check
koryph board                               # cross-project overview
koryph status --project keese               # per-slot detail for the current run
```
