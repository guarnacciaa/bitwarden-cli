# Bitwarden CLI for secret rotation

Container that runs `bw serve` — the **Bitwarden CLI's local REST server**, i.e. the
Vault Management API — so a rotation pipeline can write a freshly generated
password into Bitwarden. Bitwarden EU region by default.

The Bitwarden Public API cannot manage individual vault items (its own docs say to
use the Vault Management API), and Secrets Manager is a separate product: this is
the only path to write real items you can browse.

## Image

Built from this repo and published daily when upstream changes:

- **Docker Hub**: [`guarnacciaa/bitwarden-cli`](https://hub.docker.com/r/guarnacciaa/bitwarden-cli) — `latest` and `:<cli-version>`
- **GHCR**: `ghcr.io/<owner>/bitwarden-cli` — same tags

The workflow (`.github/workflows/build.yml`) asks npm for the latest
`@bitwarden/cli` version, skips the build when that version is already published,
and otherwise builds and pushes to both registries with OCI provenance labels
(`source`, `revision`, `org.opencontainers.image.version` = the CLI version).

## Runtime

| Item | Value |
|------|-------|
| Port | `8091` inside (published as `8191` in the author's homelab: 8091 was taken) |
| Data | `/data` — CLI state (`data.json`) and the persisted session (`.session`) |
| Credentials | none by default: the container idles and prints instructions |
| Server | `BW_SERVER_URL` (default `https://vault.bitwarden.eu`) |

### Unlocking

`bw serve` only answers with an unlocked session. Three sources, in order:

1. `BW_CLIENTID` + `BW_CLIENTSECRET` + `BW_PASSWORD` — API key login + unlock at
   start (unattended, but the master password ends up in the container env)
2. `BW_TOKEN` — a session key from the environment
3. `/data/.session` — a session persisted by a one-shot unlock

The author's setup uses (3): a host script asks for the master password at the
terminal, unlocks inside the container and writes **only the session key** to
`/data/.session` (0600). The master password is never stored; the session can be
revoked by logging out all sessions in the web UI.

## Compose

```yaml
services:
  bitwarden-cli:
    image: guarnacciaa/bitwarden-cli:latest
    container_name: bitwarden-cli
    restart: unless-stopped
    environment:
      BW_SERVER_URL: https://vault.bitwarden.eu
      BW_TOKEN: ${BW_TOKEN:-}
      TZ: Europe/Rome
    ports:
      - "8191:8091"
    volumes:
      - /opt/containers/bitwarden-cli/data:/data
```

To build locally instead: `docker build -t bitwarden-cli:latest .`

## Notes

- `bw serve` re-encrypts values server-side: the client sends plaintext over the
  local API, so keep the port on a trusted network.
- The CLI is installed from the official npm package `@bitwarden/cli` on the
  official `node:22-alpine` base — no third-party image in the chain.
- `docker run --rm bitwarden-cli bw --version` works: arguments bypass the wrapper.
