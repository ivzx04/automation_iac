#!/usr/bin/env bash
# Installs quadlet/*.container and *.network into the rootless quadlet
# directory and reloads systemd. Run this on the deployment host itself
# to get everything started
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (or via sudo)."  >&2
  exit 1
fi 

USER="automation"

if id "$USER" &>/dev/null; then
  echo "Automation User already exists, skipping creation"
else 
  useradd "$USER" --create-home
  passwd -l "$USER" &>/dev/null # lock the password of the user (accessible only with sudo access or perhaps via ssh with authorized keys)
  echo "Created user ${USER}"
fi

loginctl enable-linger "$USER" 

USER_UID="$(id -u "$USER")"
systemctl start "user@${USER_UID}.service" # ensure that the new users systemd handler is running
DEST="/etc/containers/systemd/users/${USER_UID}"
mkdir -p "$DEST"

cp "$(dirname "$0")"/../quadlet/*.network "$DEST"/
cp "$(dirname "$0")"/../quadlet/*.container "$DEST"/
chown -R root:root "$DEST"
chmod 644 "$DEST"/*
echo "Quadlet units installed to $DEST"

CONTAINER_DIR="/home/${USER}/.local/share/containers"
mkdir -p "${CONTAINER_DIR=}/quadlets_bk/n8n" # its important to make this bc its a mount point
cp "$(dirname "$0")"/../quadlet/Caddyfile  "$CONTAINER_DIR"

cp "$(dirname "$0")"/postgres-init.sh "${CONTAINER_DIR}/postgres-init.sh"
cp "$(dirname "$0")"/create-secrets.sh "${CONTAINER_DIR}/create-secrets.sh"
chmod +x "${CONTAINER_DIR}"/*.sh

chown -R ${USER}:${USER} "$CONTAINER_DIR"
echo "Moved necessary init files"

echo ""
echo ""

# ensure that secrets have been created before starting services
echo "Now creating secrets, save the upcoming output if you care about having direct access to these"
su - "$USER" -c "${CONTAINER_DIR}/create-secrets.sh" 
echo "Created secrets and finished setup!"

echo ""
echo ""

# spit out final instructions for the final setup 
# (in the future, maybe have this execute by forking a shell in the new users context and have it execute a script withi these commands)
echo "This last part of the script i have not yet figured out how to automate. To finish setup, simply do the following steps in order:"
echo "1. Get a shell as the automation user using the following: "
echo "   sudo machinectl shell ${USER}@"

echo "2. Reload the daemon to define the quadlet services"
echo "   systemctl --user daemon-reload"

echo "3. Start the services listed below in the listed dependency order"
echo "   systemctl --user start automation-network.service"
echo "   systemctl --user start postgres.service"
echo "   systemctl --user start nocodb.service"
echo "   systemctl --user start n8n.service"
echo "   systemctl --user start caddy.service"
echo
