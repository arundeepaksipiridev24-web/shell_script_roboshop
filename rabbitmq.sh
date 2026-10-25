#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script rabbitmq
run 'Installing RabbitMQ repository' cp "$SCRIPT_DIR/rabbitmq.repo" /etc/yum.repos.d/rabbitmq.repo
install_packages erlang rabbitmq-server
start_service rabbitmq-server

if rabbitmqctl list_users 2>> "$LOG_FILE" | awk '{print $1}' | grep -qx roboshop; then
    info 'RabbitMQ user already exists; skipping'
else
    run 'Creating RabbitMQ user' rabbitmqctl add_user roboshop roboshop123
fi
run 'Setting RabbitMQ permissions' rabbitmqctl set_permissions -p / roboshop '.*' '.*' '.*'
