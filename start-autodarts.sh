#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER:-pi}}"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

if [[ -z "${TARGET_HOME}" ]]; then
  echo "Konnte Home-Verzeichnis von ${TARGET_USER} nicht ermitteln."
  exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${TARGET_HOME}/.Xauthority}"

if ! command -v autodarts-desktop >/dev/null 2>&1; then
  echo "autodarts-desktop nicht gefunden."
  exit 1
fi

if [[ ! -S /tmp/.X11-unix/X0 ]]; then
  echo "Kein laufender X-Server auf :0 gefunden. Bitte zuerst in den Desktop einloggen."
  exit 1
fi

if [[ "$(id -un)" != "${TARGET_USER}" ]]; then
  exec sudo -u "${TARGET_USER}" -E autodarts-desktop
fi

exec autodarts-desktop
