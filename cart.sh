#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script cart
install_nodejs
create_app_user
download_app cart
run 'Installing NodeJS dependencies' npm --prefix "$APP_DIR" install
run 'Setting application ownership' chown -R "$APP_USER:$APP_USER" "$APP_DIR"
install_service cart
run 'Configuring service endpoints' sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" /etc/systemd/system/cart.service
start_service cart
