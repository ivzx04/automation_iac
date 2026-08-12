## notes on the letsencrypt setup 

first install the needed packages for certbot

```
apt update && apt install certbot python3-certbot-dns-rfc2136
```

create this file (create parent dirs if needed): 
```bash
touch /etc/letsencrypt/rfc2136/credentials.ini 
```
and fill with the following:
```
dns_rfc2136_server = <nameserver-ip>
dns_rfc2136_port = 53
dns_rfc2136_name = <tsig-key-name>
dns_rfc2136_secret = <tsig-key-secret>
dns_rfc2136_algorithm = <tsig-algorithm>
```

Change the permissions on the file with teh following command:
```bash
chmod 600 /etc/letsencrypt/rfc2136/credentials.ini
```
Register an email address (or the same one as before with certbot for use when asking for the certificate) with the following
```bash
certbot register --email <email> --agree-tos --no-eff-email
```

to not waste api first just try the following command to confirm the credentials are correctly specified

```bash
certbot certonly --dry-run \
  --dns-rfc2136 \
  --dns-rfc2136-credentials /etc/letsencrypt/rfc2136/credentials.ini \
  -d <hostname-to-certify>
```

If it worked, run the command again without the dry run flag for each hostname that needs to be certified 
```bash
certbot certonly \
  --dns-rfc2136 \
  --dns-rfc2136-credentials /etc/letsencrypt/rfc2136/credentials.ini \
  -d <hostname-to-certify>
```

Finally create a deploy script to be run upon renewal to ensure that caddy sees when certs are updated:
```
touch /etc/letsencrypt/renewal-hooks/deploy/reload-caddy.sh
```
Mine ended up looking like this:

```bash
#!/usr/bin/env bash
cp /etc/letsencrypt/live/n8n.automation.caisa.bit.uni-bonn.de/fullchain.pem /srv/caddy/certs/n8n.automation.caisa.bit.uni-bonn.de/fullchain.pem
cp /etc/letsencrypt/live/n8n.automation.caisa.bit.uni-bonn.de/privkey.pem   /srv/caddy/certs/n8n.automation.caisa.bit.uni-bonn.de/privkey.pem
chown root:automation /srv/caddy/certs/n8n.automation.caisa.bit.uni-bonn.de/*
chmod 640 /srv/caddy/certs/n8n.automation.caisa.bit.uni-bonn.de/*

cp /etc/letsencrypt/live/admin.automation.caisa.bit.uni-bonn.de/fullchain.pem /srv/caddy/certs/admin.automation.caisa.bit.uni-bonn.de/fullchain.pem
cp /etc/letsencrypt/live/admin.automation.caisa.bit.uni-bonn.de/privkey.pem   /srv/caddy/certs/admin.automation.caisa.bit.uni-bonn.de/privkey.pem
chown root:automation /srv/caddy/certs/admin.automation.caisa.bit.uni-bonn.de/*
chmod 640 /srv/caddy/certs/admin.automation.caisa.bit.uni-bonn.de/*

sudo -u automation -H XDG_RUNTIME_DIR=/run/user/$(id -u automation) systemctl --user restart automation-caddy.service
```

And you're done!

