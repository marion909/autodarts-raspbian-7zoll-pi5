#!/usr/bin/env bash
# Prueft auf eine neuere AutoDarts-Desktop-Version (ARM64) und installiert sie.
#
#   autodarts-update-check.sh            Boot-Check: nur aktualisieren, wenn bereits installiert
#   autodarts-update-check.sh --install  zusaetzlich installieren, wenn noch nicht vorhanden (Setup)
#
# Im Boot-Check-Modus endet das Skript immer mit Exit-Code 0, damit ein
# Netzwerkproblem den Boot nicht als fehlgeschlagen markiert.
set -euo pipefail

LOG_FILE="/var/log/autodarts-update.log"
DOWNLOADS_URL="https://autodarts.io/downloads"
URL_REGEX='https://get\.autodarts\.io/desktop/linux/arm64/autodarts-desktop_[A-Za-z0-9.+~-]+_arm64\.deb'
PACKAGE="autodarts-desktop"

INSTALL_MODE=0
if [[ "${1:-}" == "--install" ]]; then
  INSTALL_MODE=1
fi

export DEBIAN_FRONTEND=noninteractive

log() {
  local msg
  msg="$(date '+%Y-%m-%d %H:%M:%S') $*"
  echo "${msg}"
  echo "${msg}" >>"${LOG_FILE}" 2>/dev/null || true
}

fail() {
  log "$*"
  if [[ "${INSTALL_MODE}" -eq 1 ]]; then
    exit 1
  fi
  exit 0
}

if ! command -v curl >/dev/null 2>&1; then
  fail "curl fehlt, Update-Check uebersprungen"
fi

INSTALLED=0
if [[ "$(dpkg-query -W -f='${Status}' "${PACKAGE}" 2>/dev/null || true)" == "install ok installed" ]]; then
  INSTALLED=1
fi

if [[ "${INSTALLED}" -eq 0 && "${INSTALL_MODE}" -eq 0 ]]; then
  log "${PACKAGE} ist nicht installiert, Update-Check uebersprungen"
  exit 0
fi

CURRENT_VERSION=""
if [[ "${INSTALLED}" -eq 1 ]]; then
  CURRENT_VERSION="$(dpkg-query -W -f='${Version}' "${PACKAGE}")"
fi

# Hoechste ARM64-Version von der Downloadseite ermitteln
LATEST_URL="$(curl -fsSL --connect-timeout 10 --max-time 30 "${DOWNLOADS_URL}" 2>/dev/null \
  | grep -oE "${URL_REGEX}" | sort -uV | tail -n1 || true)"

if [[ -z "${LATEST_URL}" ]]; then
  fail "Konnte aktuelle ARM64-URL nicht ermitteln"
fi

LATEST_FILE="${LATEST_URL##*/}"
LATEST_VERSION=""
VERSION_REGEX='^autodarts-desktop_(.+)_arm64\.deb$'
if [[ "${LATEST_FILE}" =~ $VERSION_REGEX ]]; then
  LATEST_VERSION="${BASH_REMATCH[1]}"
fi

if [[ -z "${LATEST_VERSION}" ]]; then
  fail "Konnte Versionsnummer aus ${LATEST_FILE} nicht lesen"
fi

if [[ "${INSTALLED}" -eq 1 ]]; then
  if dpkg --compare-versions "${LATEST_VERSION}" le "${CURRENT_VERSION}"; then
    log "Kein Update noetig (installiert=${CURRENT_VERSION}, aktuell=${LATEST_VERSION})"
    exit 0
  fi
  log "Update gefunden: ${CURRENT_VERSION} -> ${LATEST_VERSION}"
else
  log "Installiere ${PACKAGE} ${LATEST_VERSION}"
fi

# Temporaeres Verzeichnis (apt/_apt muss die Datei lesen koennen)
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
chmod 755 "${TMP_DIR}"
TMP_DEB="${TMP_DIR}/${LATEST_FILE}"

if ! curl -fL --retry 3 --connect-timeout 10 --max-time 900 -o "${TMP_DEB}" "${LATEST_URL}"; then
  fail "Download fehlgeschlagen: ${LATEST_URL}"
fi
chmod 644 "${TMP_DEB}"

# Plausibilitaetspruefung des Pakets vor der Installation
DEB_PACKAGE="$(dpkg-deb --field "${TMP_DEB}" Package 2>/dev/null || true)"
DEB_ARCH="$(dpkg-deb --field "${TMP_DEB}" Architecture 2>/dev/null || true)"
if [[ "${DEB_PACKAGE}" != "${PACKAGE}" || "${DEB_ARCH}" != "arm64" ]]; then
  fail "Heruntergeladene Datei ist kein ${PACKAGE}-ARM64-Paket (Package='${DEB_PACKAGE}', Arch='${DEB_ARCH}'), abgebrochen"
fi

if apt-get install -y -o DPkg::Lock::Timeout=120 "${TMP_DEB}"; then
  log "Erfolgreich installiert: ${LATEST_VERSION}"
else
  fail "Installation fehlgeschlagen"
fi
