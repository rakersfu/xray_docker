# xray_docker

Lightweight Docker setup for Xray (XTLS/Xray-core) with ready-to-use entrypoint scripts for common configurations (WS+TLS and XHTTP+Reality). This repository provides a minimal Alpine-based Dockerfile, two entrypoint scripts that generate runtime config.json dynamically, and a sample docker-compose.yml for quick deployment.

## What this is

A simple containerized Xray runtime that downloads the Xray-core binary, generates configuration from environment variables at container start, and runs Xray. It targets users who want an easy way to run Xray in Docker with either WebSocket+TLS (entrypoint.sh) or XHTTP+Reality (entrypoint_new.sh).

## Contents

- Dockerfile - builds the image from alpine, downloads Xray-core, and installs an entrypoint.
- entrypoint.sh - generates a config.json for WS+TLS inbound (vless over ws+tls). Use when you have TLS certs and want WS transport.
- entrypoint_new.sh - generates a config.json for XHTTP and Reality transports (XHTTP inbound + vless-reality inbound). It also generates X25519 keys and prints vless:// links.
- docker-compose.yml - example compose service for running the image.
- .github/workflows/push_to_dockerhub.yml - GitHub Actions workflow (push image to Docker Hub).

## How it works (runtime)

At container start the image runs the entrypoint script (installed at /usr/local/bin/entrypoint.sh). The entrypoint script reads environment variables, generates an appropriate `config.json` inside `/app`, prints connection links (entrypoint_new.sh), and then execs the container CMD (the Xray binary):

- Dockerfile ENTRYPOINT: `/usr/local/bin/entrypoint.sh`
- Dockerfile CMD: `./xray run -config config.json`

The Dockerfile copies `entrypoint_new.sh` to `/usr/local/bin/entrypoint.sh` by default; `entrypoint.sh` in the repo provides an alternate WS+TLS configuration example.

## Build locally

Build the Docker image locally (replace the tag as desired):

```bash
# From repository root
docker build -t xray-local:latest .
```

Run the container (example using entrypoint_new.sh behavior):

```bash
docker run -d \
  --name xray \
  -p 443:443 \
  -p 2779:2779 \
  -v $(pwd)/logs:/var/log/xray \
  -e HOST=127.0.0.1 \
  -e DOMAIN=www.mysql.com \
  -e UUID= \
  xray-local:latest
```

The entrypoint will generate a `config.json` at `/app/config.json` and then exec the default CMD to start Xray.

## Using docker-compose

The included `docker-compose.yml` references the image `xiongli870110/xray:1.0.2`. To use your locally built image, modify the compose file's `image` line to reference `xray-local:latest` or build inside compose.

Start with:

```bash
docker compose up -d
```

## Environment variables

The entrypoints generate configs from environment variables. Key variables used by `entrypoint_new.sh` (XHTTP + Reality):

- UUID - client UUID; if empty the script will call `./xray uuid` to generate one
- PORT - Reality/TLS listening port (default: 443)
- XHTTPPORT - XHTTP listening port (default: 2779)
- DESTHOST - destination host/port for reality `dest` (default: 443)
- SHORTIDS - reality `shortIds` array (default: `b477209778`)
- HOST - host used in generated connection links and XHTTP host header (default: `127.0.0.1`)
- XHTTP_PATH - xhttp path (defaults to the value of UUID)
- LISTEN_ADDR - address to bind listen sockets (default: `0.0.0.0`)
- LOG_LEVEL - Xray log level (default: `info`)
- DOMAIN - fake domain used for SNI/serverNames in Reality
- CERT_FILE, KEY_FILE - (provided for TLS-based entrypoint) cert/key paths if you use `entrypoint.sh` (WS+TLS)

Notes:
- The entrypoint scripts print out vless:// links to the container logs so you can copy them after start (entrypoint_new.sh prints an XHTTP and a Reality link).
- `entrypoint.sh` (WS+TLS) expects TLS cert and key mounted into the container (defaults: `/etc/ssl/cert.pem` and `/etc/ssl/key.pem`).

## Ports

- 443 - used by Reality/TLS inbound in both scripts by default
- 2779 - example XHTTP inbound port used by entrypoint_new.sh

Adjust these with environment variables or Docker port mappings.

## Volumes

- /var/log/xray (container) -> recommended to mount a host directory (example `./logs`) with write permissions so Xray can write logs if configured.
- If using `entrypoint.sh` (WS+TLS) and TLS certs, mount certs into `/etc/ssl/cert.pem` and `/etc/ssl/key.pem` as specified by the compose file.

## Security & Notes

- The repository's scripts generate and print private keys and passwords (entrypoint_new.sh). Treat container logs as sensitive.
- Reality transport uses generated X25519 private key and a shortid list. Make sure your usage complies with your threat model and platform policies.
- If exposing ports on public hosts, secure the host and firewall appropriately.

## Differences between entrypoint scripts

- entrypoint.sh: Generates a `config.json` that configures a single vless inbound over WebSocket + TLS. Expects mounted TLS certs and is suitable when you control certificate files.
- entrypoint_new.sh: Generates a `config.json` with two inbounds: an XHTTP vless inbound (no security) and a vless-reality inbound (security: reality). It calls `./xray x25519` to generate reality keys and prints connection links. This script is copied into the image by default.

## Troubleshooting

- If the container exits immediately, check container logs:

```bash
docker logs xray
```

- If `./xray` is not found or permission denied, ensure the Dockerfile fetched Xray and moved the binary to `/app/xray` and that the binary has execute permissions.

## Contributing

Contributions are welcome: open issues or PRs for improvements. If you change the entrypoint behavior or default ports, update the README accordingly.

## License

No license file is included in this repository. If you intend to reuse or distribute this, add an appropriate LICENSE file.
