#!/bin/sh
# Start `bw serve` with an unlocked session, or stay idle so an operator can log in.
#
# Credential sources, in order:
#   1. BW_CLIENTID + BW_CLIENTSECRET + BW_PASSWORD  -> API key login + unlock
#   2. BW_TOKEN                                     -> session key from the stack env
#   3. /data/.session                               -> session persisted by bw_unlock.sh
# With none of them the container stays up and prints how to log in; it never
# crash-loops and keeps the volume, so a manual unlock survives a restart.
set -eu

# `docker run image bw ...` must run the CLI directly, not the wrapper: without
# this the arguments are swallowed and the container idles forever.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

export HOME=/data
BW_SERVER_URL="${BW_SERVER_URL:-https://vault.bitwarden.eu}"

echo "[bw] server: $BW_SERVER_URL"
bw config server "$BW_SERVER_URL" >/dev/null 2>&1 || echo "[bw] WARN: config server failed (already configured?)"

SESSION=""

if [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ] && [ -n "${BW_PASSWORD:-}" ]; then
  echo "[bw] login with the personal API key"
  bw login --apikey >/dev/null 2>&1 || echo "[bw] note: already logged in, continuing"
  echo "[bw] unlocking the vault"
  SESSION="$(bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || true)"
elif [ -n "${BW_TOKEN:-}" ]; then
  echo "[bw] using the session key from BW_TOKEN"
  SESSION="$BW_TOKEN"
elif [ -s /data/.session ]; then
  echo "[bw] using the session persisted in /data/.session (written by bw_unlock.sh)"
  SESSION="$(cat /data/.session)"
fi

if [ -z "$SESSION" ]; then
  cat <<'EOT'
[bw] no session: container idle on purpose.

Run this once on the host and the container picks the session up on restart:
    /root/bw_unlock.sh
It asks for the master password at the terminal and stores only the session key
in this container's /data/.session (0600). The master password is never written
anywhere: not in Vault, not in the stack env, not in a log.

Alternative, for unattended restarts: set BW_CLIENTID / BW_CLIENTSECRET /
BW_PASSWORD in this stack's env (encrypted at rest, but that is the vault master
password — a bigger blast radius than the session key).
EOT
  exec sleep infinity
fi

echo "$SESSION" > /data/.session
chmod 600 /data/.session
export BW_SESSION="$SESSION"
bw sync >/dev/null 2>&1 || echo "[bw] WARN: sync failed, serving the local cache"

echo "[bw] serving on 0.0.0.0:8091"
exec bw serve --hostname 0.0.0.0 --port 8091 --disable-origin-protection
