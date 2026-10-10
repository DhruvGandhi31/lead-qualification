-- n8n keeps its own state (workflows, credentials, executions) in a separate database
-- on the same Postgres instance. App data lives in $POSTGRES_DB (default: leads).
CREATE DATABASE n8n;
