#!/usr/bin/env bash
# Nightly offsite backup: dump the databases that live in named volumes, then
# hand every source to autorestic -> backblaze b2.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }
fail() { log "FAILED: $*"; exit 1; }

[ -f .env ] || fail "backups/.env missing -- copy .env.example and fill in the b2 credentials"
set -a; . ./.env; set +a
for v in AUTORESTIC_B2_B2_ACCOUNT_ID AUTORESTIC_B2_B2_ACCOUNT_KEY AUTORESTIC_B2_RESTIC_PASSWORD; do
    [ -n "${!v:-}" ] || fail "$v is not set in backups/.env"
done
grep -q 'CHANGEME-bucket' .autorestic.yml && fail "set your b2 bucket name in backups/.autorestic.yml"

mkdir -p dumps

# Postgres data lives in docker named volumes. Copying those files while the
# database is running gives an inconsistent (often unrestorable) copy, so dump
# instead. Fixed filenames, not dated: restic dedupes them and the snapshot
# history provides the versions.
dump_pg() {
    local container=$1 user=$2 db=$3 out=$4
    log "dumping $db from $container"
    docker exec "$container" pg_dump -U "$user" -d "$db" > "dumps/$out.tmp" \
        || fail "pg_dump of $db failed"
    [ -s "dumps/$out.tmp" ] || fail "pg_dump of $db produced an empty file"
    mv "dumps/$out.tmp" "dumps/$out"
}

dump_pg authentik-postgresql-1 authentik authentik authentik.sql
dump_pg paperless-db-1        paperless paperless paperless.sql

# aurum is sqlite in WAL mode: aurum.db on its own is missing whatever is still
# in aurum.db-wal, and a copy taken mid-write can open cleanly and be short.
# Its own script takes a consistent snapshot (VACUUM INTO), tars it with the
# uploads, verifies the archive and keeps the newest 7 in aurum/data/backups,
# which autorestic then picks up with the rest of containers/.
#
# Not fatal, unlike the dumps above: the live file still goes offsite and is
# usually restorable, so one service's snapshot failing should not cost every
# other service its nightly backup. The run is still marked failed at the end.
warnings=0
snapshot_aurum() {
    local out
    log "snapshotting aurum"
    if out=$( (cd ../aurum && docker compose run --rm -T aurum scripts/backup.sh) 2>&1 ); then
        log "aurum snapshot: $(printf '%s\n' "$out" | tail -n 1)"
    else
        log "WARNING: aurum snapshot failed, backing up the live file only"
        printf '%s\n' "$out" | tail -n 5
        warnings=$((warnings + 1))
    fi
}

snapshot_aurum

log "running autorestic"
docker compose run --rm autorestic autorestic -c /data/.autorestic.yml --ci backup -a

[ "$warnings" -eq 0 ] || fail "offsite backup ran, but $warnings step(s) above did not -- see WARNING"
log "backup completed"
