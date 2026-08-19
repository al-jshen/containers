# Restoring from backup

## What you need first (none of it lives on the dead machine)

1. **B2 credentials** — keyID + applicationKey for the `substrate-backups` bucket
2. **The restic repository password** — from `backups/.env`
3. **The repo** — `git clone git@github.com:al-jshen/containers.git`

Items 1 and 2 must be stored somewhere *off this machine*. Note the trap: the
self-hosted Vaultwarden is itself on this box, so it cannot be the only copy of
these secrets. Use a phone password manager, a printed copy, or another cloud
account.

Without the restic password the backups are permanently unreadable. There is no
recovery path, no reset, no support to call.

## You do not need autorestic to restore

The bucket holds a plain restic repository. Autorestic is only a scheduling
convenience -- restore with vanilla restic and skip the whole compose setup:

```bash
export RESTIC_REPOSITORY=b2:substrate-backups:homelab
export RESTIC_PASSWORD='<repo password>'
export B2_ACCOUNT_ID='<keyID>'
export B2_ACCOUNT_KEY='<applicationKey>'

alias r='docker run --rm -it \
  -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e B2_ACCOUNT_ID -e B2_ACCOUNT_KEY \
  -v "$PWD/restored":/restore restic/restic'
```

## Restore

```bash
r snapshots                 # list what is available
r restore latest --target /restore                    # everything
r restore latest --target /restore --include /backup/containers/vaultwarden
r ls latest                 # browse a snapshot's contents
r find '*.kdbx'             # locate a file across snapshots
```

Paths inside a snapshot use the container's view:

| In the snapshot | Was on disk at |
|---|---|
| `/backup/containers/...` | `/home/mushy/containers/...` |
| `/backup/external/...` | `/external/backups/...` |
| `/backup/paperless-media/...` | docker volume `paperless_media` |
| `/backup/paperless-data/...` | docker volume `paperless_data` |

## Rebuilding services

1. Install docker + compose, `git clone` the repo to `~/containers`.
2. Restore `/backup/containers` over it -- that supplies the gitignored `.env`
   files and service config dirs that GitHub does not have.
3. **authentik**: `docker compose up -d postgresql`, then
   `docker exec -i authentik-postgresql-1 psql -U authentik -d authentik < backups/dumps/authentik.sql`,
   then bring up server + worker.
4. **paperless**: restore the `paperless_media` / `paperless_data` volumes from
   the snapshot, then load `backups/dumps/paperless.sql` the same way. Simpler
   alternative: start empty and run `document_importer` against
   `/external/backups/paperless_export`.
5. **vaultwarden**: restore `containers/vaultwarden` (live data), or use a dated
   archive from `external/vaultwarden`.
6. **home assistant / notes(couchdb) / navidrome / calibre**: restore their
   directories under `containers/` and `docker compose up -d`.

Databases come from the `.sql` dumps, never from copied files -- a file-level
copy of a running postgres is usually unrestorable.

## Verifying (do this occasionally, not just when it's an emergency)

```bash
r check                     # repository integrity
r check --read-data-subset=5%   # actually re-read and verify 5% of the data
r restore latest --target /tmp/testrestore --include <some path>
```

A backup nobody has restored from is a hypothesis, not a backup.
