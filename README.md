# 🏠 Home Media Server Stack

A self-hosted media server stack running on Docker, with Caddy as a reverse proxy using Cloudflare DNS challenge for wildcard TLS certificates, and Cloudflare Tunnel for secure public access.

---

## 📦 Stack Overview

| Service | Description | Port |
|---|---|---|
| [Jellyfin](#jellyfin) | Media server (movies, shows, music) | `8096` |
| [Jellystat](#jellystat) | Jellyfin statistics dashboard | `3000` |
| [Sonarr](#sonarr) | TV show management | `8989` |
| [Radarr](#radarr) | Movie management | `7878` |
| [Lidarr](#lidarr) | Music management | `8686` |
| [Bazarr](#bazarr) | Subtitle management | `6767` |
| [Prowlarr](#prowlarr) | Indexer manager | `9696` |
| [qBittorrent](#qbittorrent) | Torrent client | `8090` |
| [Seerr](#seerr) | Media request manager | `5055` |
| [Lidatube](#lidatube) | YouTube → Lidarr downloader | `5000` |
| [Metube](#metube) | YouTube downloader UI | `8081` |
| [Navidrome](#navidrome) | Music streaming server | `4533` |
| [Nextcloud](#nextcloud) | Self-hosted cloud storage | `8083` |
| [Slskd](#slskd) | Soulseek client | `5030` |
| [Soulsync](#soulsync) | Music sync automation | `8008` |
| [Unmanic](#unmanic) | Media transcoding pipeline | `8888` |
| [Stirling PDF](#stirling-pdf) | PDF tools | `5050` |
| [Immich](#immich) | Photo/video backup | `2283` |
| [Portainer](#portainer) | Docker management UI | `9000` |
| [Dashdot](#dashdot) | Server stats dashboard | `3001` |
| [Flaresolverr](#flaresolverr) | Cloudflare bypass for indexers | `8191` |
| [Watchtower](#watchtower) | Automatic container updates | — |
| [Cloudflared](#cloudflared) | Cloudflare Tunnel | — |
| [TSDProxy](#tsdproxy) | Tailscale reverse proxy | — |
| [Caddy](#caddy) | Reverse proxy with TLS | `80`, `443` |

---

## 🗂️ Directory Structure

```
.
├── docker-compose.yml
├── Caddyfile
├── hwaccel.ml.yml          # Immich hardware acceleration config
└── .env                    # Environment variables (see below)
```

Media and config are stored on the host:

```
/mnt/
├── docker/                 # Container config/data volumes
│   ├── jellyfin_config/
│   ├── jellyfin_cache/
│   ├── sonarr/
│   ├── radarr/
│   ├── lidarr/
│   ├── bazarr/
│   ├── prowlarr/
│   ├── qbittorrent/
│   ├── seerr/
│   ├── jellystat/
│   ├── lidatube/
│   ├── navidrome/
│   ├── nextcloud/
│   ├── slskd/
│   ├── soulsync/
│   ├── immich/
│   ├── portainer_data/
│   ├── StirlingPDF/
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

# Navidrome
ND_LASTFM_APIKEY=your_lastfm_api_key
ND_LASTFM_SECRET=your_lastfm_secret

# Slskd
SLSKD_API_KEY=your_api_key
SLSKD_SLSK_USERNAME=your_soulseek_username
SLSKD_SLSK_PASSWORD=your_soulseek_password

# Watchtower notifications (optional, e.g. ntfy/Gotify URL)
WATCHTOWER_NOTIFICATION_URL=
```

---

## 🌐 Networking

Services communicate via Docker's default bridge network. A few exceptions:

- **Jellyfin** exposes its port on the host (`172.17.0.1:8096`) so Caddy can proxy it.
- **Cockpit** (host service, not Docker) is proxied via `172.17.0.1:9090` (Docker host gateway IP).
- **Cloudflared** routes all inbound public traffic through the Cloudflare Tunnel to Caddy.
- **TSDProxy** handles Tailscale-based access for selected services (currently Jellyfin and Navidrome via the `$OLDDOMAIN` TLS setup).

---

## 🔒 TLS & Reverse Proxy (Caddy)

Caddy handles HTTPS using a **wildcard certificate** for `*.yourdomain.com` obtained via the Cloudflare DNS-01 ACME challenge. No ports need to be exposed directly to the internet.

```
Cloudflare DNS → Cloudflare Tunnel → Cloudflared container → Caddy → Services
```

The Caddyfile uses a reusable `(proxy)` snippet and environment variable substitution. A wildcard anchor block forces issuance of the wildcard certificate:

```caddy
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
| `cockpit.yourdomain.com` | `172.17.0.1:9090` |
| `dash.yourdomain.com` | `dash:3001` |
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
| `portainer.yourdomain.com` | `portainer:9000` |
| `prowlarr.yourdomain.com` | `prowlarr:9696` |
| `qbittorrent.yourdomain.com` | `qbittorrent:8090` |
| `radarr.yourdomain.com` | `radarr:7878` |
| `seerr.yourdomain.com` | `seerr:5055` |
| `slskd.yourdomain.com` | `slskd:5030` |
| `sonarr.yourdomain.com` | `sonarr:8989` |
| `soulsync.yourdomain.com` | `soulsync:8008` |
| `speedtest.yourdomain.com` | `speedtest:80` *(service commented out)* |
| `stirling.yourdomain.com` | `stirling:8080` |
| `tracearr.yourdomain.com` | `tracearr:3020` *(service commented out)* |
| `tsdproxy.yourdomain.com` | `tsdproxy:8080` |
| `unmanic.yourdomain.com` | `unmanic:8888` |
| `wizarr.yourdomain.com` | `wizarr:5690` *(service commented out)* |

### Tailscale domain (`$OLDDOMAIN`)

HTTP requests to `*.OLDDOMAIN` are redirected to HTTPS. Two services are proxied using manual TLS certificates managed by TSDProxy:

| Subdomain | Proxied To |
|---|---|
| `jellyfin.OLDDOMAIN` | `jellyfin:8096` |
| `navidrome.OLDDOMAIN` | `navidrome:4533` |

Certificates are read from `/mnt/docker/tsdproxy/data/default` (mounted into Caddy at `/certs`).

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
   git clone https://github.com/yourusername/yourrepo.git
   cd yourrepo
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
   docker compose up -d
   ```

6. **Configure the Cloudflare Tunnel** to route traffic to `http://caddy-cloudflare:80`

---

## 🔧 Service Details

### Jellyfin
Media server with hardware transcoding via `/dev/dri` (Intel QSV / VAAPI). Port `8096` is exposed on the host so Caddy can proxy it at `172.17.0.1:8096`. Also accessible over Tailscale via `jellyfin.OLDDOMAIN`.

### Jellystat
Statistics and history dashboard for Jellyfin. Requires a dedicated PostgreSQL 15 database (`jellystat-db`).

### Sonarr / Radarr / Lidarr / Bazarr / Prowlarr
The standard *arr stack for automated media management. All share `/mnt/media/torrent` as the download path for seamless hardlinking.

### qBittorrent
Torrent client with web UI on port `8090`. Web UI port is explicitly set via `WEBUI_PORT=8090`.

### Seerr
Media request and discovery tool (Overseerr fork). Connects to Jellyfin and the *arr stack.

### Lidatube
Downloads music from YouTube and imports to Lidarr automatically (`attempt_lidarr_import=True`).

### Metube
Web UI for downloading videos/audio via yt-dlp.

### Navidrome
Self-hosted music streaming server with Last.fm scrobbling support. Also accessible over Tailscale via `navidrome.OLDDOMAIN`.

### Nextcloud
Self-hosted cloud storage using SQLite (no separate database container). User data is stored at `/mnt/nextclouddata`.

### Slskd
Web-based Soulseek client for peer-to-peer music sharing. Remote configuration is enabled.

### Soulsync
Music sync automation tool. Bridges Spotify/Tidal playlists with Soulseek downloads and Lidarr imports. CPU and memory usage is constrained via `deploy.resources`.

### Flaresolverr
Cloudflare bypass proxy used by Prowlarr to access protected torrent indexers.

### Unmanic
File transcoding pipeline with hardware acceleration support via `/dev/dri`.

### Stirling PDF
Full-featured PDF toolkit. Configured with Turkish language support (`LANGS=["tr_TR"]`). Accessible on host port `5050`.

### Immich
Self-hosted photo and video backup. Uses:
- **OpenVINO** for ML hardware acceleration (see `hwaccel.ml.yml`)
- **VectorChord** PostgreSQL image for efficient vector search
- **Valkey** (Redis fork) for caching

### Portainer
Docker management UI. Mounts the Docker socket for full container control.

### Dashdot
Real-time server stats dashboard. Runs privileged with the host filesystem mounted read-only for accurate disk/network metrics. Displays OS, CPU, storage, RAM, and network with temperatures and percentages enabled.

### TSDProxy
Tailscale reverse proxy that automatically exposes selected containers (currently Jellyfin and Navidrome) as Tailscale nodes. Provides the TLS certificates used by Caddy for the `$OLDDOMAIN` routes.

### Watchtower
Automatically updates all containers daily at 04:00. Configured with:
- `--cleanup` — removes old images after update
- `--no-startup-message` — suppresses the initial notification
- `--include-restarting` — also updates containers that are restarting

### Cloudflared
Runs the Cloudflare Tunnel client, routing all inbound public traffic to Caddy.

### Caddy
Reverse proxy with automatic wildcard TLS via Cloudflare DNS-01. Uses the `caddy-cloudflare` image (Caddy built with the Cloudflare DNS plugin). TSDProxy certificates are mounted read-only for the `$OLDDOMAIN` Tailscale routes.

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
docker compose pull && docker compose up -d

# Restart a single service
docker compose restart jellyfin

# Check running containers
docker compose ps
```

---

## 📝 Notes

- Several services are **commented out** in `docker-compose.yml` and have Caddyfile entries ready for when they're re-enabled: AdGuard, Filebrowser, Homepage, Speedtest, Wizarr, Tracearr, Glances, Home Assistant, Homarr, tdarr, NPM, Tailscale, Feishin, and the Navidrome import tool.
- **Cockpit** (Ubuntu server web UI) is proxied through Caddy at `cockpit.yourdomain.com → 172.17.0.1:9090`. Make sure Cockpit allows the tunnel domain in `/etc/cockpit/cockpit.conf`.
- **Watchtower** is pinned to `nickfedor/watchtower` (a maintained fork of `containrrr/watchtower`).
- The `(proxy)` snippet in the Caddyfile is defined for convenience but each service block uses `reverse_proxy` directly for clarity.
