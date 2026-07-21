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
if ! podman secret exists postgres-password 2>/dev/null; then
  create_if_missing postgres-password "$(openssl rand -base64 32)"
fi

create_if_missing n8n-db-password "$(openssl rand -base64 32)"
create_if_missing nocodb-db-password "$(openssl rand -base64 32)"

# n8n's credential-at-rest encryption key. Generated once, never
# rotated automatically (n8n has no key-rotation path) -- back this
# up externally (password manager) the moment it's created, since
# losing it makes every stored n8n credential permanently unreadable.
if ! podman secret exists n8n-encryption-key 2>/dev/null; then
  KEY="$(openssl rand -base64 32)"
  printf '%s' "$KEY" | podman secret create n8n-encryption-key -
  echo "created secret 'n8n-encryption-key'"
  echo
  echo "  >>> BACK THIS UP NOW, IT WILL NOT BE SHOWN AGAIN <<<"
  echo "  N8N_ENCRYPTION_KEY = ${KEY}"
  echo
fi

# NocoDB's full connection string as a single secret, injected as an
# env var directly (type=env in the quadlet unit) since NC_DB has no
# native _FILE support. Values here must match n8n-db-password /
# nocodb-db-password above and whatever the postgres init script creates.
NOCODB_DB_PASS="$(podman secret inspect nocodb-db-password --showsecret --format '{{.SecretData}}' 2>/dev/null || true)"
if [[ -z "$NOCODB_DB_PASS" ]]; then
  echo "WARNING: could not read back nocodb-db-password -- create nocodb-db-url manually:"
  echo "  podman secret create nocodb-db-url - <<< 'pg://automation-postgres:5432?u=nocodb&p=<password>&d=nocodb'"
else
  create_if_missing nocodb-db-url "pg://automation-postgres:5432?u=nocodb&p=${NOCODB_DB_PASS}&d=nocodb"
fi

if podman secret exists n8n-owner-password-hash 2>/dev/null; then
  echo "secret 'n8n-owner-password-hash' already exists, skipping"
else
  OWNER_PASS="$(openssl rand -base64 24)"
  OWNER_HASH="$(podman run --rm docker.io/library/caddy:2-alpine caddy hash-password --plaintext "$OWNER_PASS")"
  printf '%s' "$OWNER_HASH" | podman secret create n8n-owner-password-hash -
  echo "created secret 'n8n-owner-password-hash'"
  echo
  echo "  >>> BACK THIS UP NOW, IT WILL NOT BE SHOWN AGAIN <<<"
  echo "  n8n owner login password = ${OWNER_PASS}"
  echo
fi


if podman secret exists nocodb-admin-password 2>/dev/null; then
  echo "secret 'nocodb-admin-password' already exists, skipping"
else
  NC_PASS="$(openssl rand -base64 24)"
  printf '%s' "$NC_PASS" | podman secret create nocodb-admin-password -
  echo
  echo "  >>> BACK THIS UP NOW, IT WILL NOT BE SHOWN AGAIN <<<"
  echo "  NocoDB admin login password = ${NC_PASS}"
  echo
fi

create_if_missing n8n-workflows-db-password "$(openssl rand -base64 32)"
create_if_missing nocodb-domain-password "$(openssl rand -base64 32)"

# add this in later and wire it up to prevent making admin accounts each time (also probably use python for the bcrypt pw hash requiered for n8n btw)

echo "Done. Verify with: podman secret ls"

