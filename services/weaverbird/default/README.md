# WeaverBird Services Stack

Application and gateway services for WeaverBird.

Includes:
- nginx (public entrypoint through existing Traefik)
- auth-service
- auth-frontend
- rebac-service
- audit-service
- notification-service
- credential-service
- storage-service
- webhook-relay

## Usage

```bash
cp .env.example .env
docker compose up -d
```

This stack expects `infrastructure/weaverbird-infra/default` to be running first.
No service in this stack is exposed directly to host ports.
