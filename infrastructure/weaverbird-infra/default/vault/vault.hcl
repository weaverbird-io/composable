# Vault Configuration for WeaverBird AIM (Development)
# In dev mode, Vault runs in-memory with auto-unsealing

ui = true

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true  # No TLS in development
}

# Development mode uses in-memory storage
# Production would use raft or consul backend
storage "file" {
  path = "/vault/data"
}

# Disable mlock for development (Docker)
disable_mlock = true

# API address
api_addr = "http://127.0.0.1:8200"
