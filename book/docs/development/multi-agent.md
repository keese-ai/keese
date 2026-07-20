<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 keese-ai -->

# Multi-agent worktree workflow

Parallel agent work — dispatch into isolated git worktrees, then merge back to `main` — is
delegated entirely to [koryph](https://koryph.build), an external orchestrator. keese no
longer runs its own dispatch/merge scripts for this.

!!! info "Audience"
    Keese contributors and operators who want to parallelize agent-driven development work.
    **Prerequisites:** `koryph` and `bd` on `PATH`; a working clone of the keese repo,
    registered once via `koryph project add` (see
    [`koryph-orchestration.md`](../../../docs/references/koryph-orchestration.md) for details).

## Why worktrees, still

One human plus several agents editing a single checkout produces overlapping diffs,
conflicting code-generator output, and racing `go.sum` writes. Git worktrees give each agent
an independent filesystem view sharing the parent `.git` directory. koryph owns creating,
tracking, and cleaning up these worktrees — see `worktree_root` in
`~/.koryph/registry.d/keese.json`.

## Work lives in beads, not phase docs

All dispatchable work is a **bead** (`bd`), labeled with `area:*` (from `koryph.project.json`'s
`area_map`) and `fp:*`/`res:*` footprint/resource tokens the scheduler uses to keep parallel
work conflict-free:

```bash
bd ready                  # what's dispatchable right now
bd show <id>               # full description + acceptance criteria
bd update <id> --claim      # claim before starting (or let koryph do it)
bd close <id>               # koryph closes on successful merge; rarely done by hand
```

File new work with `/koryph-issue` (a single bead) or decompose a design doc with
`/koryph-plan`. See [`docs/concepts/beads.md`](https://koryph.build/concepts/beads/)
upstream for the full bead schema.

## Dispatching

**One bead:**

```bash
/koryph-build <bead-id>          # or omit the id to pick from bd ready
```

Shells out to `koryph run --project keese --once --review --only <bead-id>`. Track it with
`koryph status --project keese` and `koryph tail --project keese <bead-id> --follow`.

**A whole wave (many ready beads in parallel):**

```bash
/koryph-loop                     # koryph run --project keese --review [--auto-merge]
```

Joins the shared cross-project governor (`koryph governor show`) so keese's concurrency
respects whatever else is running on the machine. `koryph board` gives a one-line-per-project
overview across every registered project.

## Merging

koryph owns the merge gate. It rebases the branch onto current `main`, refuses to merge any
diff touching a `protected_paths` entry from `koryph.project.json`, runs the `gate` array
(`make gate`), and fast-forwards on success:

```bash
koryph merge <branch>            # land a finished agent branch by hand
koryph land                      # land an engine-opened PR, fast-forward-only
```

Conflicts are never auto-resolved — koryph aborts the rebase and surfaces the conflict for a
human or a follow-up bead, the same "never auto-resolve" rule the old in-repo merge script
enforced.

## Protected paths and containment

The full list is `koryph.project.json`'s `protected_paths` (`CLAUDE.md`, `AGENTS.md`,
`.claude/rules/`, `.claude/agents/`, `.beads/`, `flake.nix`, …). Claude Code additionally
enforces these **pre-execution** via hooks installed at `koryph project add` time
(`${KORYPH_HOME}/hooks/worktree-guard.sh`, `agent-boundary-guard.sh`) — see
[AGENTS.md](../../../AGENTS.md) "Containment model".
Runtimes without hook support fall back to merge-time refusal only.

## Observability

```bash
koryph doctor                    # health check: layout, binaries, registry, governor
koryph board                     # every registered project, one line each
koryph status --project keese     # per-slot detail for the current run
koryph tail --project keese <id> --follow
```

## See also

- [`AGENTS.md`](../../../AGENTS.md) — the full runtime-neutral operating contract
- [`koryph-orchestration.md`](../../../docs/references/koryph-orchestration.md) —
  what this repo owns vs. what koryph owns
- [Repository map](repo-map.md) — where agents find source, tests, and configs
- [SDLC & the design gate](sdlc.md) — how work gates on design + spec scores
- [Testing strategy](testing.md) — what the merge gate actually runs
