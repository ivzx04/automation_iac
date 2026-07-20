#!/usr/bin/env bash
# Placed at /docker-entrypoint-initdb.d/ inside the postgres container.
# The official postgres image only runs scripts in this directory on
# an EMPTY data directory -- i.e. first boot ever. Changing this script 
# later does nothing to an already-initialized volume;
# any future schema/role change has to be handled via migration instead.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER n8n WITH PASSWORD '${N8N_DB_PASSWORD}';
    CREATE DATABASE n8n OWNER n8n;

    CREATE USER nocodb WITH PASSWORD '${NOCODB_DB_PASSWORD}';
    CREATE DATABASE nocodb OWNER nocodb;

    CREATE DATABASE automation OWNER ${POSTGRES_USER}'';
EOSQL
