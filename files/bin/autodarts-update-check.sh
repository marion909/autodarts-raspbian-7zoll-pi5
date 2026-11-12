#!/usr/bin/env bash
# Prueft auf eine neuere AutoDarts-Desktop-Version (Linux ARM64, AppImage) und installiert sie.
#
#   autodarts-update-check.sh            Boot-Check: nur aktualisieren, wenn bereits installiert
#   autodarts-update-check.sh --install  zusaetzlich installieren, wenn noch nicht vorhanden (Setup)
#
# Kanal: AUTODARTS_CHANNEL=stable|beta (Standard: stable, siehe /etc/default/autodarts-update)
#
# Im Boot-Check-Modus endet das Skript immer mit Exit-Code 0, damit ein
# Netzwerkproblem den Boot nicht als fehlgeschlagen markiert.
set -euo pipefail

LOG_FILE="/var/log/autodarts-update.log"
INSTALL_DIR="/opt/autodarts"
APPIMAGE="${INSTALL_DIR}/autodarts-desktop.AppImage"
VERSION_FILE="${INSTALL_DIR}/version"
RELEASES_BASE="https://releases.autodarts.com/desktop/downloads"
CHANNEL="${AUTODARTS_CHANNEL:-stable}"
FILE_REGEX='^autodarts-desktop_[A-Za-z0-9.+~-]+_linux-arm64\.AppImage$'

INSTALL_MODE=0
if [[ "${1:-}" == "--install" ]]; then
  INSTALL_MODE=1
fi

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

case "${CHANNEL}" in
  stable | beta) ;;
  *) fail "Ungueltiger Kanal '${CHANNEL}' (erlaubt: stable, beta)" ;;
esac

for tool in curl jq; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    fail "${tool} fehlt, Update-Check uebersprungen"
  fi
done

INSTALLED=0
CURRENT_VERSION=""
if [[ -x "${APPIMAGE}" ]]; then
  INSTALLED=1
  CURRENT_VERSION="$(cat "${VERSION_FILE}" 2>/dev/null || true)"
fi

if [[ "${INSTALLED}" -eq 0 && "${INSTALL_MODE}" -eq 0 ]]; then
  log "AutoDarts Desktop ist nicht installiert, Update-Check uebersprungen"
  exit 0
fi

# Neueste Version des Kanals ermitteln
INDEX_URL="${RELEASES_BASE}/latest.${CHANNEL}.json"
INDEX_JSON="$(curl -fsSL --retry 2 --connect-timeout 10 --max-time 30 "${INDEX_URL}" 2>/dev/null || true)"
if [[ -z "${INDEX_JSON}" ]]; then
  fail "Konnte ${INDEX_URL} nicht abrufen"
fi

# Erste AppImage-Datei der Plattform linux-arm64: Version, Dateiname, URL, Groesse
INFO="$(jq -r '
  .platforms["linux-arm64"] as $p
  | ([$p.files[]? | select(.name | endswith(".AppImage"))] | first) as $f
  | select($f != null)
  | [$p.version, $f.name, $f.url, ($f.size // 0 | tostring)] | @tsv
' <<<"${INDEX_JSON}" 2>/dev/null || true)"

if [[ -z "${INFO}" ]]; then
  fail "Kein ARM64-AppImage im Kanal '${CHANNEL}' gefunden"
fi

IFS=$'\t' read -r LATEST_VERSION LATEST_FILE LATEST_URL LATEST_SIZE <<<"${INFO}"

if [[ ! "${LATEST_FILE}" =~ ${FILE_REGEX} || "${LATEST_URL}" != "${RELEASES_BASE}/${LATEST_FILE}" ]]; then
  fail "Unerwarteter Dateiname oder URL in der Release-Liste (${LATEST_FILE} / ${LATEST_URL}), abgebrochen"
fi

if [[ "${INSTALLED}" -eq 1 ]]; then
  if [[ "${LATEST_VERSION}" == "${CURRENT_VERSION}" ]]; then
    log "Kein Update noetig (Kanal=${CHANNEL}, Version=${CURRENT_VERSION})"
    exit 0
  fi
  log "Update gefunden (Kanal=${CHANNEL}): ${CURRENT_VERSION:-unbekannt} -> ${LATEST_VERSION}"
else
  log "Installiere AutoDarts Desktop ${LATEST_VERSION} (Kanal=${CHANNEL})"
fi

install -d -m 0755 "${INSTALL_DIR}"
TMP_FILE="$(mktemp "${INSTALL_DIR}/.download.XXXXXX")"
trap 'rm -f "${TMP_FILE}"' EXIT

if ! curl -fsSL --retry 3 --connect-timeout 10 --max-time 900 -o "${TMP_FILE}" "${LATEST_URL}"; then
  fail "Download fehlgeschlagen: ${LATEST_URL}"
fi

# Plausibilitaetspruefung: Groesse laut Release-Liste und ELF-Header (AppImages sind ELF-Dateien)
ACTUAL_SIZE="$(wc -c <"${TMP_FILE}" | tr -d ' ')"
if [[ "${LATEST_SIZE}" -gt 0 && "${ACTUAL_SIZE}" -ne "${LATEST_SIZE}" ]]; then
  fail "Dateigroesse stimmt nicht (erwartet ${LATEST_SIZE}, erhalten ${ACTUAL_SIZE}), abgebrochen"
fi
if [[ "$(head -c 4 "${TMP_FILE}" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]]; then
  fail "Heruntergeladene Datei ist kein AppImage (ELF-Header fehlt), abgebrochen"
fi

# Atomar ersetzen (laufende Instanzen behalten ihre alte Datei)
chmod 0755 "${TMP_FILE}"
mv -f "${TMP_FILE}" "${APPIMAGE}"
echo "${LATEST_VERSION}" >"${VERSION_FILE}"
log "Erfolgreich installiert: ${LATEST_VERSION}"
