#!/usr/bin/env bash
# Paperless keeps documents in a docker volume, so document_exporter writes a
# portable copy; this mirrors that copy onto /external (the second disk).
set -euo pipefail

SRC=/home/mushy/containers/paperless-ngx/export
DST=/external/backups/paperless_export

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

log "exporting paperless documents"
docker exec paperless-webserver-1 document_exporter ../export

# trailing slashes: mirror the *contents* of the export dir into DST.
# no -z (local copy, compression just burns cpu) and no -u (this is a mirror,
# newest-wins would mask deletions).
log "syncing export to $DST"
mkdir -p "$DST"
rsync -a --delete --info=stats1 "$SRC/" "$DST/"

log "done ($(du -sh "$DST" | cut -f1))"
