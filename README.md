# Composable

Registry of docker-compose configurations for infrastructure and services.

## Structure

```
composable/
├── registry.json              # Index of all available stacks
├── infrastructure/            # Core infrastructure services
│   ├── networks/default/      # Shared Docker networks (install first)
│   ├── traefik/default/       # Reverse proxy with auto HTTPS
│   └── ...
└── services/                  # Application services
    └── ...
```

## Networks

All services use shared networks to avoid exposing ports to host:

| Network | Purpose |
|---------|---------|
| `infra-public` | Services exposed via Traefik |
| `infra-private` | Internal service communication (no external access) |

## Installation Order

1. `infrastructure-networks-default` - Creates shared networks
2. `infrastructure-traefik-default` - Reverse proxy (requires networks)
3. Other services...

## Usage with infra-cli

```bash
# List available infrastructure
infra registry list infrastructure

# Install a service
infra registry install infrastructure-traefik-default

# Disable a service (stops and renames compose file)
infra registry disable infrastructure-traefik-default
```

## Contributing

1. Create a directory under `infrastructure/` or `services/`
2. Add `docker-compose.yml` with `name:` field matching directory path
3. Add `README.md` and `.env.example`
4. Submit a PR - the workflow validates naming and updates registry.json

### Naming Convention

The `name:` field in docker-compose.yml must match the directory path:
- `infrastructure/traefik/default/` → `name: infrastructure-traefik-default`
- `services/n8n/production/` → `name: services-n8n-production`
