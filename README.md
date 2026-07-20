# automation-environment

Podman-first scaffolding for the automation services. The deployment target needs nothing but Podman >=4.4 and systemd (Quadlet ships with Podman itself, so this should work on most systemd based distros: Ubuntu, Debian, Fedora, RHEL, Arch, etc).

## Layout

```
quadlet/
  automation-net.network       -- podman network definition
  reverse-proxy.container      -- Caddy, the only container with a published port
  n8n.service                  -- n8n service to orchestrate automation tasks
  nocodb.service               -- allows for a nice admin dashboard for easy editing
  postgres.service             -- main source of truth and backing db for all other services
scripts/
  install-quadlets.sh          -- copies units into ~/.config/containers/systemd, reloads
  create-secrets.sh            -- decrypts per-service sops env files into podman secrets
  postgres-init.sh             -- script that runs only once on the very first deployment to define pg architecture
```

## Deploying 

1. Install Podman >=4.4 and make sure your user has a systemd instance
2. Run the provided install-quadlets.sh scripts (make sure you are in the scripts directory when you do this)
3. switch to the newly created user using the following command: ` sudo machinectl shell automation@ `
4. start the listed services

All of these steps only need to be done once at setup time.

## Network model

One podman bridge network, `automation-net`. Only `reverse-proxy` publishes ports. Other services are reachable directly only from other containers on that network. Each service backend has its own podman secret(s); they never share a credential.

## description of the init script and its consequences

The init script mainly just creates a new automation user and copies over alot of the contents of this repo into the required places to properly mount volumes for all of the services. The created user account will then essentially have its systemd instance in charge of handling all of the containers and ensuring that they are constantly up. By defualt this account has its passwd locked and thus must be accesed via sudo commands to get in (for more easy access I would reccomend adding ssh keys to an authorized hosts files). Additionally the script makes the account linger, meaning that it doesnt need someone to log into it for the services to run automatically, making it survive reboots fairly easily. The majority of mounted volumes are then all held within this users home directory, allowing for fairly simple migration of things via a copying of the exising home directory. 

Some benefits of this podman quadlet design are that systemd integration natively gives you things like automatic restarts and logging. For instance to see if a service is up you can call `systemctl --user status <service-name>` and get logs via `journalctl --user <service-name>` while logged in as the automation account. 

This also cleanly separates the state of these operations into one account which is constantly running while not needing to give it sudo access. This is nice for worst case scenario, allowing this same environment to function as a place to later deploy agentic solutions to other workflows without the risk of a root compromise if it escapes its sandbox.

## A note on secret handling

For ease of deployment, secrets are currently being automatically handled by podman on the created automation account. Upon creation of new secrets, the value of the key is printed to console so they can be saved beforehand. 
