#!/usr/bin/env bash
# Startet AutoDarts Desktop und Chromium im Kiosk-Modus (mit automatischem Neustart).
set -euo pipefail

URL="https://play.autodarts.com/"
OFFLINE_PAGE="/usr/local/share/autodarts/offline.html"
NETWORK_WAIT_SECONDS=30
KIOSK_PROFILE="${HOME}/.config/autodarts-kiosk"

xset s off || true
xset -dpms || true
xset s noblank || true
unclutter -idle 0.5 -root &

# Rotation, Skalierung und HDMI-Spiegelung (synchron, vor dem Browserstart)
if [[ -x /usr/local/bin/autodarts-display.sh ]]; then
  /usr/local/bin/autodarts-display.sh || true
fi

CHROMIUM_BIN="$(command -v chromium || command -v chromium-browser || true)"
if [[ -z "${CHROMIUM_BIN}" ]]; then
  echo "Chromium wurde nicht gefunden." >&2
  exit 1
fi

# Wartet bis zu NETWORK_WAIT_SECONDS auf play.autodarts.com.
# Gibt die Start-URL aus: die echte Seite, sonst die lokale Offline-Seite,
# die selbststaendig alle paar Sekunden erneut versucht.
pick_start_url() {
  local deadline=$((SECONDS + NETWORK_WAIT_SECONDS))
  until curl -sI -o /dev/null --connect-timeout 3 --max-time 5 "${URL}"; do
    if ((SECONDS >= deadline)); then
      if [[ -f "${OFFLINE_PAGE}" ]]; then
        echo "file://${OFFLINE_PAGE}"
      else
        echo "${URL}"
      fi
      return 0
    fi
    sleep 2
  done
  echo "${URL}"
}

fix_profile_state() {
  local pref_file="${KIOSK_PROFILE}/Default/Preferences"
  mkdir -p "${KIOSK_PROFILE}/Default"
  if [[ -f "${pref_file}" ]]; then
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/g' "${pref_file}" || true
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/g' "${pref_file}" || true
  fi
}

start_url="$(pick_start_url)"

if command -v autodarts-desktop >/dev/null 2>&1; then
  autodarts-desktop &
  sleep 5
fi

# Chromium bei Absturz/Beenden automatisch neu starten
while true; do
  fix_profile_state
  started_at=$SECONDS

  "${CHROMIUM_BIN}" \
    --ozone-platform=x11 \
    --start-fullscreen \
    --enable-virtual-keyboard \
    --enable-features=VirtualKeyboard \
    --force-renderer-accessibility \
    --touch-events=enabled \
    --force-device-scale-factor=0.85 \
    --password-store=basic \
    --user-data-dir="${KIOSK_PROFILE}" \
    --profile-directory=Default \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --no-first-run \
    --no-default-browser-check \
    --autoplay-policy=no-user-gesture-required \
    "${start_url}" || true

  # Crash-Schleife abbremsen, wenn Chromium sofort wieder beendet wird
  if ((SECONDS - started_at < 10)); then
    sleep 10
  else
    sleep 2
  fi

  start_url="$(pick_start_url)"
done
