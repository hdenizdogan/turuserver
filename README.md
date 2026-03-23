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
| [Unmanic](#unmanic) | Media transcoding pipeline | `8888` |
| [Stirling PDF](#stirling-pdf) | PDF tools | `5050` |
| [Immich](#immich) | Photo/video backup | `2283` |
| [Portainer](#portainer) | Docker management UI | `9000` |
| [Dashdot](#dashdot) | Server stats dashboard | `3001` |
| [Watchtower](#watchtower) | Automatic container updates | — |
| [Cloudflared](#cloudflared) | Cloudflare Tunnel | — |
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
│   ├── immich/
│   ├── portainer_data/
│   ├── StirlingPDF/
│   ├── redis/
│   └── caddy-cloudflare/
└── media/                  # Media library
    ├── torrent/            # Download directory
    │   └── Music/
    ├── Shows/
    └── Movies/
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
OLDDOMAIN=youroldomain.com   # optional, for redirects

# Jellystat DB
JELLYSTATDB_POSTGRES_USER=jellystat
JELLYSTATDB_POSTGRES_PASSWORD=strongpassword
JELLYSTATDB_POSTGRES_IP=jellystat-db
JELLYSTATDB_POSTGRES_PORT=5432
JELLYSTAT_JWT_SECRET=your_jwt_secret

# Immich
IMMICH_VERSION=release
UPLOAD_LOCATION=/mnt/docker/immich/photos
DB_DATA_LOCATION=/mnt/docker/immich/postgres
DB_PASSWORD=strongpassword
DB_USERNAME=postgres
DB_DATABASE_NAME=immich

# Watchtower notifications (optional, e.g. ntfy/Gotify URL)
WATCHTOWER_NOTIFICATION_URL=

# Homarr (if enabled)
SECRET_ENCRYPTION_KEY=
```

---

## 🌐 Networking

All services (except Jellyfin and Cockpit) communicate over a custom bridge network `local_net` with subnet `172.19.0.0/24`.

- **Caddy** is assigned a static IP of `172.19.0.199` within this network.
- **Jellyfin** uses `network_mode: host` for better hardware passthrough and DLNA support.
- **Cockpit** (host service, not Docker) is proxied via `172.17.0.1:9090` (Docker host gateway IP).
- **Cloudflared** runs with 2 replicas for redundancy and routes traffic through the Cloudflare Tunnel to Caddy.

---

## 🔒 TLS & Reverse Proxy (Caddy)

Caddy handles HTTPS using a **wildcard certificate** for `*.yourdomain.com` obtained via the Cloudflare DNS-01 ACME challenge. No ports need to be exposed to the internet.

```
Cloudflare DNS → Cloudflare Tunnel → Cloudflared container → Caddy → Services
```

The Caddyfile uses environment variable substitution:

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

Each service gets a subdomain:

| Subdomain | Proxied To |
|---|---|
| `jellyfin.yourdomain.com` | `172.17.0.1:8096` |
| `cockpit.yourdomain.com` | `172.17.0.1:9090` |
| `sonarr.yourdomain.com` | `sonarr:8989` |
| `radarr.yourdomain.com` | `radarr:7878` |
| `bazarr.yourdomain.com` | `bazarr:6767` |
| `lidarr.yourdomain.com` | `lidarr:8686` |
| `prowlarr.yourdomain.com` | `prowlarr:9696` |
| `qbittorrent.yourdomain.com` | `qbittorrent:8090` |
| `seerr.yourdomain.com` | `seerr:5055` |
| `jellystat.yourdomain.com` | `jellystat:3000` |
| `lidatube.yourdomain.com` | `lidatube:5000` |
| `unmanic.yourdomain.com` | `unmanic:8888` |
| `portainer.yourdomain.com` | `portainer:9000` |
| `dash.yourdomain.com` | `dash:3001` |
| `stirling.yourdomain.com` | `stirling:8080` |
| `immich.yourdomain.com` | `immich:2283` |

> **Note:** `adguard`, `homepage`, `speedtest`, and `wizarr` entries are present in the Caddyfile but their corresponding Docker services are currently commented out.

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
   sudo mkdir -p /mnt/docker /mnt/media/torrent/Music /mnt/media/Shows /mnt/media/Movies
   ```

3. **Create the `.env` file** (see [Environment Variables](#️-environment-variables) above)

4. **Create the Cloudflare Tunnel** in the Cloudflare dashboard and copy the tunnel token to `.env`

5. **Start the stack**
   ```bash
   docker compose up -d
   ```

6. **Configure the Cloudflare Tunnel** to route traffic to `http://caddy-cloudflare:80` (or `http://localhost:80` if using host networking)

---

## 🔧 Service Details

### Jellyfin
Media server with hardware transcoding support via `/dev/dri` (Intel QSV / VAAPI). Uses `network_mode: host` for DLNA and direct play support.

### Jellystat
Statistics and history dashboard for Jellyfin. Requires a dedicated PostgreSQL database (`jellystat-db`).

### Sonarr / Radarr / Lidarr / Bazarr / Prowlarr
The standard *arr stack for automated media management. All share `/mnt/media/torrent` as the download path for seamless hardlinking.

### qBittorrent
Torrent client with web UI on port `8090`. Web UI port is explicitly set via `WEBUI_PORT=8090`.

### Seerr
Media request and discovery tool (Overseerr fork). Connects to Jellyfin and the *arr stack.

### Lidatube
Downloads music from YouTube and imports to Lidarr automatically (`attempt_lidarr_import=True`).

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
Real-time server stats dashboard. Runs privileged with host filesystem mounted read-only for accurate disk/network metrics.

### Watchtower
Automatically updates all containers daily at 04:00. Configured with:
- `--cleanup` — removes old images after update
- `--no-startup-message` — suppresses the initial notification
- `--include-restarting` — also updates containers that are restarting

### Cloudflared
Runs the Cloudflare Tunnel client with **2 replicas** for high availability. All inbound traffic is routed through this to Caddy.

### Caddy
Reverse proxy with automatic TLS. Uses the `caddy-cloudflare` image (Caddy built with the Cloudflare DNS plugin). Mounts a read-only `Caddyfile` and persists certificate data under `/mnt/docker/caddy-cloudflare/`.

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

- Several services are **commented out** in `docker-compose.yml` (Navidrome, Glances, Homepage, AdGuard, Homarr, Wizarr, Filebrowser, Metube, Speedtest, tdarr, Jellysweep, NPM, Home Assistant, tsdproxy). They can be enabled by uncommenting.
- Cockpit (Ubuntu server web UI) is proxied through Caddy at `cockpit.yourdomain.com` → `172.17.0.1:9090`. Make sure Cockpit is configured to allow the tunnel domain in `/etc/cockpit/cockpit.conf`.
- Watchtower is pinned to `nickfedor/watchtower` (a maintained fork of the original `containrrr/watchtower`).