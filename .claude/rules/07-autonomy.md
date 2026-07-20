<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 keese-ai -->

# Autonomy for dispatched agents (always loaded)

[koryph](https://koryph.build) dispatches agents into isolated git worktrees it creates
and tears down itself. `.claude/settings.json` allows broad autonomy — `Bash(*)` plus
file tools on the project tree — so a dispatched agent can run the common dev loop
(`make manifests generate`, `make lint`, `make test`, `go build`, codegen, commit)
without prompting for each command. The `deny` list is the universal safety net; the
`ask` list gates the few outward-facing or hard-to-reverse operations. This rule is the
human-readable companion to that matrix and to koryph's merge-time protected-path check.

This rule never overrides [`05-security-zero-trust.md`](05-security-zero-trust.md)
or [`02-security.md`](02-security.md) — on any conflict, those win.

## Blast radius

Dispatched agents work in git worktrees (under koryph's `worktree_root`, see
`~/.koryph/registry.d/keese.json`). A bad-but-non-denied command inside a worktree
damages only that worktree — throw it away and rerun; `main` stays clean. Defense in
depth: Claude Code's hook-supporting runtimes get `${KORYPH_HOME}/hooks/worktree-guard.sh`
and `agent-boundary-guard.sh` (installed at `koryph project add` time, wired via
`.claude/settings.json`) enforcing containment **before** every tool call — see
`AGENTS.md`'s "Containment model". koryph's merge gate refuses any diff that weakens the
sandbox (protected paths, below) regardless of what a runtime without hook support let
through.

## Universal deny list

Enforced by `.claude/settings.json` `deny`; overrides any allow:

- **Root / home / tree nukes**: `rm -rf /`, `rm -rf ~`, `rm -rf *`, `git clean -fdx`.
- **Disk + filesystem destroyers**: `dd if=… of=/dev/…`, `mkfs*`, `fdisk`, `parted`.
- **Power / privilege**: `sudo`, `shutdown`/`reboot`/`halt`/`poweroff`,
  `chmod -R 000|777`, `chown -R …`, `killall -9`, `kill -KILL -1`.
- **Pipe-to-shell RCE**: `curl … | sh|bash`, `wget … | sh|bash`.
- **Force pushes + history rewrite**: `git push --force|-f`,
  `git reset --hard origin|HEAD|main|master`, `git commit --no-verify|-n`,
  `git filter-branch`, `git filter-repo`, `git branch -D main|master`,
  `git update-ref -d`.
- **Image registry publish**: `docker push`.
- **Cluster / infra state**: prod-context `kubectl` (`--context=prod-*`,
  `*production*`, `*prd*`), `helm install`, prod `operator-sdk run bundle`,
  `kind delete clusters`, `fga store delete`, `tofu destroy`,
  `tofu workspace delete`, prod `tofu apply`.
- **Secret reads**: `.env`, `.env.local`, `**/*.key`, `**/*.pem`,
  `**/kubeconfig*`, `dev/bootstrap/**/secrets/**`. Also blocked by the
  `block-secret-read.sh` hook.

## Auto-allowed (no prompt needed)

`.claude/settings.json` `allow` grants `Bash(*)` (subject to deny + ask) and
`Read / Glob / Grep / Edit / Write` on the project tree, plus explicit entries
for the keese toolchain: `make *`, `go`/`gofumpt`/`goimports`/`golangci-lint`,
`operator-sdk`/`controller-gen`/`setup-envtest`/`kustomize`/`kubeconform`,
read-only and `kind-keese*`-scoped `kubectl`/`kind`/`tilt`/`helmfile`, `fga`,
`trivy`/`gosec`/`govulncheck`/`detect-secrets`/`gitleaks`, and `scripts/*`. `bd`
and `koryph` themselves fall under the general `Bash(*)` allow.

## Always ask the user first

These land in `settings.json` `ask`:

- **Network publish / remote state**: `git push`, `gh *` (PRs, issues, releases).
- **Cluster mutation**: `kubectl apply|delete|patch`, `operator-sdk run`,
  `helmfile sync`, `tofu apply`, `make release`.
- **History / worktree movement**: `git rebase`, `git merge`, `git reset`,
  `git checkout main`, `git worktree remove`.
- **Local container ops with side effects**: `docker build`, `docker run`.

## Judgment boundary

When an operation falls outside the allow/ask/deny matrix:

1. **Local, reversible, no network side-effect** → proceed.
2. **Affects shared state or touches the network** → announce + ask.
3. **Destructive and unclear** → refuse; surface the conflict to the user.

## Protected paths (cannot be merged from a worktree)

The authoritative list is `koryph.project.json`'s `protected_paths` array — koryph
refuses to merge any branch whose diff touches it. They control what dispatched agents
are allowed to do; a compromised or confused agent editing them would undermine the
sandbox. **Author on `main` only:**

- `CLAUDE.md`, `AGENTS.md`, `MEMORY.md`, `koryph.project.json`
- `.claude/rules/**`, `.claude/settings.json`, `.claude/settings.local.json`
- `.claude/hooks/**` — secret-read blocker, commit-format validator, SPDX-header
  enforcer.
- `.claude/agents/**`, `.claude/commands/**`, `.claude/skills/**` — agent
  definitions + skills koryph dispatches.
- `scripts/lib/**` — shared shell libraries.
- `.pre-commit-config.yaml` — gates detect-secrets, SPDX header, commitlint,
  controller-gen freshness, kubeconform, rebac markers, bundle-validate.
- `.gitignore` — could exclude secret files from tracking.
- `.github/**`, `CODEOWNERS` — CI workflows + reviewer ownership.
- `.beads/` — the beads database; agents read it via `bd`, never edit it directly.
- `flake.nix`, `flake.lock` — the pinned dev environment (supply chain).

There is no override flag — changes to protected paths happen on `main` directly. If a
dispatched agent believes one of these must change, it should say so in its final report
rather than editing the path; the change lands on `main` in a follow-up.

## Conventional commits still required

The `validate-conventional-commit.sh` hook fires on every `git commit -m`.
Autonomy does not relax commit-message format (see
[`01-conventions.md`](01-conventions.md)); autonomy means you do not have to ask
permission to commit in the first place. Commit per logical unit — commits are the
durable checkpoint; uncommitted work is lost if a run is interrupted.
