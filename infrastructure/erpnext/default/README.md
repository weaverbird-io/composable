# ERPNext

Open-source ERP system built on the Frappe framework with HR, Helpdesk, and Inventory modules.

## Included Modules

- **ERPNext Core** - Accounting, CRM, Projects, Stock/Inventory, Manufacturing
- **HRMS** - Human Resources, Payroll, Attendance, Leave Management
- **Helpdesk** - Support Tickets, SLA Management, Customer Portal
- **Kenya Compliance** - KRA eTIMS integration for tax compliance

## Quick Start (Basic Setup)

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
   ./setup.sh
   ```

4. Access ERPNext at `https://your-domain.com`
   - Username: `Administrator`
   - Password: (from .env ADMIN_PASSWORD)

## Full Setup with HRMS + Helpdesk

The default `frappe/erpnext` image only includes core ERPNext. To add HRMS and Helpdesk:

### Option 1: Build Custom Image (Recommended)

```bash
# 1. Build custom image with all apps (takes 10-20 min)
./build.sh

# 2. Update .env to use custom image
ERPNEXT_IMAGE=erpnext-custom
ERPNEXT_VERSION=v15

# 3. Restart with new image
docker compose down
docker compose up -d

# 4. Run setup if first time
./setup.sh

# 5. Install the apps on your site
./configure-modules.sh
```

### Option 2: Use Pre-built Image

If you have a registry with pre-built images:

```bash
# Update .env
ERPNEXT_IMAGE=your-registry.com/erpnext-custom
ERPNEXT_VERSION=v15

# Restart
docker compose down
docker compose up -d

# Configure modules
./configure-modules.sh
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ERPNEXT_IMAGE` | Docker image name | `frappe/erpnext` |
| `ERPNEXT_VERSION` | Image tag | `v15` |
| `SITE_DOMAIN` | Your ERPNext domain | `erp.example.com` |
| `DB_ROOT_PASSWORD` | MariaDB root password | Required |
| `ADMIN_PASSWORD` | ERPNext admin password | Required |

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Main stack definition |
| `.env.example` | Environment template |
| `apps.json` | Apps to include in custom image |
| `setup.sh` | Creates ERPNext site |
| `build.sh` | Builds custom image with HRMS/Helpdesk |
| `configure-modules.sh` | Installs apps on existing site |

## Module Setup Guides

After installation, configure modules in ERPNext:

### Stock/Inventory (Built-in)
- Go to **Stock > Stock Settings**
- Create Warehouses: **Stock > Warehouse**
- Add Items: **Stock > Item**

### HR Module
- Go to **HR > HR Settings**
- Setup: Company, Department, Designation
- Add Employees: **HR > Employee**

### Helpdesk
- Go to **Support > Support Settings**
- Configure SLA: **Support > Service Level Agreement**
- Create Issue Types: **Support > Issue Type**

### eTIMS Kenya (KRA Compliance)
- Go to **Kenya Compliance > eTIMS Settings**
- Set Environment: Sandbox (testing) or Production
- Configure your KRA credentials
- Enable auto-submission of invoices

## Maintenance Commands

```bash
# Access bench CLI
docker exec -it erpnext-backend bash

# Migrate after updates
docker exec erpnext-backend bench --site $SITE_DOMAIN migrate

# Backup
docker exec erpnext-backend bench --site $SITE_DOMAIN backup

# Update ERPNext
docker compose pull
docker compose up -d
docker exec erpnext-backend bench --site $SITE_DOMAIN migrate

# List installed apps
docker exec erpnext-backend bench --site $SITE_DOMAIN list-apps
```

## Volumes

- `db-data` - MariaDB database files
- `sites` - ERPNext sites and assets
- `logs` - Application logs
- `redis-*-data` - Redis persistence
