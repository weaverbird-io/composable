-- WeaverBird AIM Database Initialization
-- Creates separate databases for each service

-- SpiceDB database
CREATE DATABASE spicedb;
GRANT ALL PRIVILEGES ON DATABASE spicedb TO weaverbird;

-- ReBAC service database (for shift schedules, metadata)
CREATE DATABASE rebac;
GRANT ALL PRIVILEGES ON DATABASE rebac TO weaverbird;

-- Audit service database
CREATE DATABASE audit;
GRANT ALL PRIVILEGES ON DATABASE audit TO weaverbird;

-- Notification service database
CREATE DATABASE notification;
GRANT ALL PRIVILEGES ON DATABASE notification TO weaverbird;

-- Credential service database (metadata only, secrets in Vault)
CREATE DATABASE credential;
GRANT ALL PRIVILEGES ON DATABASE credential TO weaverbird;

-- Communication service database
CREATE DATABASE communication;
GRANT ALL PRIVILEGES ON DATABASE communication TO weaverbird;

-- Identity service database (legacy)
CREATE DATABASE identity;
GRANT ALL PRIVILEGES ON DATABASE identity TO weaverbird;

-- Auth service database (weaverbird-auth)
CREATE DATABASE weaverbird_auth;
GRANT ALL PRIVILEGES ON DATABASE weaverbird_auth TO weaverbird;
