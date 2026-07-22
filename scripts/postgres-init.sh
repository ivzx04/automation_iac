#!/usr/bin/env bash
# Placed at /docker-entrypoint-initdb.d/ inside the postgres container.
# The official postgres image only runs scripts in this directory on
# an EMPTY data directory -- i.e. first boot ever. Changing this script 
# later does nothing to an already-initialized volume;
# any future schema/role change has to be handled via migration instead.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    CREATE USER n8n WITH PASSWORD '${N8N_DB_PASSWORD}';
    CREATE DATABASE n8n OWNER n8n;

    CREATE USER nocodb WITH PASSWORD '${NOCODB_DB_PASSWORD}';
    CREATE DATABASE nocodb OWNER nocodb;

    CREATE USER n8n_workflows WITH PASSWORD '${N8N_WORKFLOWS_DB_PASSWORD}';
    GRANT CONNECT ON DATABASE automation TO n8n_workflows;
    GRANT USAGE, CREATE ON SCHEMA public TO n8n_workflows;

    CREATE TABLE thesis_onboarding (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        student_email TEXT NOT NULL,
        supervisor_email TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',  -- pending/confirmed/denied
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE compute_requests (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        onboarding_id UUID REFERENCES thesis_onboarding(id),
        status TEXT NOT NULL DEFAULT 'pending',
        confirmation_token UUID NOT NULL DEFAULT gen_random_uuid(),
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE USER nocodb_domain WITH PASSWORD '${NOCODB_DOMAIN_PASSWORD}';
    GRANT CONNECT ON DATABASE automation TO nocodb_domain;
    GRANT USAGE, CREATE ON SCHEMA public TO nocodb_domain;

    ALTER DEFAULT PRIVILEGES FOR ROLE nocodb_domain IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO n8n_workflows;

    ALTER DEFAULT PRIVILEGES FOR ROLE n8n_workflows IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE ON TABLES TO nocodb_domain;

EOSQL
