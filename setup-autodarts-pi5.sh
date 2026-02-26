#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Bitte als root ausführen: sudo bash setup-autodarts-pi5.sh"
  exit 1
fi

TARGET_USER="${SUDO_USER:-pi}"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" ]]; then
  echo "Konnte Home-Verzeichnis von ${TARGET_USER} nicht ermitteln."
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"
BOOT_SPLASH_SRC="${ASSETS_DIR}/boot-splash.png"
WALLPAPER_SRC="${ASSETS_DIR}/wallpaper.jpg"
AUTODARTS_EXTENSION_ID="oolfddhehmbpdnlmoljmllcdggmkgihh"
AUTODARTS_EXTENSION_UPDATE_URL="https://clients2.google.com/service/update2/crx"

echo "[1/6] Pakete aktualisieren"
apt-get update
apt-get -y upgrade

echo "[2/6] Chromium + Kiosk Abhängigkeiten installieren"
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

echo "[3/6] Autodarts Desktop (ARM64) installieren"
AUTODARTS_URL="$(curl -fsSL https://autodarts.io/downloads | grep -oE 'https://get\.autodarts\.io/desktop/linux/arm64/[^" ]+\.deb' | head -n1 || true)"
if [[ -z "${AUTODARTS_URL}" ]]; then
  AUTODARTS_URL="https://get.autodarts.io/desktop/linux/arm64/autodarts-desktop_1.5.0_arm64.deb"
fi

tmp_deb="/tmp/autodarts-desktop_arm64.deb"
curl -fL "${AUTODARTS_URL}" -o "${tmp_deb}"
apt-get install -y "${tmp_deb}"
rm -f "${tmp_deb}"

echo "[Bonus] Chrome Extension 'Tools for Autodarts' konfigurieren"
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

echo "[4/6] Kiosk Startskript anlegen"
cat >/usr/local/bin/autodarts-kiosk.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

URL="https://play.autodarts.io/"

xset s off || true
xset -dpms || true
xset s noblank || true
unclutter -idle 0.5 -root &

while ! curl -Is https://play.autodarts.io >/dev/null 2>&1; do
  sleep 2
done

CHROMIUM_BIN="$(command -v chromium || command -v chromium-browser || true)"
if [[ -z "${CHROMIUM_BIN}" ]]; then
  echo "Chromium wurde nicht gefunden."
  exit 1
fi

if command -v autodarts-desktop >/dev/null 2>&1; then
  autodarts-desktop &
  sleep 5
fi

KIOSK_PROFILE="${HOME}/.config/autodarts-kiosk"
mkdir -p "${KIOSK_PROFILE}"

"${CHROMIUM_BIN}" \
  --kiosk \
  --start-fullscreen \
  --force-device-scale-factor=0.85 \
  --password-store=basic \
  --user-data-dir="${KIOSK_PROFILE}" \
  --profile-directory=Default \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --autoplay-policy=no-user-gesture-required \
  "${URL}"
EOF
chmod +x /usr/local/bin/autodarts-kiosk.sh

echo "[5/6] Desktop-Autostart konfigurieren"
mkdir -p /etc/xdg/autostart
cat >/etc/xdg/autostart/autodarts-kiosk.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Autodarts Kiosk
Comment=Startet play.autodarts.io im Vollbild
Exec=/usr/local/bin/autodarts-kiosk.sh
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF

echo "[Bonus] Bootscreen und Hintergrund setzen"
if [[ -f "${BOOT_SPLASH_SRC}" ]]; then
  install -m 0644 "${BOOT_SPLASH_SRC}" /usr/share/plymouth/themes/pix/splash.png 2>/dev/null || true
  install -m 0644 "${BOOT_SPLASH_SRC}" /usr/share/plymouth/themes/pix/splash-16x9.png 2>/dev/null || true
  install -m 0644 "${BOOT_SPLASH_SRC}" /boot/firmware/splash.png 2>/dev/null || true
  if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u || true
  fi
fi

if [[ -f "${WALLPAPER_SRC}" ]]; then
  WALLPAPER_DST="/usr/share/backgrounds/autodarts-wallpaper.jpg"
  if [[ ! -d "/usr/share/backgrounds" ]]; then
    mkdir -p /usr/local/share/backgrounds
    WALLPAPER_DST="/usr/local/share/backgrounds/autodarts-wallpaper.jpg"
  fi
  mkdir -p "$(dirname "${WALLPAPER_DST}")"
  install -m 0644 "${WALLPAPER_SRC}" "${WALLPAPER_DST}"

  cat >/usr/local/bin/autodarts-set-wallpaper.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${WALLPAPER_DST}"
if [[ ! -f "\${WALLPAPER}" ]]; then
  exit 0
fi

for _ in 1 2 3 4 5; do
  if command -v pcmanfm >/dev/null 2>&1; then
    pcmanfm --set-wallpaper "\${WALLPAPER}" --wallpaper-mode=stretch >/dev/null 2>&1 || true
  fi
  sleep 1
done
EOF
  chmod +x /usr/local/bin/autodarts-set-wallpaper.sh

  cat >/etc/xdg/autostart/autodarts-wallpaper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Autodarts Wallpaper
Comment=Setzt den Desktop-Hintergrund beim Login
Exec=/usr/local/bin/autodarts-set-wallpaper.sh
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF

  mkdir -p "${TARGET_HOME}/.config/pcmanfm/LXDE"
  mkdir -p "${TARGET_HOME}/.config/pcmanfm/LXDE-pi"
  cat >"${TARGET_HOME}/.config/pcmanfm/LXDE/desktop-items-0.conf" <<EOF
[*]
wallpaper=${WALLPAPER_DST}
wallpaper_mode=stretch
desktop_bg=#000000
show_wm_menu=0
EOF

  cat >"${TARGET_HOME}/.config/pcmanfm/LXDE-pi/desktop-items-0.conf" <<EOF
[*]
wallpaper=${WALLPAPER_DST}
wallpaper_mode=stretch
desktop_bg=#000000
show_wm_menu=0
EOF
fi

if command -v raspi-config >/dev/null 2>&1; then
  echo "[6/6] Auto-Login auf Desktop aktivieren"
  raspi-config nonint do_boot_behaviour B4 || true
else
  echo "[6/6] raspi-config nicht gefunden, Auto-Login bitte manuell aktivieren."
fi

echo "[Bonus] GNOME Keyring Prompt deaktivieren"
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

chown -R "${TARGET_USER}":"${TARGET_USER}" "${TARGET_HOME}"/.config 2>/dev/null || true

echo
echo "Fertig. Bitte neu starten: sudo reboot"
