#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Bitte als root ausführen: sudo bash setup-autodarts-pi5.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

TARGET_USER="${TARGET_USER:-${SUDO_USER:-pi}}"
if ! id -u "${TARGET_USER}" >/dev/null 2>&1; then
  echo "Benutzer '${TARGET_USER}' existiert nicht. Mit TARGET_USER=<name> den Desktop-Benutzer angeben."
  exit 1
fi
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" ]]; then
  echo "Konnte Home-Verzeichnis von ${TARGET_USER} nicht ermitteln."
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${SCRIPT_DIR}/files"
ASSETS_DIR="${SCRIPT_DIR}/assets"
BOOT_SPLASH_SRC="${ASSETS_DIR}/boot-splash.png"
WALLPAPER_SRC="${ASSETS_DIR}/wallpaper.jpg"
SHARE_DIR="/usr/local/share/autodarts"
AUTODARTS_EXTENSION_ID="oolfddhehmbpdnlmoljmllcdggmkgihh"
AUTODARTS_EXTENSION_UPDATE_URL="https://clients2.google.com/service/update2/crx"

if [[ ! -d "${FILES_DIR}" ]]; then
  echo "Verzeichnis '${FILES_DIR}' fehlt. Bitte das komplette Repository verwenden (oder install.sh)."
  exit 1
fi

TOTAL_STEPS=8
STEP=0
step() {
  STEP=$((STEP + 1))
  echo "[${STEP}/${TOTAL_STEPS}] $*"
}

# --- Rotation wählen -------------------------------------------------------
# ROTATION_OPTION kann per Umgebungsvariable gesetzt werden. Sonst wird,
# falls ein Terminal vorhanden ist (auch bei "curl | sudo bash"), gefragt.
ROTATION_OPTION="${ROTATION_OPTION:-}"
if [[ -z "${ROTATION_OPTION}" ]] && (exec </dev/tty) 2>/dev/null; then
  echo ""
  echo "Screen Rotation wählen:"
  echo "  1) Keine Rotation"
  echo "  2) 90°"
  echo "  3) -90°"
  echo "  4) 180°"
  read -r -p "Option [1-4, Enter=1]: " ROTATION_OPTION </dev/tty || ROTATION_OPTION=""
fi
ROTATION_OPTION="${ROTATION_OPTION:-1}"

case "${ROTATION_OPTION}" in
  1) ROTATION_XRANDR="normal"; ROTATION_LABEL="0" ;;
  2) ROTATION_XRANDR="right"; ROTATION_LABEL="90" ;;
  3) ROTATION_XRANDR="left"; ROTATION_LABEL="-90" ;;
  4) ROTATION_XRANDR="inverted"; ROTATION_LABEL="180" ;;
  *)
    echo "Ungültige Rotation-Option '${ROTATION_OPTION}', nutze 1 (keine Rotation)."
    ROTATION_OPTION="1"
    ROTATION_XRANDR="normal"
    ROTATION_LABEL="0"
    ;;
esac

# Display-Parameter (per Umgebungsvariable überschreibbar)
DSI_MODE="${DSI_MODE:-800x480}"
DSI_SCALE="${DSI_SCALE:-1.2x1.2}"
MIRROR_HDMI="${MIRROR_HDMI:-1}"

# --- 1) Pakete ---------------------------------------------------------------
step "Pakete aktualisieren"
apt-get update
apt-get -y upgrade

# --- 2) Chromium + Abhängigkeiten ---------------------------------------------
step "Chromium + Kiosk Abhängigkeiten installieren"
CHROMIUM_PACKAGE="chromium"
if ! apt-cache show chromium >/dev/null 2>&1; then
  CHROMIUM_PACKAGE="chromium-browser"
fi

apt-get install -y --no-install-recommends \
  "${CHROMIUM_PACKAGE}" \
  curl \
  ca-certificates \
  unclutter \
  x11-xserver-utils

# --- 3) Skripte, Service, Autostart ------------------------------------------
step "Skripte, Update-Service und Autostart installieren"

# Aufräumen von Vorgängerversionen (separate Rotations-/Mirror-Skripte)
rm -f /usr/local/bin/autodarts-rotate-display.sh \
  /usr/local/bin/autodarts-mirror-display.sh \
  /etc/xdg/autostart/autodarts-rotation.desktop \
  /etc/xdg/autostart/autodarts-mirror.desktop \
  /etc/default/autodarts-display-rotation

for script in autodarts-kiosk.sh autodarts-display.sh autodarts-update-check.sh autodarts-set-wallpaper.sh; do
  install -D -m 0755 "${FILES_DIR}/bin/${script}" "/usr/local/bin/${script}"
done

install -D -m 0644 "${FILES_DIR}/share/offline.html" "${SHARE_DIR}/offline.html"
install -D -m 0644 "${FILES_DIR}/autostart/autodarts-kiosk.desktop" /etc/xdg/autostart/autodarts-kiosk.desktop
install -D -m 0644 "${FILES_DIR}/systemd/autodarts-update-check.service" /etc/systemd/system/autodarts-update-check.service

systemctl daemon-reload
systemctl enable autodarts-update-check.service >/dev/null 2>&1 || true

# --- 4) AutoDarts Desktop ------------------------------------------------------
step "Autodarts Desktop (ARM64) installieren"
if ! /usr/local/bin/autodarts-update-check.sh --install; then
  echo "WARNUNG: AutoDarts Desktop konnte nicht installiert werden (siehe /var/log/autodarts-update.log)."
  echo "         Setup erneut ausführen oder das .deb manuell von https://autodarts.io/downloads installieren."
fi

# --- 5) Chromium-Erweiterung ---------------------------------------------------
step "Chrome Extension 'Tools for Autodarts' konfigurieren"
for policy_dir in /etc/chromium/policies/managed /etc/chromium-browser/policies/managed; do
  mkdir -p "${policy_dir}"
  cat >"${policy_dir}/autodarts-tools-extension.json" <<EOF
{
  "ExtensionInstallForcelist": [
    "${AUTODARTS_EXTENSION_ID};${AUTODARTS_EXTENSION_UPDATE_URL}"
  ]
}
EOF
done

# --- 6) Display-Konfiguration ---------------------------------------------------
step "Display-Konfiguration schreiben (Rotation ${ROTATION_LABEL}°)"
{
  echo "# Wird von /usr/local/bin/autodarts-display.sh gelesen (Setup erneut ausführen oder hier anpassen)."
  printf 'ROTATION_OPTION=%q\n' "${ROTATION_OPTION}"
  printf 'ROTATION_DEGREES=%q\n' "${ROTATION_LABEL}"
  printf 'ROTATION_XRANDR=%q\n' "${ROTATION_XRANDR}"
  printf 'DSI_MODE=%q\n' "${DSI_MODE}"
  printf 'DSI_SCALE=%q\n' "${DSI_SCALE}"
  printf 'MIRROR_HDMI=%q\n' "${MIRROR_HDMI}"
} >/etc/default/autodarts-display

# --- 7) Bootscreen + Wallpaper ---------------------------------------------------
step "Bootscreen und Hintergrund setzen"
if [[ -f "${BOOT_SPLASH_SRC}" ]]; then
  install -m 0644 "${BOOT_SPLASH_SRC}" /usr/share/plymouth/themes/pix/splash.png 2>/dev/null || true
  install -m 0644 "${BOOT_SPLASH_SRC}" /usr/share/plymouth/themes/pix/splash-16x9.png 2>/dev/null || true
  install -m 0644 "${BOOT_SPLASH_SRC}" /boot/firmware/splash.png 2>/dev/null || true
  if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u || true
  fi
fi

if [[ -f "${WALLPAPER_SRC}" ]]; then
  WALLPAPER_DST="${SHARE_DIR}/wallpaper.jpg"
  install -D -m 0644 "${WALLPAPER_SRC}" "${WALLPAPER_DST}"
  install -D -m 0644 "${FILES_DIR}/autostart/autodarts-wallpaper.desktop" /etc/xdg/autostart/autodarts-wallpaper.desktop

  # Bestehende pcmanfm-Konfiguration einmalig sichern, dann überschreiben
  for profile in LXDE LXDE-pi; do
    conf_dir="${TARGET_HOME}/.config/pcmanfm/${profile}"
    conf_file="${conf_dir}/desktop-items-0.conf"
    mkdir -p "${conf_dir}"
    if [[ -f "${conf_file}" && ! -f "${conf_file}.autodarts-bak" ]]; then
      cp -a "${conf_file}" "${conf_file}.autodarts-bak"
    fi
    cat >"${conf_file}" <<EOF
[*]
wallpaper=${WALLPAPER_DST}
wallpaper_mode=stretch
desktop_bg=#000000
show_wm_menu=0
EOF
  done
fi

# --- 8) Session, Autologin, Keyring -------------------------------------------------
if command -v raspi-config >/dev/null 2>&1; then
  step "X11-Session für On-Screen-Keyboard und Auto-Login auf Desktop aktivieren"
  raspi-config nonint do_wayland W1 || true
  raspi-config nonint do_boot_behaviour B4 || true
else
  step "raspi-config nicht gefunden, Auto-Login und X11 bitte manuell aktivieren"
fi

echo "GNOME Keyring Prompt deaktivieren"
mkdir -p "${TARGET_HOME}/.config/autostart"
for keyring_file in \
  gnome-keyring-pkcs11.desktop \
  gnome-keyring-secrets.desktop \
  gnome-keyring-ssh.desktop \
  gnome-keyring-gpg.desktop; do
  cat >"${TARGET_HOME}/.config/autostart/${keyring_file}" <<EOF
[Desktop Entry]
Type=Application
Hidden=true
EOF
done

chown -R "${TARGET_USER}:" "${TARGET_HOME}/.config" || true

echo
echo "Fertig. Bitte neu starten: sudo reboot"
