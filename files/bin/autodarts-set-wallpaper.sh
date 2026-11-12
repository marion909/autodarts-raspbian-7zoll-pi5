#!/usr/bin/env bash
# Setzt beim Login das Autodarts-Wallpaper (pcmanfm braucht manchmal einige Versuche).
set -euo pipefail

WALLPAPER="/usr/local/share/autodarts/wallpaper.jpg"

if [[ ! -f "${WALLPAPER}" ]] || ! command -v pcmanfm >/dev/null 2>&1; then
  exit 0
fi

for _ in 1 2 3 4 5; do
  pcmanfm --set-wallpaper "${WALLPAPER}" --wallpaper-mode=stretch >/dev/null 2>&1 || true
  sleep 1
done
