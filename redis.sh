#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script redis
run 'Disabling default Redis module' dnf module disable redis -y
run 'Enabling Redis 7 module' dnf module enable redis:7 -y
install_packages redis
run 'Configuring Redis' sed -i \
    -e 's/^bind 127\.0\.0\.1/bind 0.0.0.0/' \
    -e 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
start_service redis
run 'Verifying Redis' redis-cli ping
