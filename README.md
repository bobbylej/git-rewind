# git-rewind

Jump back to a recently used git branch with an interactive menu built from your reflog.

## Requirements

- Bash 3.2+
- Git

No third-party packages are required.

## Setup

Run the script directly from a git repository:

```bash
./git-rewind
```

To install for bash and zsh (binary, completions, and shell config):

```bash
./install.sh
```

This installs to `~/.local/bin` and adds PATH + completion snippets to `~/.bashrc` and `~/.zshrc`.

Then reload your shell:

```bash
source ~/.bashrc   # bash
source ~/.zshrc    # zsh
```

To remove the install:

```bash
./install.sh --uninstall
```

### Manual install

1. Copy the script:

```bash
mkdir -p ~/bin
cp git-rewind ~/bin/git-rewind
chmod +x ~/bin/git-rewind
```

2. Make sure `~/bin` is on your `PATH` (add to `~/.bashrc` or `~/.zshrc` if needed):

```bash
export PATH="$HOME/bin:$PATH"
```

### Bash

Add this to your `~/.bashrc`:

```bash
git-rewind() {
  "$HOME/bin/git-rewind" "$@"
}
```

Then reload your shell:

```bash
source ~/.bashrc
```

### Zsh

Add this to your `~/.zshrc`:

```bash
git-rewind() {
  "$HOME/bin/git-rewind" "$@"
}
```

Then reload your shell:

```bash
source ~/.zshrc
```

## Usage

Run inside a git repository:

```bash
git-rewind
git-rewind --time "4 hours"
git-rewind --time 1 week
git-rewind --config timeframe "3 days"
git-rewind --config --global timeframe "1 week"
```

Recommended setup — persist a default lookback window in git config:

```bash
git-rewind --config --global timeframe "3 days"
git-rewind
```

Or override from your shell:

```bash
export GIT_REWIND_DEFAULT_TIMEFRAME="3 days"
git-rewind
```

## Options

| Option                  | Description                                                                  |
| ----------------------- | ---------------------------------------------------------------------------- |
| `--time DURATION`       | Look back this far for this run only (`4 hours`, `1 day`, `2w`, `30m`, etc.) |
| `--config NAME [VALUE]` | Read or write a default stored as `git config git-rewind.*`                  |
| `--global`              | With `--config`, write to `~/.gitconfig` instead of the local repo           |
| `--system`              | With `--config`, write to system-wide git config                             |
| `--unset`               | With `--config`, remove the stored default                                   |

### Configurable parameters

| Parameter   | Description                                           |
| ----------- | ----------------------------------------------------- |
| `timeframe` | Default lookback duration (built-in default: `1 day`) |

Default precedence: `--time` > `GIT_REWIND_DEFAULT_TIMEFRAME` > git config > built-in default.

## How it works

1. Reads `git reflog` entries for branch checkouts and switches.
2. Builds sessions between consecutive checkouts (current branch runs until the next checkout or now).
3. Lists branches with activity in the lookback window, sorted by most recent session end.
4. Shows an interactive menu — use ↑/↓ to navigate, Enter to checkout, Esc to cancel.

The current branch is marked with a green dot (●).

## Example output

```
Recent branches  (3)

● main
  feature/my-branch
  fix/quick-bug

↑/↓ navigate  Enter select  Esc cancel
```

After selecting a branch:

```
Switching to 'feature/my-branch'...
Switched to branch 'feature/my-branch'
```

## Notes

- Branch history comes from checkouts in the reflog, not commits or file edits.
- Branches that no longer exist locally are skipped.
- If you stayed on a branch before the lookback window but never switched away, it still counts as recent.
- Reflog entries can expire; older history may be missing depending on git configuration.
- Interactive mode requires a terminal (TTY).

## For developers

The project is a single Bash script plus shell completions and an installer. No build step, no runtime dependencies beyond Git.

### Project layout

```
git-rewind              Main script (reflog parsing, TUI, checkout)
install.sh              Installs to ~/.local/bin and patches ~/.bashrc / ~/.zshrc
completions/
  git-rewind.bash       Bash tab completion
  _git-rewind           Zsh completion function
```

### Reflog → sessions → recent branches

`collect_recent_branches` is the core data pipeline:

1. **Parse checkouts** — scan `git reflog --date=unix HEAD` and match both `checkout:` and `switch:` lines with regex (Git changed the message format over time).
2. **Rebuild sessions** — reflog is newest-first. Walk consecutive entries: each checkout timestamp closes the previous branch's session. The oldest entry's branch gets a session ending at `now`.
3. **Filter by window** — keep sessions whose end time is ≥ the cutoff. A branch checked out before the window but never left still appears, because its session ends at `now`.
4. **Deduplicate** — one row per branch, keeping the latest session end.
5. **Sort** — zero-padded unix timestamps + `sort -rn` so the most recently active branch is first.

### Interactive TUI in pure Bash

There is no `fzf`, `dialog`, or curses library. The menu is hand-rolled:

- **Alternate screen** — `\033[?1049h` / `\033[?1049l` swaps to a clean buffer and restores the terminal on exit.
- **Incremental redraw** — after the first full clear, `\033[{n}A` moves the cursor up and `\033[K` clears each line instead of repainting the whole screen.
- **Raw mode** — `stty -echo -icanon` reads keys one byte at a time; saved/restored with `trap` on `EXIT`.
- **Arrow keys** — `\x1b[A` / `\x1b[B` (and `\x1bOA` / `\x1bOB` for some terminals).

### Bash 3.2 compatibility

macOS still ships Bash 3.2 as `/bin/bash`. The script avoids Bash 4+ features in the hot path and branches in `read_esc_continuation`:

- Bash 4+: `read -rsn1 -t 0.02` reads escape sequences with a short timeout.
- Bash 3.2: brief `sleep`, switch to non-blocking `stty`, then drain remaining bytes — `read -t` is unreliable for single-character reads on older Bash.

This is why the shebang targets plain Bash and why testing on macOS default shell matters.

### TTY handling

Interactive I/O prefers `/dev/tty` over stdin/stdout. That keeps the menu working when the script is invoked from a shell function or wrapper that might redirect streams — alt-screen, key reads, and cleanup all use the same device.

### Config layering

Defaults follow a clear precedence chain, similar to Git itself:

```
--time  →  GIT_REWIND_DEFAULT_TIMEFRAME  →  git config git-rewind.*  →  built-in default
```

`--config` is a thin wrapper around `git config`, with validation (e.g. `timeframe` values must parse as a duration before being written).

### Installer design

`install.sh` uses marked blocks in rc files (`# git-rewind (git-branch-switch)` … `# /git-rewind`) so install is idempotent and `--uninstall` can remove only its own snippets without touching unrelated config. Completions are copied to `~/.local/share/git-rewind/completions/`; the binary is symlinked from the repo so local edits are picked up immediately during development.
