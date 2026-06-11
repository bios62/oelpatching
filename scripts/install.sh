#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Must run as root" >&2
  exit 1
fi

install -m 0750 "$ROOT_DIR/scripts/ol-security-patch.sh" /usr/local/sbin/ol-security-patch.sh
install -m 0644 "$ROOT_DIR/config/ol-security-patching.conf" /etc/ol-security-patching.conf
install -m 0644 "$ROOT_DIR/systemd/ol-security-patch.service" /etc/systemd/system/ol-security-patch.service
install -m 0644 "$ROOT_DIR/systemd/ol-security-patch.timer" /etc/systemd/system/ol-security-patch.timer

systemctl daemon-reload
systemctl enable --now ol-security-patch.timer

echo "Installed Oracle Linux patching timer."
echo "Edit /etc/ol-security-patching.conf to adjust patch mode or reboot handling."
