# WeaverBird Infra Stack

Internal infrastructure services for WeaverBird. This stack is intentionally internal-only (no host ports published).

Includes:
- PostgreSQL
- SpiceDB (+ migration + schema loader)
- Redis
- RabbitMQ
- Vault
- Mailpit
- SeaweedFS (master, volume, filer)

## Usage

```bash
cp .env.example .env
docker compose up -d
```
