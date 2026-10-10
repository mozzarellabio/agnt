#!/bin/sh
set -eu

REPO="mozzarellabio/agnt"
BASE="${AGNT_BASE_URL:-https://github.com/$REPO/releases}"
API="${AGNT_API_URL:-https://api.github.com/repos/$REPO/releases/latest}"
VERSION="${AGNT_VERSION:-}"
DIR="${AGNT_INSTALL_DIR:-}"
MODIFY_PATH=1
UNINSTALL=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  ACC="$(printf '\033[38;2;217;119;87m')"
  SEC="$(printf '\033[38;2;240;176;137m')"
  DIM="$(printf '\033[38;2;124;118;108m')"
  OK="$(printf '\033[38;2;139;196;138m')"
  ERR="$(printf '\033[38;2;229;104;95m')"
  B="$(printf '\033[1m')"
  R="$(printf '\033[0m')"
else
  ACC="" SEC="" DIM="" OK="" ERR="" B="" R=""
fi

step() { printf '  %s›%s %s\n' "$ACC" "$R" "$*"; }
ok() { printf '  %s✓%s %s\n' "$OK" "$R" "$*"; }
note() { printf '    %s%s%s\n' "$DIM" "$*" "$R"; }
fail() {
  printf '  %s✗%s %s\n' "$ERR" "$R" "$*" >&2
  exit 1
}

banner() {
  printf '\n%s' "$ACC"
  cat <<'EOF'
     __ _  __ _ _ __ | |_
    / _` |/ _` | '_ \| __|
   | (_| | (_| | | | | |_
    \__,_|\__, |_| |_|\__|
          |___/
EOF
  printf '%s  %sagent orchestras in your terminal%s\n\n' "$R" "$DIM" "$R"
}

usage() {
  cat <<EOF
agnt installer

  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh
  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh -s -- [options]

  -v, --version <x.y.z>   install a specific release (default: latest)
  -d, --dir <path>        install directory (default: ~/.local/bin, /usr/local/bin as root)
      --no-modify-path    do not touch shell startup files
      --uninstall         remove the binary (config in ~/.config/agnt is kept)
  -h, --help              show this help

env: AGNT_VERSION, AGNT_INSTALL_DIR, AGNT_BASE_URL, NO_COLOR
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -v | --version)
      [ $# -ge 2 ] || fail "$1 needs a value"
      VERSION="$2"
      shift 2
      ;;
    -d | --dir)
      [ $# -ge 2 ] || fail "$1 needs a value"
      DIR="$2"
      shift 2
      ;;
    --no-modify-path)
      MODIFY_PATH=0
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) fail "unknown option: $1 (try --help)" ;;
  esac
done

if [ -z "$DIR" ]; then
  if [ "$(id -u)" -eq 0 ]; then DIR="/usr/local/bin"; else DIR="$HOME/.local/bin"; fi
fi
DEST="$DIR/agnt"

pretty() {
  case "$1" in
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

installed_version() {
  [ -x "$1" ] || return 0
  "$1" --version 2>/dev/null | awk '{print $2; exit}' || true
}

fetch() {
  if command -v curl >/dev/null 2>&1; then
    if [ -t 2 ]; then curl -fL# "$1" -o "$2"; else curl -fsSL "$1" -o "$2"; fi
  elif command -v wget >/dev/null 2>&1; then
    if [ -t 2 ]; then wget -q --show-progress -O "$2" "$1"; else wget -q -O "$2" "$1"; fi
  else
    fail "need curl or wget"
  fi
}

latest_tag() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -m 8 "$API" 2>/dev/null || true
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 8 -O - "$API" 2>/dev/null || true
  fi | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1
}

shell_rc() {
  case "$(basename "${SHELL:-sh}")" in
    zsh) printf '%s' "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      if [ -f "$HOME/.bashrc" ] || [ ! -f "$HOME/.bash_profile" ]; then printf '%s' "$HOME/.bashrc"; else printf '%s' "$HOME/.bash_profile"; fi
      ;;
    fish) printf '%s' "$HOME/.config/fish/config.fish" ;;
    *) printf '%s' "$HOME/.profile" ;;
  esac
}

add_to_path() {
  rc="$(shell_rc)"
  if [ -f "$rc" ] && grep -qF "$DIR" "$rc" 2>/dev/null; then
    note "$(pretty "$DIR") already referenced in $(pretty "$rc")"
    return 0
  fi
  mkdir -p "$(dirname "$rc")"
  case "$rc" in
    *config.fish) printf '\nfish_add_path "%s"\n' "$DIR" >>"$rc" ;;
    *) printf '\nexport PATH="%s:$PATH"\n' "$DIR" >>"$rc" ;;
  esac
  ok "added $(pretty "$DIR") to PATH in $(pretty "$rc")"
}

banner

if [ "$UNINSTALL" -eq 1 ]; then
  [ -e "$DEST" ] || fail "nothing to remove at $(pretty "$DEST")"
  rm -f "$DEST"
  ok "removed $(pretty "$DEST")"
  note "keys and settings in ~/.config/agnt were left in place"
  exit 0
fi

os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Linux) ;;
  Darwin) fail "macOS builds are not published yet" ;;
  *) fail "unsupported OS: $os (Windows: irm https://raw.githubusercontent.com/$REPO/main/install.ps1 | iex)" ;;
esac
case "$arch" in
  x86_64 | amd64) ;;
  *) fail "unsupported architecture: $arch (only x86_64 builds are published)" ;;
esac
ok "detected ${B}linux x86_64${R}"

VERSION="${VERSION#v}"
if [ -n "$VERSION" ]; then
  URLS="$BASE/download/$VERSION/agnt-linux $BASE/download/v$VERSION/agnt-linux"
  TARGET="$VERSION"
else
  URLS="$BASE/latest/download/agnt-linux"
  TARGET="$(latest_tag)"
  TARGET="${TARGET#v}"
fi

CURRENT="$(installed_version "$DEST")"
if [ -n "$CURRENT" ] && [ -n "$TARGET" ] && [ "$CURRENT" = "$TARGET" ]; then
  ok "agnt ${B}$CURRENT${R} is already installed and up to date"
  exit 0
fi

if [ -n "$CURRENT" ]; then
  step "updating ${B}$CURRENT${R} → ${B}${TARGET:-latest}${R}"
else
  step "installing ${B}agnt ${TARGET:-latest}${R}"
fi

mkdir -p "$DIR" 2>/dev/null || fail "cannot create $(pretty "$DIR") (try --dir or sudo)"
[ -w "$DIR" ] || fail "$(pretty "$DIR") is not writable (try --dir or sudo)"

TMP="$(mktemp "$DIR/.agnt.XXXXXX")"
trap 'rm -f "$TMP"' EXIT INT TERM

step "downloading"
got=0
for URL in $URLS; do
  if fetch "$URL" "$TMP"; then got=1; break; fi
done
[ "$got" -eq 1 ] || fail "download failed: ${VERSION:+version $VERSION not found, }check $BASE"
chmod 755 "$TMP"

GOT="$("$TMP" --version 2>/dev/null | awk '{print $2; exit}' || true)"
[ -n "$GOT" ] || fail "downloaded file does not run on this system"

mv -f "$TMP" "$DEST"
trap - EXIT INT TERM
ok "installed ${B}agnt $GOT${R} to $(pretty "$DEST")"

case ":$PATH:" in
  *":$DIR:"*) ;;
  *)
    if [ "$MODIFY_PATH" -eq 1 ]; then
      add_to_path
      note "restart your shell, or run: export PATH=\"$DIR:\$PATH\""
    else
      note "$(pretty "$DIR") is not on your PATH"
    fi
    ;;
esac

printf '\n'
printf '  %sRun it%s       %sagnt%s\n' "$DIM" "$R" "$SEC" "$R"
printf '  %sUpdate%s       %sagnt update%s\n' "$DIM" "$R" "$SEC" "$R"
printf '  %sAdd a key%s    %s/key anthropic <key>%s %sinside agnt, or skip it: free models work out of the box%s\n' "$DIM" "$R" "$SEC" "$R" "$DIM" "$R"
printf '\n  %sKeys and settings live in ~/.config/agnt and are never touched by the installer.%s\n\n' "$DIM" "$R"
