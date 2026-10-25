#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script mongodb
run 'Installing MongoDB repository' cp "$SCRIPT_DIR/mongo.repo" /etc/yum.repos.d/mongo.repo
install_packages mongodb-org
run 'Configuring MongoDB listen address' sed -i 's/127\.0\.0\.1/0.0.0.0/' /etc/mongod.conf
start_service mongod
