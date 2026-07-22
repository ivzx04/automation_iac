# automation-environment

Podman container scaffolding for some basic automation workflows to be orchestrated through n8n. The deployment target needs nothing but Podman >=5.5 and systemd (Quadlet ships with Podman itself, so this should work on most systemd based distros: Ubuntu, Debian, Fedora, RHEL, Arch, etc).

## Layout

```
quadlet/
  automation-net.network       -- podman network definition
  automation-caddy.container      -- Caddy, the only container with a published port
  automation-n8n.service                  -- n8n service to orchestrate automation tasks
  automation-nocodb.service               -- allows for a nice admin dashboard for easy editing
  automation-postgres.service             -- main source of truth and backing db for all other services
scripts/
  install-quadlets.sh          -- creates a user to manage the environment, copies units into ~/etc/containers/systemd/users/<uid>, generates needed secrets and spins up the containers
  create-secrets.sh            -- bash script that creates secrets via randomly generated openssl strings upon first deployment
  postgres-init.sh             -- script that runs only once on the very first deployment to define pg architecture
```

## Deploying 

1. Install Podman and make sure your user has a systemd instance
2. Run the provided install-quadlets.sh scripts (make sure you are in the scripts directory when you do this)
3. Save the credentials printed during the install 
4. Login to the services as needed. (note for the moment I have not yet gotten the nococdb admin account to be automatically registered which is a bit of a shame)
5. For nocodb add the connection to the main automation database via their interface

All of these steps only need to be done once at setup time.

## Network model

One podman bridge network, `automation-network`. Only `caddy` publishes ports acting as a reverse proxy, it only exposes n8n and nocodb through n8n.automation.local and admin.automation.local respectively. Other services are reachable directly only from other containers on that network. Each service backend has its own podman secret(s); they never share a credential, however almost everything is automatically handled for ease of deployment. 

As a side effect off using Caddy for tls with extenrnal connections, for browsers to not freak out upon seeing the exposed pages, the caddy generated certificate should be installed onto the OS/Browser trust store of users.

## description of the init script and its consequences

The init script mainly just creates a new automation user and copies over a lot of the contents of this repo into the required places to properly mount volumes for all of the services. The created user account will then essentially have its systemd instance in charge of handling all of the containers and ensuring that they are constantly up. By default this account has its password locked and thus must be accessed via sudo commands to get in (for more easy access I would recommend adding ssh keys to an authorized hosts file). Additionally the script makes the account linger, meaning that it doesnt need someone to log into it for the services to run automatically, making it survive reboots fairly easily. The majority of mounted volumes are then all held within this users home directory, allowing for fairly simple migration of things via a copying of the exising home directory. Furthermore, the script will create all the needed secrets for running automatically and is fairly idempotent, allowing for ease of use in a general sense.  

Some benefits of this podman quadlet design are that systemd integration natively gives you things like automatic restarts and logging. For instance to see if a service is up you can call `systemctl --user status <service-name>` and get logs via `journalctl --user <service-name>` while logged in as the automation account. Additionally it does not rely on the docker daemon service as well which allows for a better separation of responsibilities. 

This also cleanly separates the state of these operations into one account which is constantly running while not needing to give it sudo access. This is nice for worst case scenario, allowing this same environment to function as a place to later deploy agentic solutions to other workflows without the risk of a root compromise if it escapes its sandbox.

## n8n installation rules

All services store their internal data on their own separate postgres databases with their own separate access accounts. To ensure that data is not automatically lost or deleted during deployment, the exposed n8n_workflows user for the main automation database in postgres has SELECT, INSERT, and UPDATE access permissions only. (no DELETE)  

## Pinned versions (do not casually bump)
- nocodb: 0.301.1 — SSRF_ALLOWED_DOMAINS/NC_ALLOW_PRIVATE_IP broke in 0.301.4+, required for connecting to the automation DB over the internal network at all.
- n8n: 1.81.0
- caddy: 2.32.11-alpine 
- postgres: 17.10

## important TODO

Postgres 'prod' data and the n8n workflows should probably get some kind of backup/migration strategy dedicated to them for this to be safe to deploy, but it has yet to be implemented.
