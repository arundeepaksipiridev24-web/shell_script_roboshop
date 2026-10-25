#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script dispatch
rabbitmq_host="rabbitmq.$DOMAIN_NAME"

install_go
create_app_user
download_app dispatch
run 'Building dispatch application' bash -c "cd '$APP_DIR' && go build -o dispatch ."
run 'Setting application ownership' chown -R "$APP_USER:$APP_USER" "$APP_DIR"
install_service dispatch
run 'Configuring RabbitMQ endpoint' sed -i \
    "s|<RABBITMQ-SERVER-IPADDRESS>|$rabbitmq_host|g" /etc/systemd/system/dispatch.service
run 'Validating systemd service' systemd-analyze verify /etc/systemd/system/dispatch.service
start_service dispatch
