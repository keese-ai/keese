# Claude Code account setup for contributors

This repo is wired so that Claude Code (CLI and the VS Code extension) uses a
**specific Claude account** for this project, even if you also use a different
Claude account elsewhere. The mechanism is committed to the repo, so every
contributor gets the same behavior — you only do a small one-time personal setup.

## What's committed (don't change per-machine)

A `.envrc` file at the repo root selects the account by pointing
`CLAUDE_CONFIG_DIR` at a per-account Claude Code config directory. For a **work**
project it contains:

```bash
# Claude Code account selection — committed; shared by all contributors.
# This project uses the WORK Claude account.
# If you keep work on a separate Claude Code config dir, this points Claude at it.
# Convention: ~/.claude-work. Override with CLAUDE_WORK_CONFIG_DIR or .envrc.local.
# If you only have one account, the dir won't exist and this is a no-op.
_claude_dir="${CLAUDE_WORK_CONFIG_DIR:-$HOME/.claude-work}"
[ -d "$_claude_dir" ] && export CLAUDE_CONFIG_DIR="$_claude_dir"
unset _claude_dir
source_env_if_exists ./.envrc.local
```

A **personal** project uses the same block with the personal defaults
(`CLAUDE_PERSONAL_CONFIG_DIR`, default `~/.claude`).

`.gitignore` includes `.envrc.local` so your personal overrides are never committed.

## One-time per-developer setup

You need this only if you use **two Claude accounts** (e.g. a work Team account
and a personal account) and want this project pinned to one of them. If you only
have one account, do nothing — the committed `.envrc` is a no-op for you.

1. **Install direnv** and hook it into your shell (one-time, machine-wide):
   ```bash
   brew install direnv               # or your package manager
   echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc   # bash: direnv hook bash
   exec $SHELL
   ```

2. **Create a separate config dir for the work account and log in:**
   ```bash
   mkdir -p ~/.claude-work
   CLAUDE_CONFIG_DIR=~/.claude-work claude   # then: /login  -> your WORK account
   ```
   Your other (personal) account stays on the default `~/.claude`. The two config
   dirs keep credentials, MCP servers, memory, and session history fully separate.

3. **Authorize direnv in the repo** (once per repo, after each `.envrc` change):
   ```bash
   cd <this repo> && direnv allow
   ```

4. **Verify:**
   ```bash
   echo "$CLAUDE_CONFIG_DIR"   # -> /Users/you/.claude-work
   claude auth status          # -> your work account
   ```

### If your config dir isn't at `~/.claude-work`

Either export an override in your shell profile:

```bash
export CLAUDE_WORK_CONFIG_DIR="$HOME/somewhere/else"
```

…or create a gitignored `.envrc.local` in the repo:

```bash
export CLAUDE_CONFIG_DIR="$HOME/somewhere/else"
```

## Notes

- The committed `.envrc` is safe for everyone: contributors without a second
  config dir simply fall back to their normal account (the guard skips a dir that
  doesn't exist).
- macOS stores login credentials in the Keychain. After logging into the second
  account, confirm both can be logged in at once: in a separate terminal outside
  this repo, run `claude auth status` and check it still shows your *other*
  account. If logging into one flips the other, log the work account in with a
  token instead (`CLAUDE_CONFIG_DIR=~/.claude-work claude setup-token`) so the two
  credential stores stay separate.
- Switching this project to a different account later is a one-line change to the
  committed `.envrc` (work ↔ personal defaults), or a personal `.envrc.local`.
