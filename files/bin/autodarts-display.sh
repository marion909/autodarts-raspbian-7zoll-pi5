#!/usr/bin/env bash
# Setzt Rotation/Skalierung des DSI-Displays und spiegelt es optional auf HDMI.
# Konfiguration: /etc/default/autodarts-display (wird vom Setup geschrieben).
set -euo pipefail

CONFIG_FILE="/etc/default/autodarts-display"

ROTATION_XRANDR="normal"
DSI_MODE="800x480"
DSI_SCALE="1.2x1.2"
MIRROR_HDMI="1"

if [[ -r "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

DSI_OUTPUT=""
HDMI_OUTPUT=""
MAIN_OUTPUT=""

detect_outputs() {
  local outputs
  outputs="$(xrandr --query 2>/dev/null)" || return 1

  DSI_OUTPUT="$(awk '/^DSI-[A-Za-z0-9-]+ connected/ {print $1; exit}' <<<"${outputs}")"
  HDMI_OUTPUT="$(awk '/^HDMI-[A-Za-z0-9-]+ connected/ {print $1; exit}' <<<"${outputs}")"

  MAIN_OUTPUT="${DSI_OUTPUT}"
  if [[ -z "${MAIN_OUTPUT}" ]]; then
    MAIN_OUTPUT="$(awk '/ connected primary / {print $1; exit}' <<<"${outputs}")"
  fi
  if [[ -z "${MAIN_OUTPUT}" ]]; then
    MAIN_OUTPUT="$(awk '/ connected/ {print $1; exit}' <<<"${outputs}")"
  fi

  [[ -n "${MAIN_OUTPUT}" ]]
}

# Auf X-Server und angeschlossenes Display warten (max. ~10 s)
found=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if detect_outputs; then
    found=1
    break
  fi
  sleep 1
done

if [[ "${found}" -ne 1 ]]; then
  echo "Kein angeschlossenes Display gefunden, nichts zu tun." >&2
  exit 0
fi

# Rotation (+ bei DSI: feste Aufloesung und Skalierung)
args=(--output "${MAIN_OUTPUT}" --rotate "${ROTATION_XRANDR}")
if [[ -n "${DSI_OUTPUT}" ]]; then
  args+=(--mode "${DSI_MODE}" --scale "${DSI_SCALE}" --primary)
fi

if ! xrandr "${args[@]}" >/dev/null 2>&1; then
  # Fallback: nur Rotation, falls Mode/Scale vom Display nicht unterstuetzt werden
  xrandr --output "${MAIN_OUTPUT}" --rotate "${ROTATION_XRANDR}" >/dev/null 2>&1 || true
fi

# HDMI spiegeln: kurz auf spaet erkanntes HDMI warten (max. 3 s)
if [[ "${MIRROR_HDMI}" == "1" && -n "${DSI_OUTPUT}" ]]; then
  for _ in 1 2 3; do
    if [[ -n "${HDMI_OUTPUT}" ]]; then
      break
    fi
    sleep 1
    detect_outputs || true
  done

  if [[ -n "${HDMI_OUTPUT}" ]]; then
    xrandr --output "${HDMI_OUTPUT}" --same-as "${DSI_OUTPUT}" --auto >/dev/null 2>&1 || true
  fi
fi

exit 0
