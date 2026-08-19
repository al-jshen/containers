#!/usr/bin/env bash
# Thin wrapper around plain restic against the b2 repo, for browsing/restoring
# by hand. Anything restic can do works here: ./restic.sh snapshots, ls, find,
# restore, check, stats.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
set -a; . ./.env; set +a

exec docker run --rm -i \
  -e RESTIC_REPOSITORY=b2:substrate-backups:homelab \
  -e RESTIC_PASSWORD="$AUTORESTIC_B2_RESTIC_PASSWORD" \
  -e B2_ACCOUNT_ID="$AUTORESTIC_B2_B2_ACCOUNT_ID" \
  -e B2_ACCOUNT_KEY="$AUTORESTIC_B2_B2_ACCOUNT_KEY" \
  -v "$PWD/restored":/restore \
  restic/restic "$@"
