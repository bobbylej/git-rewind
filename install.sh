#!/usr/bin/env bash
#
# Install or uninstall git-rewind for bash and zsh.
#
# Usage:
#   ./install.sh              # install to ~/.local/bin
#   ./install.sh --uninstall  # remove install and shell snippets
#   ./install.sh --dry-run    # show what would change
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BIN="${INSTALL_BIN:-$HOME/.local/bin}"
INSTALL_SHARE="${INSTALL_SHARE:-$HOME/.local/share/git-rewind}"
MARKER_BEGIN="# git-rewind (git-branch-switch)"
MARKER_END="# /git-rewind"

DRY_RUN=false
UNINSTALL=false

usage() {
  cat <<EOF
Usage: ./install.sh [OPTIONS]

Install git-rewind for bash and zsh (one command, both shells).

Options:
  --uninstall   Remove binary, completions, and shell config snippets
  --dry-run     Print actions without changing anything
  -h, --help    Show this help

Environment:
  INSTALL_BIN     Destination for the git-rewind executable (default: ~/.local/bin)
  INSTALL_SHARE   Destination for completions (default: ~/.local/share/git-rewind)

After install, open a new terminal or run:
  source ~/.bashrc    # bash
  source ~/.zshrc     # zsh
EOF
}

log() {
  printf 'install: %s\n' "$*"
}

run() {
  if $DRY_RUN; then
    printf '  [dry-run] '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

ensure_block_in_file() {
  local file="$1"
  shift
  local -a lines=("$@")

  if [[ ! -f "$file" ]]; then
    run touch "$file"
  fi

  if grep -qF "$MARKER_BEGIN" "$file" 2>/dev/null; then
    log "already configured in ${file}"
    return 0
  fi

  log "updating ${file}"
  if $DRY_RUN; then
    printf '  [dry-run] append to %s:\n' "$file"
    printf '    %s\n' "$MARKER_BEGIN"
    local line
    for line in "${lines[@]}"; do
      printf '    %s\n' "$line"
    done
    printf '    %s\n' "$MARKER_END"
  else
    {
      printf '\n%s\n' "$MARKER_BEGIN"
      local line
      for line in "${lines[@]}"; do
        printf '%s\n' "$line"
      done
      printf '%s\n' "$MARKER_END"
    } >>"$file"
  fi
}

remove_marker_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  if ! grep -qF "$MARKER_BEGIN" "$file" 2>/dev/null; then
    return 0
  fi

  log "removing config from ${file}"
  if $DRY_RUN; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    $0 == begin { skip = 1; next }
    skip && $0 == end { skip = 0; next }
    skip { next }
    { print }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

shell_snippet_lines() {
  cat <<EOF
export PATH="${INSTALL_BIN}:\$PATH"
if [[ -n "\${BASH_VERSION:-}" ]]; then
  [[ -f "${INSTALL_SHARE}/completions/git-rewind.bash" ]] && source "${INSTALL_SHARE}/completions/git-rewind.bash"
fi
if [[ -n "\${ZSH_VERSION:-}" ]]; then
  fpath=("${INSTALL_SHARE}/completions" \$fpath)
  autoload -Uz _git-rewind 2>/dev/null
fi
EOF
}

install() {
  log "installing git-rewind to ${INSTALL_BIN}"
  run mkdir -p "$INSTALL_BIN" "${INSTALL_SHARE}/completions"
  run ln -sf "${REPO_DIR}/git-rewind" "${INSTALL_BIN}/git-rewind"
  run cp "${REPO_DIR}/completions/git-rewind.bash" "${INSTALL_SHARE}/completions/git-rewind.bash"
  run cp "${REPO_DIR}/completions/_git-rewind" "${INSTALL_SHARE}/completions/_git-rewind"
  run chmod +x "${INSTALL_BIN}/git-rewind"

  local -a lines=()
  while IFS= read -r line; do
    lines+=("$line")
  done < <(shell_snippet_lines)

  ensure_block_in_file "$HOME/.bashrc" "${lines[@]}"
  ensure_block_in_file "$HOME/.zshrc" "${lines[@]}"

  log "done"
  cat <<EOF

git-rewind is installed for bash and zsh.

  ${INSTALL_BIN}/git-rewind --help
  git-rewind --time "4 hours"

Open a new terminal, or reload your shell:
  source ~/.bashrc   # bash
  source ~/.zshrc    # zsh
EOF
}

uninstall() {
  log "uninstalling git-rewind"
  run rm -f "${INSTALL_BIN}/git-rewind"
  run rm -rf "${INSTALL_SHARE}"

  remove_marker_block "$HOME/.bashrc"
  remove_marker_block "$HOME/.zshrc"

  log "done"
  cat <<EOF

git-rewind has been removed. Open a new terminal or reload your shell config.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) UNINSTALL=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if $UNINSTALL; then
  uninstall
else
  install
fi
