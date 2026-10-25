#!/bin/bash

# Common variables and functions used by all RoboShop scripts.

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
RESET='\e[0m'
APP_DIR='/app'
APP_USER='roboshop'
ARTIFACT_URL='https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts'

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd)
DOMAIN_NAME=${DOMAIN_NAME:-sodhichebutha.online}

log() {
    echo -e "$(date '+%F %T') $1" | tee -a "$LOG_FILE"
}

info() { log "[INFO] $1"; }
success() { log "${GREEN}[SUCCESS]${RESET} $1"; }
warning() { log "${YELLOW}[WARNING]${RESET} $1"; }
error() { log "${RED}[ERROR]${RESET} $1"; }

run() {
    local message=$1
    shift
    "$@" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        success "$message"
    else
        error "$message failed. Check $LOG_FILE"
        exit 1
    fi
}

init_script() {
    APP_NAME=$1
    if [ "$(id -u)" -ne 0 ]; then
        printf 'Run this script as root: sudo bash %s.sh\n' "$APP_NAME" >&2
        exit 1
    fi
    if [[ ! $DOMAIN_NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        printf 'Invalid DOMAIN_NAME: %s\n' "$DOMAIN_NAME" >&2
        exit 1
    fi
    LOG_DIR=${LOG_DIR:-/var/log/roboshop}
    mkdir -p -- "$LOG_DIR"
    LOG_FILE="$LOG_DIR/$APP_NAME-$(date +%F-%H-%M-%S).log"
    touch "$LOG_FILE"
    info "Starting $APP_NAME setup"
}

install_packages() {
    run "Installing packages: $*" dnf install -y "$@"
}

install_nodejs() {
    run 'Disabling default NodeJS module' dnf module disable nodejs -y
    run 'Enabling NodeJS 24 module' dnf module enable nodejs:24 -y
    install_packages nodejs unzip curl
}

install_java() {
    run 'Enabling Maven 3.9 module' dnf module enable maven:3.9 -y
    install_packages maven java-25-openjdk-devel unzip curl mysql
    run 'Selecting Java 25' alternatives --set java /usr/lib/jvm/java-25-openjdk/bin/java
}

install_python() {
    install_packages python3.14 python3.14-pip unzip curl
}

install_go() {
    install_packages golang unzip curl
}

create_app_user() {
    if id "$APP_USER" >> "$LOG_FILE" 2>&1; then
        info "$APP_USER user already exists; skipping"
    else
        run "Creating $APP_USER user" useradd --system --home "$APP_DIR" \
            --shell /sbin/nologin --comment 'RoboShop service user' "$APP_USER"
    fi
}

download_app() {
    local app=$1
    local archive="/tmp/$1.zip"
    run "Downloading $app" curl -fL --retry 3 -o "$archive" "$ARTIFACT_URL/$app-v4.zip"
    run "Validating $app archive" unzip -t "$archive"
    run "Preparing $APP_DIR" rm -rf -- "$APP_DIR"
    run "Creating $APP_DIR" mkdir -p "$APP_DIR"
    run "Extracting $app" unzip -o "$archive" -d "$APP_DIR"
}

install_service() {
    local service=$1
    run "Installing $service service" cp "$SCRIPT_DIR/$service.service" "/etc/systemd/system/$service.service"
}

start_service() {
    local service=$1
    run 'Reloading systemd' systemctl daemon-reload
    run "Enabling $service" systemctl enable "$service"
    run "Restarting $service" systemctl restart "$service"
    run "Checking $service" systemctl is-active --quiet "$service"
    success "$APP_NAME setup completed"
    info "Log file: $LOG_FILE"
}
