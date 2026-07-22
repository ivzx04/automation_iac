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
rm -rf "$DEST" # in case container names change its best to clean this thing up to prevent weirdness down the line (this bit me)
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

chown -R ${USER}:${USER} "/home/${USER}/.local"
echo "Moved necessary init files"

echo ""
echo ""

# ensure that secrets have been created before starting services
echo "Now creating secrets, save the upcoming output if you care about having direct access to these"
su - "$USER" -c "${CONTAINER_DIR}/create-secrets.sh" 
echo "Created secrets and finished setup!"

echo ""
echo "Now starting services:"

# this could be the ticket sudo -u ${USER} -H XDG_RUNTIME_DIR=/run/user/${USER_UID}   systemctl --user status automation-postgres.service 
sudo -u ${USER} -H XDG_RUNTIME_DIR=/run/user/${USER_UID}   systemctl --user daemon-reload
sudo -u ${USER} -H XDG_RUNTIME_DIR=/run/user/${USER_UID}   systemctl --user start automation-postgres.service 
echo  "Started postgres"
sleep 35 ## just to let postgres fully spin up before going onto the other services and preventing stale data 
sudo -u ${USER} -H XDG_RUNTIME_DIR=/run/user/${USER_UID}   systemctl --user start automation-nocodb.service 
echo  "Started nocodb"
sudo -u ${USER} -H XDG_RUNTIME_DIR=/run/user/${USER_UID}   systemctl --user start automation-n8n.service 
echo  "Started n8n"
sudo -u ${USER} -H XDG_RUNTIME_DIR=/run/user/${USER_UID}   systemctl --user start automation-caddy.service 
echo  "Started caddy"

echo
echo "All done! check statuses by doing the following"

# echo "This last part of the script i have not yet figured out how to automate. To finish setup, simply do the following steps in order:"
echo "1. Get a shell as the automation user using the following: "
echo "   sudo machinectl shell ${USER}@"
echo "2. check services with"
echo "   systemctl --user list-unit-files | grep -i -E 'automation'"
echo
# echo "   systemctl --user daemon-reload"
# echo "3. Start the services listed below in the listed dependency order"
# echo "   systemctl --user start automation-network"
# echo "   systemctl --user start automation-postgres"
# echo "   systemctl --user start automation-nocodb"
# echo "   systemctl --user start automation-n8n"
# echo "   systemctl --user start automation-caddy"
# echo
