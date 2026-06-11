#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/ol-security-patching.conf"
PATCH_MODE="security"
DRY_RUN="false"
REQUESTED_PATCH_MODE=""
LOG_FILE="/var/log/ol-security-patch.log"
LOCK_FILE="/var/run/ol-security-patch.lock"
REBOOT_MARKER="/var/run/reboot-required-by-security-patch"
REBOOT_POLICY="mark-only"
CLEAN_CACHE="true"
PRE_PATCH_HOOK=""
POST_PATCH_HOOK=""

usage() {
  cat <<'USAGE'
Usage:
  ol-security-patch.sh [--mode security|all] [--dry-run] [--config <path>]

Options:
  --mode security|all  Override PATCH_MODE for this run.
  --dry-run            Show the package transaction without applying updates.
  --config <path>      Load an alternate config file.
  -h, --help           Show help.
USAGE
}

log() {
  echo "[$(date -Is)] $*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

ARGS=("$@")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      [[ $# -ge 2 ]] || fail "--config requires a value"
      CONFIG_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -r "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

set -- "${ARGS[@]}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || fail "--mode requires a value"
      REQUESTED_PATCH_MODE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --config)
      [[ $# -ge 2 ]] || fail "--config requires a value"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if [[ -n "$REQUESTED_PATCH_MODE" ]]; then
  PATCH_MODE="$REQUESTED_PATCH_MODE"
fi

case "$PATCH_MODE" in
  security|all)
    ;;
  *)
    fail "PATCH_MODE must be 'security' or 'all'"
    ;;
esac

case "$REBOOT_POLICY" in
  mark-only|ignore)
    ;;
  *)
    fail "REBOOT_POLICY must be 'mark-only' or 'ignore'"
    ;;
esac

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

exec >>"$LOG_FILE" 2>&1

log "===== Oracle Linux patch run started ====="
log "Mode: ${PATCH_MODE}; dry run: ${DRY_RUN}; config: ${CONFIG_FILE}"

if [[ "${EUID}" -ne 0 ]]; then
  fail "Must run as root"
fi

if [[ ! -r /etc/os-release ]]; then
  fail "Unable to read /etc/os-release"
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ol" ]]; then
  fail "Unsupported distribution: ${PRETTY_NAME:-unknown}"
fi

MAJOR="${VERSION_ID%%.*}"

run_hook() {
  local hook="$1"
  local label="$2"

  if [[ -n "$hook" ]]; then
    log "Running ${label} hook: ${hook}"
    "$hook"
  fi
}

run_yum() {
  local transaction=()

  [[ "$CLEAN_CACHE" == "true" ]] && yum clean expire-cache

  if [[ "$PATCH_MODE" == "security" ]]; then
    yum updateinfo list security || true
    transaction=(yum --security update-minimal)
  else
    transaction=(yum update)
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    "${transaction[@]}" --assumeno || true
  else
    "${transaction[@]}" -y
  fi
}

run_dnf() {
  local transaction=()

  [[ "$CLEAN_CACHE" == "true" ]] && dnf clean expire-cache

  if [[ "$PATCH_MODE" == "security" ]]; then
    dnf updateinfo list --security || true
    transaction=(dnf upgrade --security)
  else
    transaction=(dnf upgrade)
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    "${transaction[@]}" --assumeno || true
  else
    "${transaction[@]}" -y
  fi
}

run_hook "$PRE_PATCH_HOOK" "pre-patch"

case "$MAJOR" in
  7)
    log "Detected Oracle Linux 7"
    run_yum
    ;;
  8|9)
    log "Detected Oracle Linux ${MAJOR}"
    run_dnf
    ;;
  *)
    fail "Unsupported Oracle Linux version: ${VERSION_ID:-unknown}"
    ;;
esac

run_hook "$POST_PATCH_HOOK" "post-patch"

log "Patch command completed"

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run complete; reboot marker was not changed"
  log "===== Oracle Linux patch run finished ====="
  exit 0
fi

rm -f "$REBOOT_MARKER"

if command -v needs-restarting >/dev/null 2>&1; then
  if needs-restarting -r; then
    log "No reboot required"
  else
    log "Reboot required"
    if [[ "$REBOOT_POLICY" == "mark-only" ]]; then
      touch "$REBOOT_MARKER"
      log "Created reboot marker: ${REBOOT_MARKER}"
    fi
  fi
else
  log "needs-restarting not installed; reboot status was not checked"
fi

log "===== Oracle Linux patch run finished ====="
