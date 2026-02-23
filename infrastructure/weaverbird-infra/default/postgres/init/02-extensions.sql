-- Enable useful PostgreSQL extensions for each database

-- Connect to audit database and enable extensions
\c audit
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Connect to notification database
\c notification
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Connect to credential database
\c credential
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Connect to communication database
\c communication
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Connect to identity database
\c identity
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Connect to rebac database
\c rebac
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
