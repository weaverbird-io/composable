# ERPNext

Open-source ERP system built on the Frappe framework.

## Components

- **ERPNext v15** - Full-featured ERP with accounting, HR, manufacturing, etc.
- **MariaDB 10.6** - Database backend
- **Redis** - Caching and job queue
- **Nginx** - Web frontend (via frappe image)

## Quick Start

1. Copy environment file and configure:
   ```bash
   cp .env.example .env
   # Edit .env with your domain and passwords
   ```

2. Start the stack:
   ```bash
   docker compose up -d
   ```

3. Create the ERPNext site:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

4. Access ERPNext at `https://your-domain.com`
   - Username: `Administrator`
   - Password: (from .env ADMIN_PASSWORD)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ERPNEXT_VERSION` | ERPNext Docker image version | `v15` |
| `SITE_NAME` | Your ERPNext domain | `erp.example.com` |
| `DB_ROOT_PASSWORD` | MariaDB root password | Required |
| `ADMIN_PASSWORD` | ERPNext admin password | Required |

## Traefik Integration

The frontend service includes Traefik labels for automatic HTTPS. Ensure:
- DNS points to your server
- Traefik is running with the `infra` network
- Certificate resolver `letsencrypt` is configured

## Maintenance Commands

```bash
# Access bench CLI
docker exec -it erpnext-backend bash

# Migrate after updates
docker exec erpnext-backend bench --site your-site migrate

# Backup
docker exec erpnext-backend bench --site your-site backup

# Update ERPNext
docker compose pull
docker compose up -d
docker exec erpnext-backend bench --site your-site migrate
```

## Volumes

- `db-data` - MariaDB database files
- `sites` - ERPNext sites and assets
- `logs` - Application logs
- `redis-*-data` - Redis persistence
