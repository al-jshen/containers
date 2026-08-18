# notes

Two independent things:

- `obsidian_client` — linuxserver.io Obsidian desktop in a browser, at https://notes.jshen.net
- `couchdb` (`obsidian_couchdb`) — sync backend for the **Self-hosted LiveSync** plugin,
  at https://notes-sync.jshen.net (also on `127.0.0.1:5984` for local admin)

Credentials live in `.env` (gitignored, see `.env.example`). CouchDB tuning that the
plugin requires (CORS for `app://obsidian.md`, `require_valid_user`, body size limits)
is in `couchdb/local.ini`.

## Client setup (per device)

1. Obsidian → Settings → Community plugins → Browse → install **Self-hosted LiveSync**, enable it.
2. Its setup wizard → "Enable LiveSync with a remote server" → **CouchDB**, then:
   - URI: `https://notes-sync.jshen.net`
   - Username / Password: from `.env`
   - Database name: `obsidian`
   - E2E passphrase: pick one, and use the **same** on every device.
3. "Test Database Connection" and "Check Database Configuration" should both come back clean.
4. First device: pick **"I'm ready, sync all files"** so the vault is uploaded.
   Later devices: start from an *empty* vault and choose to fetch from remote, otherwise
   you get duplicate-file conflicts.
5. Easiest way to add device 2+: on a working device, LiveSync settings → **Copy setup URI**,
   open that `obsidian://setuplivesync?...` link on the other device.

Devices must be able to reach `notes-sync.jshen.net` — that's a tailnet address, so phones
need Tailscale up. Obsidian mobile refuses plain HTTP, but the Caddy cert is a real
Let's Encrypt one, so it's fine.

## Notes

- `local.ini` is mounted `:ro`, which is why the container runs as `user: 5984:5984` —
  the image's entrypoint otherwise tries to chown it and aborts the boot.
- `couchdb/data` is gitignored and owned by uid 5984. To touch it from the host:
  `docker run --rm -v $PWD/couchdb/data:/data alpine <cmd>`
- Changing `local.ini` needs a recreate, not just a restart:
  `docker compose up -d --force-recreate couchdb`
- Housekeeping the plugin expects occasionally: LiveSync settings → "Rebuild everything"
  after big schema/passphrase changes; CouchDB compaction is automatic in 3.x.
