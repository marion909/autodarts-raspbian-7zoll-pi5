#!/usr/bin/env bash
# Single-line Installer:
#   curl -fsSL https://raw.githubusercontent.com/marion909/autodarts-raspbian-7zoll-pi5/main/install.sh | sudo bash
#
# Optionale Umgebungsvariablen (nach "sudo" angeben):
#   ROTATION_OPTION=1..4     Rotation ohne Rückfrage (1=0°, 2=90°, 3=-90°, 4=180°)
#   AUTODARTS_REF=<tag|branch>  Version des Repos (Standard: main)
#   AUTODARTS_REPO=<user/repo>  anderes Repository (z. B. eigener Fork)
set -euo pipefail

REPO="${AUTODARTS_REPO:-marion909/autodarts-raspbian-7zoll-pi5}"
REF="${AUTODARTS_REF:-main}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Bitte als root ausführen:"
  echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/${REF}/install.sh | sudo bash"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
  apt-get update
  apt-get install -y curl ca-certificates tar
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Lade ${REPO}@${REF} ..."
curl -fsSL --retry 3 --connect-timeout 10 --max-time 120 \
  "https://codeload.github.com/${REPO}/tar.gz/${REF}" \
  | tar -xz -C "${WORK_DIR}" --strip-components=1

if [[ ! -f "${WORK_DIR}/setup-autodarts-pi5.sh" ]]; then
  echo "setup-autodarts-pi5.sh im heruntergeladenen Repository nicht gefunden."
  exit 1
fi

bash "${WORK_DIR}/setup-autodarts-pi5.sh" "$@"
