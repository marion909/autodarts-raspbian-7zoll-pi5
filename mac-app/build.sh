#!/usr/bin/env bash
# Baut "Autodarts Control.app" (Menüleisten-/Fenster-App zur Verwaltung des Autodarts-Pi).
# Voraussetzung: Xcode oder die Command Line Tools (xcode-select --install).
#
#   ./build.sh                  baut nach ~/Applications
#   OUT_DIR=/pfad ./build.sh    anderes Zielverzeichnis
#   ./build.sh --test           führt zusätzlich die Unit-Tests aus
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

APP_NAME="Autodarts Control"
OUT_DIR="${OUT_DIR:-${HOME}/Applications}"
# Gebaut wird im lokalen Temp-Verzeichnis: Code-Signing scheitert auf externen Laufwerken
BUILD_DIR="${BUILD_DIR:-${TMPDIR:-/tmp}/autodarts-control-build}"

if ! command -v swift >/dev/null 2>&1; then
  echo "swift nicht gefunden. Bitte Xcode oder die Command Line Tools installieren: xcode-select --install" >&2
  exit 1
fi

if [[ "${1:-}" == "--test" ]]; then
  swift test --build-path "${BUILD_DIR}" --disable-index-store
fi

swift build -c release --build-path "${BUILD_DIR}" --disable-index-store
BIN_DIR="$(swift build -c release --build-path "${BUILD_DIR}" --disable-index-store --show-bin-path)"

APP="${OUT_DIR}/${APP_NAME}.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN_DIR}/AutodartsControl" "${APP}/Contents/MacOS/AutodartsControl"
cp Resources/Info.plist "${APP}/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"
fi

xattr -cr "${APP}" 2>/dev/null || true
codesign --force --deep --sign - "${APP}"

echo
echo "Fertig: ${APP}"
echo "Starten: open \"${APP}\""
