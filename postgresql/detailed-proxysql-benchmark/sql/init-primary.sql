-- Monitor user for ProxySQL health checks
CREATE USER proxymon WITH PASSWORD 'proxymon';
GRANT pg_monitor TO proxymon;

-- App user
CREATE USER appuser WITH PASSWORD 'appuser';
GRANT ALL PRIVILEGES ON DATABASE demo TO appuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO appuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO appuser;
