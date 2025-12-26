# Shared Networks

Creates shared Docker networks for all services.

## Networks

| Network | Purpose | External Access |
|---------|---------|-----------------|
| `infra-public` | Services exposed via Traefik | Yes (via Traefik) |
| `infra-private` | Internal service communication | No (internal only) |

## Usage

Services should use these as external networks:

```yaml
services:
  myapp:
    networks:
      - infra-public   # If needs to be accessed via Traefik
      - infra-private  # For internal communication

networks:
  infra-public:
    external: true
  infra-private:
    external: true
```

## Install First

This must be installed before any other infrastructure or services.
