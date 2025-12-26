# Traefik (Default Configuration)

Reverse proxy with automatic HTTPS via Cloudflare DNS challenge.

## Requires

- `infrastructure-networks-default` (install first)

## Ports

| Port | Purpose |
|------|---------|
| 80 | HTTP (redirects to HTTPS) |
| 443 | HTTPS |
| 1883 | MQTT |
| 8883 | MQTT over TLS |

## Environment Variables

Copy `.env.example` to `.env` and configure:

- `ACME_EMAIL` - Email for Let's Encrypt certificate registration
- `CF_DNS_API_TOKEN` - Cloudflare API token with DNS edit permissions
  - Create at: Cloudflare Dashboard → Profile → API Tokens
  - Use template: "Edit zone DNS" and select your zones

## Usage

Services connect by joining the `infra-public` network and adding labels.
No need to expose ports to host - Traefik handles all external traffic.

```yaml
services:
  myapp:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`app.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
    networks:
      - infra-public

networks:
  infra-public:
    external: true
```

## MQTT Services

For MQTT services (like Mosquitto):

```yaml
services:
  mosquitto:
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.mqtt.rule=HostSNI(`*`)"
      - "traefik.tcp.routers.mqtt.entrypoints=mqtt"
      - "traefik.tcp.services.mqtt.loadbalancer.server.port=1883"
    networks:
      - infra-public

networks:
  infra-public:
    external: true
```
