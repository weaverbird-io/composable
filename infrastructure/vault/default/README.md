# Vault

HashiCorp Vault for secrets management with multi-tenant support.

## Quick Start

1. Install via infra-cli
2. Initialize Vault: `docker exec -it vault vault operator init`
3. Save the unseal keys and root token securely
4. Unseal: `docker exec -it vault vault operator unseal` (run 3 times with different keys)

## Multi-Tenant Setup

This Vault is configured for multi-tenant use with Google OIDC authentication. Each organization gets isolated secrets and only authorized users can access them.

### Architecture

```
Vault
├── Auth: OIDC (Google)
├── Organizations (secrets engines):
│   ├── org-a/       → org-a-org group → users 1, 2, 3
│   ├── org-b/       → org-b-org group → users 4, 5
│   └── org-c/       → org-c-org group → users 1, 6 (user 1 in multiple orgs)
└── Identity:
    ├── Entities (one per user email)
    ├── Entity Aliases (link OIDC login to entity)
    └── Groups (one per org, assigns policies)
```

### Initial Setup (One-time)

#### 1. Configure Google OIDC

Create OAuth credentials in Google Cloud Console:
- Go to APIs & Services → Credentials
- Create OAuth client ID (Web application)
- Add redirect URIs:
  - `https://<vault-domain>/ui/vault/auth/oidc/oidc/callback`
  - `https://<vault-domain>/oidc/callback`

Enable and configure OIDC in Vault:

```bash
export VAULT_TOKEN="<root-token>"

# Enable OIDC
vault auth enable oidc

# Configure with Google
vault write auth/oidc/config \
  oidc_discovery_url="https://accounts.google.com" \
  oidc_client_id="<client-id>.apps.googleusercontent.com" \
  oidc_client_secret="<client-secret>" \
  default_role="default-user"

# Create default role
vault write auth/oidc/role/default-user \
  bound_audiences="<client-id>.apps.googleusercontent.com" \
  allowed_redirect_uris="https://<vault-domain>/ui/vault/auth/oidc/oidc/callback" \
  allowed_redirect_uris="https://<vault-domain>/oidc/callback" \
  user_claim="email" \
  oidc_scopes="openid,email,profile" \
  policies="default"

# Make OIDC the default login method
vault auth tune -listing-visibility=unauth oidc/
```

#### 2. Get OIDC Accessor ID

```bash
vault auth list -format=json | jq -r '.["oidc/"].accessor'
# Example output: auth_oidc_xxxxxxxx
```

Save this - you'll need it when creating user entities.

### Adding a New Organization

#### 1. Create Secrets Engine

```bash
vault secrets enable -path=<org-name> -version=2 kv
```

#### 2. Create Policy

```bash
vault policy write <org-name>-admin - <<EOF
# Full access to organization secrets
path "<org-name>/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF
```

#### 3. Create Organization Group

```bash
vault write identity/group \
  name="<org-name>-org" \
  policies="<org-name>-admin"
```

Save the group ID from the output.

### Adding Users

#### 1. Create Entity for New User

```bash
OIDC_ACCESSOR="auth_oidc_xxxxxxxx"  # from step 2 above

# Create entity
vault write -format=json identity/entity \
  name="<user-email>" \
  policies="" \
  | jq -r '.data.id'
# Save the entity ID

# Create alias to link OIDC login
vault write identity/entity-alias \
  name="<user-email>" \
  canonical_id="<entity-id>" \
  mount_accessor="$OIDC_ACCESSOR"
```

#### 2. Add User to Organization Group

```bash
# Get current member IDs
vault read -format=json identity/group/name/<org-name>-org \
  | jq -r '.data.member_entity_ids | join(",")'

# Update group with new member
vault write identity/group/name/<org-name>-org \
  member_entity_ids="<existing-ids>,<new-entity-id>"
```

### Removing Users

#### Remove from Organization

```bash
# Get current members, remove the one you don't want
vault read -format=json identity/group/name/<org-name>-org \
  | jq -r '.data.member_entity_ids'

# Update group without that user
vault write identity/group/name/<org-name>-org \
  member_entity_ids="<remaining-ids>"
```

#### Delete User Entirely

```bash
vault delete identity/entity/name/<user-email>
```

### User Experience

1. User goes to `https://<vault-domain>`
2. Selects OIDC and clicks "Sign in"
3. Google login appears
4. After auth, user sees only the secrets paths they have access to
5. Users in multiple orgs see all their allowed paths

### Quick Reference

| Task | Command |
|------|---------|
| List orgs | `vault secrets list` |
| List groups | `vault list identity/group/name` |
| List users | `vault list identity/entity/name` |
| View group members | `vault read identity/group/name/<org>-org` |
| View user's groups | `vault read identity/entity/name/<email>` |

### Troubleshooting

**"claim 'email' not found"**
- Ensure `oidc_scopes` includes `email` in the role config

**User can't see secrets**
- Check user's entity exists: `vault read identity/entity/name/<email>`
- Check user is in group: `vault read identity/group/name/<org>-org`
- Check group has correct policy: should include `<org>-admin`

**Login fails for valid user**
- User must be in at least one group with a non-default policy
- Check entity alias exists and points to correct OIDC accessor
