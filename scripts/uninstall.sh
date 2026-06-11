#!/usr/bin/env bash
set -euo pipefail

PURGE_CONFIG="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-config)
      PURGE_CONFIG="true"
      shift
      ;;
    -h|--help)
      echo "Usage: uninstall.sh [--purge-config]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Must run as root" >&2
  exit 1
fi

systemctl disable --now ol-security-patch.timer 2>/dev/null || true
rm -f /etc/systemd/system/ol-security-patch.service
rm -f /etc/systemd/system/ol-security-patch.timer
rm -f /usr/local/sbin/ol-security-patch.sh

if [[ "$PURGE_CONFIG" == "true" ]]; then
  rm -f /etc/ol-security-patching.conf
fi

systemctl daemon-reload

echo "Uninstalled Oracle Linux patching timer."
