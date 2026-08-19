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

log "running autorestic"
docker compose run --rm autorestic autorestic -c /data/.autorestic.yml --ci backup -a

log "backup completed"
