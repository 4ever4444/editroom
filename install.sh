#!/bin/bash
# The one line a Mac user pastes in Terminal (stage 13.3, D8): curl -fsSL <address>/install.sh | bash
# Same as install.ps1: ~/EditRoom, uv (checked), the system's code, then install/setup.py's page in the browser.
# A Mac = Apple Silicon, macOS 14 or newer (onnxruntime and PyMuPDF have no Intel Mac wheels). NOT TESTED: no Mac (R7).
set -euo pipefail
ROOT="${EDITROOM_ROOT:-$HOME/EditRoom}"
RELEASE="https://raw.githubusercontent.com/4ever4444/editroom/main"   # D9: the public repo of releases only
UV_URL="https://github.com/astral-sh/uv/releases/download/0.13.9/uv-aarch64-apple-darwin.tar.gz"
UV_SHA="5aeca67f2283f75235de40d0bd9c0a5bbc5fce23b6d48b3bf9fa1b2db08382ca"

checked() {   # url sha dest
  if [ -f "$3" ] && [ "$(shasum -a 256 "$3" | cut -d' ' -f1)" = "$2" ]; then return; fi
  curl -fsSL "$1" -o "$3.part"
  if [ "$(shasum -a 256 "$3.part" | cut -d' ' -f1)" != "$2" ]; then rm -f "$3.part"; echo "SHA-256 mismatch: $1"; exit 1; fi
  mv "$3.part" "$3"
}

[ "$(uname -m)" = "arm64" ] || { echo "This Mac needs an Apple chip (M1 or newer)."; exit 1; }
case "$ROOT" in *[!A-Za-z0-9/_.-]*) echo "The install folder must be an English name with no spaces: $ROOT"; exit 1;; esac
CACHE="$ROOT/runtime/.cache"; mkdir -p "$CACHE" "$ROOT/runtime/uv" "$ROOT/runtime/tmp"
checked "$UV_URL" "$UV_SHA" "$CACHE/uv.tar.gz"
tar -xzf "$CACHE/uv.tar.gz" -C "$ROOT/runtime/uv" --strip-components 1

APP="$ROOT/app"
if [ ! -f "$APP/install/setup.py" ]; then
  V=""
  if [ -n "${EDITROOM_SOURCE:-}" ]; then cp "$EDITROOM_SOURCE" "$CACHE/editroom.zip"
  else
    V="$(curl -fsSL "$RELEASE/version.json")"
    FILE="$(printf '%s' "$V" | sed -n 's/.*"file": *"\([^"]*\)".*/\1/p')"; SHA="$(printf '%s' "$V" | sed -n 's/.*"sha256": *"\([^"]*\)".*/\1/p')"
    checked "$RELEASE/$FILE" "$SHA" "$CACHE/editroom.zip"
  fi
  rm -rf "$APP.new"; mkdir -p "$APP.new"; unzip -q "$CACHE/editroom.zip" -d "$APP.new"
  if [ -n "$V" ]; then printf '%s' "$V" > "$APP.new/version.json"; fi   # which version this is (updates)
  mv "$APP.new" "$APP"
fi

export UV_PYTHON_INSTALL_DIR="$ROOT/runtime/python" UV_CACHE_DIR="$CACHE/uv" TMPDIR="$ROOT/runtime/tmp"
"$ROOT/runtime/uv/uv" run --no-project --python 3.12 "$APP/install/setup.py" --root "$ROOT" --app "$APP" --ui
