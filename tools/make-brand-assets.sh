#!/usr/bin/env bash
# Erzeugt Bootscreen, Wallpaper, App-Icon und Menüleisten-Symbol aus den Autodarts-SVGs in assets/brand/.
# Nur auf dem Mac nötig (Swift/AppKit + iconutil), wenn sich das Logo ändert.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

swiftc -O -o "${WORK_DIR}/make-brand-assets" tools/make-brand-assets.swift
"${WORK_DIR}/make-brand-assets" assets/brand . "${WORK_DIR}/AppIcon.iconset"
iconutil -c icns "${WORK_DIR}/AppIcon.iconset" -o mac-app/Resources/AppIcon.icns
echo "geschrieben: mac-app/Resources/AppIcon.icns"
