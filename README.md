# 🏠 Home Media Server Stack

A self-hosted media server stack running on Docker, with three independent access paths:

- **Caddy** (via the `caddy-cloudflare` image) — **local access only**. Acts as a reverse proxy using the Cloudflare DNS-01 challenge for wildcard TLS certificates, resolved through local DNS. Never exposes services to the internet on its own.
- **Cloudflared** — **public access only**. Runs the Cloudflare Tunnel independently of Caddy, routing traffic from the internet directly to services by host:port, configured entirely in the Cloudflare dashboard.
- **TSDProxy** — **both local and public access**. Exposes select services as Tailscale nodes, reachable on your private tailnet; for services with `tsdproxy.funnel: true` (currently Jellyfin and Navidrome), it also publishes them to the public internet via Tailscale Funnel.

---

## 📦 Stack Overview

| Service | Description | Port |
|---|---|---|
| [Jellyfin](#jellyfin) | Media server (movies, shows, music) | `8096` |
| [Jellystat](#jellystat) | Jellyfin statistics dashboard | `3000` (internal) |
| [Sonarr](#sonarr) | TV show management | `8989` |
| [Radarr](#radarr) | Movie management | `7878` |
| [Lidarr](#lidarr) | Music management | `8686` |
| [Bazarr](#bazarr) | Subtitle management | `6767` |
| [Prowlarr](#prowlarr) | Indexer manager | `9696` |
| [qBittorrent](#qbittorrent) | Torrent client | `8090` (internal) |
| [Seerr](#seerr) | Media request manager | `5055` |
| [Lidatube](#lidatube) | YouTube → Lidarr downloader | `5000` (internal) |
| [Metube](#metube) | YouTube downloader UI | `8081` (internal) |
| [Navidrome](#navidrome) | Music streaming server | `4533` |
| [Nextcloud](#nextcloud) | Self-hosted cloud storage | `8083` |
| [Unmanic](#unmanic) | Media transcoding pipeline | `8888` |
| [BentoPDF](#bentopdf) | PDF tools | `8080` (internal) |
| [Immich](#immich) | Photo/video backup | `2283` |
| [Portainer](#portainer) | Docker management UI | `9000` |
| [Dashdot](#dashdot) | Server stats dashboard | `3001` |
| [Flaresolverr](#flaresolverr) | Cloudflare bypass for indexers | `8191` |
| [Watchtower](#watchtower) | Automatic container updates | — |
| [Cloudflared](#cloudflared) | Cloudflare Tunnel | — |
| [TSDProxy](#tsdproxy) | Tailscale reverse proxy | — (internal only) |
| [Caddy](#caddy) | Reverse proxy with TLS (`caddy-cloudflare`) | `80`, `443` |

> **Beszel** and **Beszel Agent** are currently **commented out** in `docker-compose.yml` (monitoring is not active). Several other previously-listed services (Slskd, Soulsync, Stirling PDF, AdGuard, Feishin, Filebrowser, Homepage, Speedtest, Tracearr, Wizarr, Sharkord, Synapse, and others) are also currently **commented out**, but Caddy still carries route definitions for most of them — see [Notes](#-notes) below.

---

## 🗂️ Directory Structure

```
.
├── docker-compose.yml
├── Caddyfile               # Caddy config
├── hwaccel.ml.yml          # Immich hardware acceleration config
└── .env                    # Environment variables (see below)
```

Media and config are stored on the host:

```
/mnt/
├── docker/                 # Container config/data volumes
│   ├── jellyfin/
│   │   ├── jellyfin_config/
│   │   └── jellyfin_cache/
│   ├── sonarr/
│   ├── radarr/
│   ├── lidarr/
│   ├── bazarr/
│   ├── prowlarr/
│   ├── qbittorrent/
│   ├── seerr/
│   ├── jellystat/
│   │   ├── jellystat-backup-data/
│   │   └── jellystat-db/
│   ├── lidatube/
│   ├── navidrome/
│   ├── nextcloud/
│   ├── immich/
│   │   ├── postgres/
│   │   ├── immich_machine_learning/cache/
│   │   └── redis/
│   ├── flaresolverr/
│   ├── portainer_data/
│   ├── unmanic/
│   ├── tsdproxy/
│   └── caddy-cloudflare/
├── media/                  # Media library
│   └── torrent/
│       ├── Music/
│       ├── Shows/
│       ├── Movies/
│       ├── downloads/
│       └── staging/
├── immichdata/             # Immich media uploads
└── nextclouddata/          # Nextcloud user data
```

---

## ⚙️ Environment Variables

Create a `.env` file in the same directory as `docker-compose.yml`:

```env
# General
TZ=Europe/Istanbul
PUID=1000
PGID=1000
HOSTNAME=your-hostname

# Cloudflare
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
TUNNEL_TOKEN=your_cloudflare_tunnel_token
DOMAIN=yourdomain.com
OLDDOMAIN=youroldomain.com   # Tailscale domain, used for legacy TLS access

# Jellystat DB
JELLYSTATDB_POSTGRES_USER=jellystat
JELLYSTATDB_POSTGRES_PASSWORD=strongpassword
JELLYSTATDB_POSTGRES_IP=jellystat-db
JELLYSTATDB_POSTGRES_PORT=5432
JELLYSTAT_JWT_SECRET=your_jwt_secret

# Immich
UPLOAD_LOCATION=/mnt/immichdata
DB_DATA_LOCATION=/mnt/docker/immich/postgres
DB_PASSWORD=strongpassword
DB_USERNAME=postgres
DB_DATABASE_NAME=immich

# Lidatube (links to your Lidarr instance)
LIDARR_ADDRESS=http://lidarr:8686
LIDARR_API_KEY=your_lidarr_api_key

# Navidrome
ND_LASTFM_APIKEY=your_lastfm_api_key
ND_LASTFM_SECRET=your_lastfm_secret

# Watchtower notifications (optional, e.g. ntfy/Gotify URL)
WATCHTOWER_NOTIFICATION_URL=
```

> Note: `BESZEL_TOKEN`, `BESZEL_KEY`, `SLSKD_*`, `SPOTIFY_CLIENT_*`, `SECRET_ENCRYPTION_KEY`, and `MEILI_MASTER_KEY` variables are no longer needed unless you re-enable the corresponding commented-out services (Beszel, Slskd, Navidrome Import, Homarr, Meilisearch, etc.).

---

## 🌐 Networking

Services communicate via Docker's default bridge network. A few exceptions:

- **Jellyfin** uses `network_mode: host`, so it's reachable directly on the host at port `8096` (Caddy proxies it via `172.17.0.1:8096`).
- **Cockpit** (host service, not Docker) is proxied via `172.17.0.1:9090` (Docker host gateway IP).
- **Cloudflared** is **public-access only** and runs independently of Caddy. It uses simple routing rules in the Cloudflare Tunnel dashboard to forward public internet traffic directly to individual services by port.
- **TSDProxy** provides **both local and public access** for selected services, identified via `tsdproxy.*` labels. Currently enabled for **Jellyfin** and **Navidrome** — both are reachable on your private tailnet, and because both also set `tsdproxy.funnel: true`, they're additionally published to the public internet via Tailscale Funnel. TSDProxy publishes no host port of its own and its own admin UI is only reachable through Caddy at `tsdproxy.yourdomain.com` (local access only, like the rest of the Caddy-routed subdomains).
- **Caddy** (`caddy-cloudflare`) is **local-access only** — it resolves subdomains via local DNS and is not connected to the Cloudflare Tunnel, so nothing routed through it is exposed to the public internet by Caddy itself.

---

## 🔒 TLS & Reverse Proxy (Caddy)

Caddy handles HTTPS for **local access only** using a **wildcard certificate** for `*.yourdomain.com` obtained via the Cloudflare DNS-01 ACME challenge. Your local DNS resolver (e.g. router or AdGuard) points `*.yourdomain.com` to the server's local IP, so all subdomain traffic is resolved and terminated locally by Caddy — this path is never exposed to the internet.

```
Local DNS (*.yourdomain.com → server LAN IP) → Caddy → Services   [local only]
```

The Cloudflare Tunnel runs **separately** and handles **public access only**. It's configured in the Cloudflare dashboard with simple routing rules pointing directly to services by port, and does not go through Caddy.

```
Cloudflare Tunnel → Cloudflared container → Service (by host:port)   [public only]
```

TSDProxy sits outside both of these paths and covers **both** local and public access for the handful of services it's enabled on:

```
Tailscale tailnet → TSDProxy → Service                         [local]
Tailscale Funnel (public) → TSDProxy → Service                 [public, only where tsdproxy.funnel: true]
```

Caddy loads its config from **`./Caddyfile`** and uses a reusable `(proxy)` snippet with environment variable substitution. The global options block sets Cloudflare DNS-01 (`acme_dns cloudflare`) as the default ACME resolver for the whole file, and a wildcard anchor block additionally forces explicit issuance of the `*.{$DOMAIN}` certificate:

```caddy
{
    acme_dns cloudflare {$CLOUDFLARE_API_TOKEN}
}

*.{$DOMAIN} {
    tls {
        dns cloudflare {$CLOUDFLARE_API_TOKEN}
    }
    respond 404
}
```

### Public subdomains

| Subdomain | Proxied To |
|---|---|
| `adguard.yourdomain.com` | `adguard:80` *(service commented out)* |
| `bazarr.yourdomain.com` | `bazarr:6767` |
| `beszel.yourdomain.com` | `beszel:8090` *(service commented out)* |
| `cockpit.yourdomain.com` | `172.17.0.1:9090` |
| `dash.yourdomain.com` | `dash:3001` |
| `feishin.yourdomain.com` | `feishin:9180` *(service commented out)* |
| `filebrowser.yourdomain.com` | `filebrowser:80` *(service commented out)* |
| `homepage.yourdomain.com` | `homepage:3000` *(service commented out)* |
| `immich.yourdomain.com` | `immich:2283` |
| `jellyfin.yourdomain.com` | `172.17.0.1:8096` |
| `jellystat.yourdomain.com` | `jellystat:3000` |
| `lidarr.yourdomain.com` | `lidarr:8686` |
| `lidatube.yourdomain.com` | `lidatube:5000` |
| `metube.yourdomain.com` | `metube:8081` |
| `navidrome.yourdomain.com` | `navidrome:4533` |
| `nextcloud.yourdomain.com` | `nextcloud:80` |
| `pdf.yourdomain.com` | `bentopdf:8080` |
| `portainer.yourdomain.com` | `portainer:9000` |
| `prowlarr.yourdomain.com` | `prowlarr:9696` |
| `qbittorrent.yourdomain.com` | `qbittorrent:8090` |
| `radarr.yourdomain.com` | `radarr:7878` |
| `seerr.yourdomain.com` | `seerr:5055` |
| `sharkord.yourdomain.com` | `sharkord:4991` *(service commented out; route uses `encode gzip`)* |
| `slskd.yourdomain.com` | `slskd:5030` *(service commented out)* |
| `sonarr.yourdomain.com` | `sonarr:8989` |
| `soulsync.yourdomain.com` | `soulsync:8008` *(service commented out)* |
| `speedtest.yourdomain.com` | `speedtest:80` *(service commented out)* |
| `stirling.yourdomain.com` | `stirling:8080` *(service commented out)* |
| `synapse.yourdomain.com` | `synapse:8008` *(service commented out)* |
| `tracearr.yourdomain.com` | `tracearr:3020` *(service commented out)* |
| `tsdproxy.yourdomain.com` | `tsdproxy:8080` |
| `unmanic.yourdomain.com` | `unmanic:8888` |
| `wizarr.yourdomain.com` | `wizarr:5690` *(service commented out)* |

`pdf.yourdomain.com` (BentoPDF) is routed through Caddy directly — BentoPDF exposes no host port of its own, so this Caddy route is the only way to reach it. All public-domain blocks above use `reverse_proxy` directly for clarity, rather than the `(proxy)` snippet.

### Tailscale domain (`$OLDDOMAIN`)

HTTP requests to `*.OLDDOMAIN` are redirected to HTTPS. Two services are currently proxied using manual TLS certificates managed by TSDProxy (a third, Beszel, is defined in the Caddyfile but commented out since the Beszel service itself is disabled):

| Subdomain | Proxied To |
|---|---|
| `jellyfin.OLDDOMAIN` | `172.17.0.1:8096` |
| `navidrome.OLDDOMAIN` | `navidrome:4533` |

These blocks use `import tailscale_tls <name>` and `import proxy <name>:<port>` snippets rather than a bare `reverse_proxy` directive. Certificates are read from `/mnt/docker/tsdproxy/data/default` (mounted into Caddy at `/certs`). Note that `jellyfin.OLDDOMAIN` proxies to `172.17.0.1:8096` (the host gateway IP) rather than `jellyfin:8096`, since Jellyfin runs with `network_mode: host`.

---

## 🚀 Getting Started

### Prerequisites

- Docker & Docker Compose
- A domain managed by Cloudflare
- A Cloudflare API token with `Zone:DNS:Edit` permissions
- A Cloudflare Tunnel token

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/hdenizdogan/turuserver.git
   cd turuserver/
   ```

2. **Create required directories**
   ```bash
   sudo mkdir -p /mnt/docker /mnt/media/torrent/Music /mnt/media/torrent/downloads \
     /mnt/media/torrent/staging /mnt/immichdata /mnt/nextclouddata
   ```

3. **Create the `.env` file** (see [Environment Variables](#️-environment-variables) above)

4. **Create the Cloudflare Tunnel** in the Cloudflare dashboard and copy the tunnel token to `.env`

5. **Start the stack**
   ```bash
   docker compose up -d --remove-orphans
   ```

---

## 🔧 Service Details

### Jellyfin
Media server with hardware transcoding via `/dev/dri` (Intel QSV / VAAPI). Runs with `network_mode: host` so Caddy can proxy it at `172.17.0.1:8096`. Also accessible over Tailscale via `jellyfin.OLDDOMAIN` and publicly exposed through TSDProxy's Tailscale Funnel (`tsdproxy.funnel: true`).

### Jellystat
Statistics and history dashboard for Jellyfin. Requires a dedicated PostgreSQL 15 database (`jellystat-db`). No longer exposes a host port directly — access via reverse proxy.

### Sonarr / Radarr / Lidarr / Bazarr / Prowlarr
The standard *arr stack for automated media management. All share `/mnt/media/torrent` as the download path for seamless hardlinking.

### qBittorrent
Torrent client with web UI configured via `WEBUI_PORT=8090`. Host port publishing is currently disabled (commented out) — access via reverse proxy only.

### Seerr
Media request and discovery tool. Connects to Jellyfin and the *arr stack.

### Lidatube
Downloads music from YouTube and imports to Lidarr automatically (`attempt_lidarr_import=True`), using `LIDARR_ADDRESS` and `LIDARR_API_KEY` to talk to the Lidarr container.

### Metube
Web UI for downloading videos/audio via yt-dlp. Uses a `tmpfs` mount for `/downloads`; no host port is currently published.

### Navidrome
Self-hosted music streaming server with Last.fm scrobbling support. Also accessible over Tailscale via `navidrome.OLDDOMAIN` and publicly exposed through TSDProxy's Tailscale Funnel (`tsdproxy.funnel: true`).

### Nextcloud
Self-hosted cloud storage using SQLite (no separate database container). User data is stored at `/mnt/nextclouddata`.

### Unmanic
File transcoding pipeline with hardware acceleration support via `/dev/dri`.

### BentoPDF
Self-hosted PDF toolkit (`bentopdf-simple` build). Publishes no host port of its own; reachable via Caddy at `pdf.yourdomain.com → bentopdf:8080`.

### Immich
Self-hosted photo and video backup. Uses:
- **OpenVINO** for ML hardware acceleration (see `hwaccel.ml.yml`)
- **VectorChord** PostgreSQL image for efficient vector search
- **Valkey** (Redis fork) for caching

### Portainer
Docker management UI. Mounts the Docker socket for full container control.

### Dashdot
Real-time server stats dashboard. Runs privileged with the host filesystem mounted read-only for accurate disk/network metrics. Displays OS, CPU, storage, RAM, and network with temperatures and percentages enabled.

### Flaresolverr
Cloudflare bypass proxy used by Prowlarr to access protected torrent indexers.

### TSDProxy
Tailscale reverse proxy that automatically exposes selected containers (currently Jellyfin and Navidrome, both with public Tailscale Funnel enabled) as Tailscale nodes. Also provides the TLS certificates used by Caddy for the `$OLDDOMAIN` routes. Publishes no host port; reachable via Caddy at `tsdproxy.yourdomain.com`.

### Watchtower
Automatically updates all containers daily at 04:00. Configured with:
- `--cleanup` — removes old images after update
- `--no-startup-message` — suppresses the initial notification
- `--include-restarting` — also updates containers that are restarting

### Cloudflared
Runs the Cloudflare Tunnel client. Routing rules are configured in the Cloudflare dashboard and point directly to services by host and port — independent of Caddy.

### Caddy
Local reverse proxy with automatic wildcard TLS via Cloudflare DNS-01, using the `caddy-cloudflare` image (Caddy built with the Cloudflare DNS plugin). Config is loaded from `./Caddyfile`. Resolves subdomains via local DNS — not connected to the Cloudflare Tunnel. TSDProxy certificates are mounted read-only for the `$OLDDOMAIN` Tailscale routes.

---

## 🛠️ Useful Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs for a specific service
docker compose logs -f sonarr

# Pull latest images and recreate containers
docker compose pull && docker compose up -d --remove-orphans
```

---

## 📝 Notes

- **Beszel** and **Beszel Agent** (monitoring hub + host metrics agent) are currently **commented out** in `docker-compose.yml`. The Caddyfile still carries route definitions for `beszel.yourdomain.com` and a (commented-out) `beszel.OLDDOMAIN` Tailscale block, so re-enabling the service just requires uncommenting the compose block and its `beszel.OLDDOMAIN` Caddy block.
- The following services are also currently **commented out** in `docker-compose.yml` and can be re-enabled as needed: AdGuard, Filebrowser, Homepage, Speedtest, Wizarr, Tracearr (+ its Timescale/TimescaleDB and Redis backends), Glances, Home Assistant, Homarr, Meilisearch, tdarr, standalone Caddy, NPM (Nginx Proxy Manager), plain Nginx, Profilarr, Tailscale, Feishin, Navidrome import tool, Sharkord, Synapse, **Slskd**, and **Soulsync**. The Caddyfile still carries route definitions for most of these (adguard, feishin, filebrowser, homepage, sharkord, slskd, soulsync, speedtest, stirling, synapse, tracearr, wizarr), so they'll 404/fail to connect until the corresponding compose service is uncommented.
- **Sharkord** and **Synapse** are new Caddyfile entries with no corresponding active compose service yet; the `sharkord.yourdomain.com` route also enables `encode gzip`.
- **Cockpit** (Ubuntu server web UI) is proxied through Caddy at `cockpit.yourdomain.com → 172.17.0.1:9090`. Make sure Cockpit allows the tunnel domain in `/etc/cockpit/cockpit.conf`.
- **Watchtower** is pinned to `nickfedor/watchtower` (a maintained fork of `containrrr/watchtower`).
- The `(proxy)` snippet in the Caddyfile is used via `import proxy` in the Tailscale-domain (`$OLDDOMAIN`) blocks; the public-domain blocks use `reverse_proxy` directly for clarity instead.
- The Caddyfile path is **`./Caddyfile`**, matching the volume mount on the `caddy-cloudflare` service.
- Caddy does not hot-reload the Caddyfile on its own — after editing it, run `docker exec caddy-cloudflare caddy reload --config /etc/caddy/Caddyfile` (see [Caddy](#caddy) above) instead of restarting the container.