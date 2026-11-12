#!/usr/bin/env bash
# Verbindet beim Login den mit autodarts-bt-speaker gespeicherten Bluetooth-Lautsprecher.
# Ist der Lautsprecher noch aus, wird einige Minuten lang im Hintergrund erneut versucht.
set -euo pipefail

CONFIG_FILE="/etc/default/autodarts-bt"
BT_SPEAKER_MAC=""

if [[ -r "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

if [[ -z "${BT_SPEAKER_MAC}" ]] || ! command -v bluetoothctl >/dev/null 2>&1; then
  exit 0
fi

bluetoothctl power on >/dev/null 2>&1 || true

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if bluetoothctl info "${BT_SPEAKER_MAC}" 2>/dev/null | grep -q 'Connected: yes'; then
    exit 0
  fi
  timeout 15 bluetoothctl connect "${BT_SPEAKER_MAC}" >/dev/null 2>&1 || true
  sleep 3
done

exit 0
