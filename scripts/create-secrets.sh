#!/usr/bin/env bash

set -euo pipefail

create_if_missing() {
  local name="$1"
  local value="$2"
  if podman secret exists "$name" 2>/dev/null; then
    echo "secret '$name' already exists, skipping"
  else
    printf '%s' "$value" | podman secret create "$name" -
    echo "created secret '$name' with value '$value'"
  fi
}

# Postgres superuser password
create_if_missing postgres-password "$(openssl rand -hex 32)"

# internal storage for n8n and nocodb passwords on postgres (separate from 'prod' data)
create_if_missing n8n-db-password "$(openssl rand -hex 32)"

NC_PASS="$(openssl rand -hex 32)"
create_if_missing nocodb-db-password "$NC_PASS" 
create_if_missing nocodb-db-url "pg://automation-postgres:5432?u=nocodb&p=${NC_PASS}&d=nocodb"

# n8n's credential-at-rest encryption key. Generated once, never
# rotated automatically (n8n has no key-rotation path) -- back this
# up externally (password manager) the moment it's created, since
# losing it makes every stored n8n credential permanently unreadable.
if ! podman secret exists n8n-encryption-key 2>/dev/null; then
  KEY="$(openssl rand -hex 32)"
  printf '%s' "$KEY" | podman secret create n8n-encryption-key -
  echo "created secret 'n8n-encryption-key'"
  echo
  echo "  >>> BACK THIS UP NOW, IT WILL NOT BE SHOWN AGAIN <<<"
  echo "  N8N_ENCRYPTION_KEY = ${KEY}"
  echo
fi


# this one was a little annoying bc n8n requires a bcrypt pw to functoin, but i basically 
# got away with it by having it launch a cheeky caddy container 
# that would then launch hash it itself to prevent needing other dependancies
if podman secret exists n8n-owner-password-hash 2>/dev/null; then
  echo "secret 'n8n-owner-password-hash' already exists, skipping"
else
  OWNER_PASS="$(openssl rand -hex 24)"
  OWNER_HASH="$(podman run --rm docker.io/library/caddy:2-alpine caddy hash-password --plaintext "$OWNER_PASS")"
  printf '%s' "$OWNER_HASH" | podman secret create n8n-owner-password-hash -
  echo "created secret 'n8n-owner-password-hash'"
  echo
  echo "  >>> BACK THIS UP NOW, IT WILL NOT BE SHOWN AGAIN <<<"
  echo "  n8n owner login password = ${OWNER_PASS}"
  echo
fi

# admin pass for nocodb
create_if_missing nocodb-admin-password "$(openssl rand -hex 24)"

# passwords that get used on the main automation database
create_if_missing n8n-workflows-db-password "$(openssl rand -hex 32)"
create_if_missing nocodb-domain-password "$(openssl rand -hex 32)"

echo "Done. Verify with: podman secret ls"

