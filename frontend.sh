#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script frontend
install_packages nginx unzip curl
run 'Downloading frontend' curl -fL --retry 3 -o /tmp/frontend.zip "$ARTIFACT_URL/frontend-v4.zip"
run 'Clearing web root' find /usr/share/nginx/html -mindepth 1 -delete
run 'Extracting frontend' unzip -o /tmp/frontend.zip -d /usr/share/nginx/html
run 'Creating Nginx configuration directory' mkdir -p /etc/nginx/default.d
run 'Installing Nginx configuration' cp "$SCRIPT_DIR/roboshop.conf" /etc/nginx/default.d/roboshop.conf
run 'Configuring service endpoints' sed -i "s/sodhichebutha\.online/$DOMAIN_NAME/g" /etc/nginx/default.d/roboshop.conf
run 'Validating Nginx configuration' nginx -t
start_service nginx
