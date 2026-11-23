#!/usr/bin/env bash
# Run once on the server: install the Nginx site and obtain a Let's Encrypt certificate.
#   sudo DOMAIN=app.example.com EMAIL=me@example.com ./setup-nginx-ssl.sh
set -euo pipefail
DOMAIN="${DOMAIN:?DOMAIN required}"
EMAIL="${EMAIL:?EMAIL required for Lets Encrypt registration}"
TEMPLATE="$(dirname "$0")/../nginx/app.conf.template"

# shellcheck disable=SC2016 # literal variable name for envsubst
DOMAIN="$DOMAIN" envsubst '${DOMAIN}' < "$TEMPLATE" > /etc/nginx/sites-available/app.conf
ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
nginx -t
systemctl reload nginx

certbot --nginx --non-interactive --agree-tos --redirect -m "$EMAIL" -d "$DOMAIN"
systemctl enable --now certbot.timer   # automatic renewal
echo "HTTPS ready: https://${DOMAIN}"
