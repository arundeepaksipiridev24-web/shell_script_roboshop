#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script user
install_nodejs
create_app_user
download_app user
run 'Installing NodeJS dependencies' npm --prefix "$APP_DIR" install
run 'Setting application ownership' chown -R "$APP_USER:$APP_USER" "$APP_DIR"
install_service user
run 'Configuring service endpoints' sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" /etc/systemd/system/user.service
start_service user
