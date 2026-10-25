
#!/bin/sh

set -eu

# ==========================================
# Domain Configuration
# ==========================================
DOMAIN_NAME="sodhichebutha.online"
AMQP_HOST="rabbitmq.${DOMAIN_NAME}"

# ==========================================
# Colors
# ==========================================
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
N='\033[0m'

# ==========================================
# Logging Configuration
# ==========================================
LOG_DIR="/var/log/roboshop"
LOG_FILE="$LOG_DIR/dispatch.log"

START_TIME=$(date +%s)
START_DATE=$(date '+%F %T')

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run using sudo sh dispatch.sh"
    exit 1
fi

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

log() {
    LEVEL="$1"
    COLOR="$2"
    MESSAGE="$3"
    TIME=$(date '+%F %T')

    printf "${COLOR}%s [%s] %s${N}\n" \
        "$TIME" "$LEVEL" "$MESSAGE"

    printf '%s [%s] %s\n' \
        "$TIME" "$LEVEL" "$MESSAGE" >> "$LOG_FILE"
}

INFO() {
    log "INFO" "$B" "$1"
}

SUCCESS() {
    log "SUCCESS" "$G" "$1"
}

WARNING() {
    log "WARNING" "$Y" "$1"
}

ERROR() {
    log "ERROR" "$R" "$1"
}

# ==========================================
# Execute Commands With Logging
# ==========================================
run_step() {
    STEP_NAME="$1"
    shift

    INFO "$STEP_NAME"

    if "$@" >> "$LOG_FILE" 2>&1; then
        SUCCESS "$STEP_NAME completed"
    else
        STATUS=$?
        ERROR "$STEP_NAME failed with exit code $STATUS"
        exit "$STATUS"
    fi
}

# ==========================================
# Execution Duration
# ==========================================
finish() {
    STATUS=$?
    trap - 0

    END_TIME=$(date +%s)
    END_DATE=$(date '+%F %T')
    TOTAL_TIME=$((END_TIME - START_TIME))

    if [ "$STATUS" -eq 0 ]; then
        SUCCESS "Dispatch installation completed successfully"
    else
        ERROR "Dispatch installation failed"
        ERROR "Check logs: $LOG_FILE"
    fi

    INFO "Start Time : $START_DATE"
    INFO "End Time   : $END_DATE"
    INFO "Total Time : $((TOTAL_TIME / 3600))h $(((TOTAL_TIME % 3600) / 60))m $((TOTAL_TIME % 60))s"
    INFO "Log File   : $LOG_FILE"
}

trap finish 0

# ==========================================
# Locate Service File
# ==========================================
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

SERVICE_SOURCE="${SCRIPT_DIR}/dispatch.service"
SERVICE_DEST="/etc/systemd/system/dispatch.service"

INFO "=========================================="
INFO "Starting Dispatch Service Installation"
INFO "=========================================="
INFO "Domain   : $DOMAIN_NAME"
INFO "RabbitMQ : $AMQP_HOST"

if [ ! -f "$SERVICE_SOURCE" ]; then
    ERROR "dispatch.service not found: $SERVICE_SOURCE"
    exit 1
fi

SUCCESS "dispatch.service found"

# ==========================================
# Install Go and Utilities
# ==========================================
run_step "Installing Go and utilities" \
    dnf install -y golang unzip curl

run_step "Checking Go version" go version

# ==========================================
# Check Go Version (>= 1.25)
# ==========================================
GO_VERSION=$(go version | awk '{print $3}' | sed 's/^go//')
GO_MAJOR=$(printf '%s' "$GO_VERSION" | cut -d. -f1)
GO_MINOR=$(printf '%s' "$GO_VERSION" | cut -d. -f2)

if [ "$GO_MAJOR" -lt 1 ] ||
   { [ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 25 ]; }; then
    ERROR "Go 1.25 or newer is required. Installed: $GO_VERSION"
    exit 1
fi

SUCCESS "Go version supported: $GO_VERSION"

# ==========================================
# Validate RabbitMQ DNS
# ==========================================
INFO "Checking RabbitMQ DNS"

if getent ahostsv4 "$AMQP_HOST" >> "$LOG_FILE" 2>&1; then
    SUCCESS "DNS resolved: $AMQP_HOST"
else
    WARNING "RabbitMQ DNS not resolving: $AMQP_HOST"
fi

# ==========================================
# Create Application User
# ==========================================
if id roboshop >> "$LOG_FILE" 2>&1; then
    SUCCESS "Roboshop user already exists"
else
    run_step "Creating roboshop user" \
        useradd --system \
        --home /app \
        --shell /sbin/nologin \
        --comment "roboshop system user" \
        roboshop
fi

# ==========================================
# Download Dispatch Application
# ==========================================
run_step "Creating application directory" mkdir -p /app

run_step "Downloading Dispatch application" \
    curl -fL --retry 3 \
    -o /tmp/dispatch.zip \
    "https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/dispatch-v4.zip"

run_step "Extracting Dispatch application" \
    unzip -o /tmp/dispatch.zip -d /app

# ==========================================
# Build Go Application
# ==========================================
INFO "Building Dispatch Go application"

if (cd /app && go build -o dispatch .) >> "$LOG_FILE" 2>&1; then
    SUCCESS "Dispatch binary built successfully"
else
    ERROR "Go build failed"
    exit 1
fi

# ==========================================
# Configure SystemD
# ==========================================
run_step "Copying dispatch.service" \
    cp "$SERVICE_SOURCE" "$SERVICE_DEST"

INFO "Updating RabbitMQ hostname"

if sed -i \
    "s|<RABBITMQ-SERVER-IPADDRESS>|${AMQP_HOST}|g" \
    "$SERVICE_DEST" >> "$LOG_FILE" 2>&1; then
    SUCCESS "RabbitMQ hostname updated"
else
    ERROR "Failed to update RabbitMQ hostname"
    exit 1
fi

if grep -q '<RABBITMQ-SERVER-IPADDRESS>' "$SERVICE_DEST"; then
    ERROR "Unresolved RabbitMQ placeholder"
    exit 1
fi

run_step "Validating systemd configuration" \
    systemd-analyze verify "$SERVICE_DEST"

# ==========================================
# Set Permissions
# ==========================================
run_step "Setting application permissions" \
    chown -R roboshop:roboshop /app

# ==========================================
# Start Dispatch Service
# ==========================================
run_step "Reloading systemd" systemctl daemon-reload
run_step "Enabling Dispatch service" systemctl enable dispatch
run_step "Restarting Dispatch service" systemctl restart dispatch

# ==========================================
# Verify Dispatch Service
# ==========================================
INFO "Checking Dispatch service status"

sleep 2

if systemctl is-active --quiet dispatch; then
    SUCCESS "Dispatch service is running"
else
    journalctl -u dispatch -n 50 --no-pager \
        >> "$LOG_FILE" 2>&1

    ERROR "Dispatch service failed to start"
    exit 1
fi

# ==========================================
# Verify RabbitMQ Connection Log
# ==========================================
INFO "Checking RabbitMQ connection"

if journalctl -u dispatch -n 50 --no-pager \
    | grep -q 'connected to RabbitMQ'; then
    SUCCESS "Dispatch connected to RabbitMQ"
else
    WARNING "RabbitMQ connection not yet confirmed"
    WARNING "Check: journalctl -u dispatch -f"
fi

INFO "=========================================="
SUCCESS "All Dispatch setup steps completed"
INFO "=========================================="
