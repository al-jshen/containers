#!/usr/bin/env bash
# Fortnightly repository verification. Plain `check` validates structure only;
# --read-data-subset actually downloads and re-hashes a slice of the data, which
# is what catches bit-rot and truncated uploads. 20% of ~3 GiB is ~600 MiB per
# run, well inside b2's free egress allowance (3x stored per month).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

log "starting restic check (--read-data-subset=20%)"
if ./restic.sh check --read-data-subset=20%; then
    log "CHECK PASSED"
else
    rc=$?
    log "CHECK FAILED (exit $rc) -- repository may be damaged, investigate before trusting a restore"
    exit $rc
fi
