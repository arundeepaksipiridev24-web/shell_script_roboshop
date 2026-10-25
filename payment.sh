#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script payment
cart_host="cart.$DOMAIN_NAME"
user_host="user.$DOMAIN_NAME"
rabbitmq_host="rabbitmq.$DOMAIN_NAME"

install_python
create_app_user
download_app payment
run 'Creating Python virtual environment' python3.14 -m venv "$APP_DIR/.venv"
run 'Installing Python dependencies' "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
run 'Setting application ownership' chown -R "$APP_USER:$APP_USER" "$APP_DIR"
install_service payment
run 'Configuring service endpoints' sed -i \
    -e "s|<CART-SERVER-IPADDRESS>|$cart_host|g" \
    -e "s|<USER-SERVER-IPADDRESS>|$user_host|g" \
    -e "s|<RABBITMQ-SERVER-IPADDRESS>|$rabbitmq_host|g" \
    /etc/systemd/system/payment.service
run 'Validating systemd service' systemd-analyze verify /etc/systemd/system/payment.service
start_service payment
