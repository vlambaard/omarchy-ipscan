#!/usr/bin/env bash
# Installs omarchy-ipscan for the current user. No root, nothing outside $HOME.
set -euo pipefail

SRC_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
APP_DIR=${APP_DIR:-$HOME/.local/share/applications}
NAME=omarchy-ipscan

B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[0m'
ok()   { printf '  %s✓%s %s\n' "$G" "$R" "$*"; }
note() { printf '  %s·%s %s\n' "$D" "$R" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$R" "$*"; }

printf '\n%s%s installer%s\n\n' "$B" "$NAME" "$R"

mkdir -p "$BIN_DIR" "$APP_DIR"

ln -sfn "$SRC_DIR/$NAME" "$BIN_DIR/$NAME"
ok "linked $BIN_DIR/$NAME -> $SRC_DIR/$NAME"

# The .desktop file must point at an absolute path, so it is generated from the
# template with the real install location substituted in.
if [[ -f $SRC_DIR/$NAME.desktop ]]; then
  sed "s|@BIN@|$BIN_DIR/$NAME|g" "$SRC_DIR/$NAME.desktop" >"$APP_DIR/$NAME.desktop"
  ok "installed $APP_DIR/$NAME.desktop"
  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$APP_DIR" >/dev/null 2>&1 \
    && note "refreshed desktop database"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ok "$BIN_DIR is on your PATH" ;;
  *) warn "$BIN_DIR is not on your PATH - add this to your shell rc:"
     # shellcheck disable=SC2016  # $PATH must stay literal in the printed advice
     printf '      export PATH="%s:$PATH"\n' "$BIN_DIR" ;;
esac

printf '\n%sdependencies%s\n' "$B" "$R"
missing=0
for dep in bash nmap gum fzf; do
  if command -v "$dep" >/dev/null 2>&1; then ok "$dep"
  else warn "$dep (required)"; missing=1; fi
done
for dep in arp-scan fping wl-clipboard:wl-copy jq xdg-utils:xdg-open; do
  bin=${dep##*:}; pkg=${dep%%:*}
  if command -v "$bin" >/dev/null 2>&1; then ok "$bin"
  else note "$pkg (optional - degrades gracefully)"; fi
done

if ((missing)); then
  printf '\n  install the required packages with:\n'
  printf '    sudo pacman -S nmap gum fzf\n'
fi

printf '\n%sdone%s - run %s%s%s\n\n' "$B" "$R" "$B" "$NAME" "$R"
