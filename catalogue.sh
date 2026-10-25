#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script catalogue
mongodb_host="mongodb.$DOMAIN_NAME"

install_nodejs
create_app_user
download_app catalogue
run 'Installing NodeJS dependencies' npm --prefix "$APP_DIR" install
run 'Setting application ownership' chown -R "$APP_USER:$APP_USER" "$APP_DIR"
install_service catalogue
run 'Configuring MongoDB endpoint' sed -i "s/MONGO_ENDPOINT/$mongodb_host/g" /etc/systemd/system/catalogue.service
run 'Installing MongoDB repository' cp "$SCRIPT_DIR/mongo.repo" /etc/yum.repos.d/mongo.repo
install_packages mongodb-mongosh

product_count=$(mongosh --host "$mongodb_host" --quiet \
    --eval 'db.getSiblingDB("catalogue").products.countDocuments()' 2>> "$LOG_FILE" || true)
if [[ $product_count == 11 ]]; then
    info 'Catalogue data already exists; skipping'
else
    run 'Loading catalogue data' bash -c "mongosh --host '$mongodb_host' < '$APP_DIR/db/master-data.js'"
fi

start_service catalogue
