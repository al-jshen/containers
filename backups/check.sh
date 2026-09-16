#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

log "starting restic check (--read-data-subset=500M)"
if ./restic.sh check --read-data-subset=500M; then
  log "CHECK PASSED"
else
  rc=$?
  log "CHECK FAILED (exit $rc) -- repository may be damaged, investigate before trusting a restore"
  exit $rc
fi
