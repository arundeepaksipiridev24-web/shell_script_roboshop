
#!/bin/sh

set -eu

# ==========================================
# Domain Configuration
# ==========================================
DOMAIN_NAME="sodhichebutha.online"

CART_HOST="cart.${DOMAIN_NAME}"
USER_HOST="user.${DOMAIN_NAME}"
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
# Log Configuration
# ==========================================
LOG_DIR="/var/log/roboshop"
LOG_FILE="${LOG_DIR}/payment.log"

START_TIME=$(date +%s)
START_DATE=$(date '+%F %T')

# ==========================================
# Root Check
# ==========================================
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Please run sudo sh payment.sh"
    exit 1
fi

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# ==========================================
# Logging Functions
# Screen = Colored messages
# File   = Messages + command output
# ==========================================
log() {
    LEVEL="$1"
    COLOR="$2"
    MESSAGE="$3"

    TIME=$(date '+%F %T')

    printf "${COLOR}%s [%s] %s${N}\n" \
        "$TIME" "$LEVEL" "$MESSAGE"

    printf "%s [%s] %s\n" \
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
# Execution Time
# ==========================================
show_execution_time() {
    END_TIME=$(date +%s)
    END_DATE=$(date '+%F %T')

    TOTAL_TIME=$((END_TIME - START_TIME))

    HOURS=$((TOTAL_TIME / 3600))
    MINUTES=$(((TOTAL_TIME % 3600) / 60))
    SECONDS=$((TOTAL_TIME % 60))

    INFO "Start Time : $START_DATE"
    INFO "End Time   : $END_DATE"
    INFO "Total Time : ${HOURS}h ${MINUTES}m ${SECONDS}s"
    INFO "Log File   : $LOG_FILE"
}

# ==========================================
# Error Handling
# ==========================================
fail() {
    ERROR "$1"
    ERROR "Check complete logs: $LOG_FILE"
    exit 1
}

# Run command and save full output to log
run_step() {
    STEP_NAME="$1"
    shift

    INFO "$STEP_NAME"

    if "$@" >> "$LOG_FILE" 2>&1; then
        SUCCESS "$STEP_NAME completed"
    else
        STATUS=$?
        ERROR "$STEP_NAME failed (exit code: $STATUS)"
        exit "$STATUS"
    fi
}

# Always show execution time on exit
finish() {
    STATUS=$?

    trap - 0

    if [ "$STATUS" -eq 0 ]; then
        SUCCESS "Payment installation completed successfully"
    else
        ERROR "Payment installation failed"
        ERROR "See: $LOG_FILE"
    fi

    show_execution_time
}

trap finish 0

# ==========================================
# Find Script Directory
# ==========================================
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

SERVICE_SOURCE="${SCRIPT_DIR}/payment.service"
SERVICE_DEST="/etc/systemd/system/payment.service"

INFO "=========================================="
INFO "Starting Payment Service Installation"
INFO "=========================================="

INFO "Domain   : $DOMAIN_NAME"
INFO "Cart     : $CART_HOST"
INFO "User     : $USER_HOST"
INFO "RabbitMQ : $AMQP_HOST"

# ==========================================
# Validate Service File
# ==========================================
INFO "Checking payment.service"

if [ ! -f "$SERVICE_SOURCE" ]; then
    fail "File not found: $SERVICE_SOURCE"
fi

SUCCESS "payment.service found"

# ==========================================
# Install Python and Utilities
# ==========================================
run_step "Installing Python 3.14 and utilities" \
    dnf install -y python3.14 python3.14-pip unzip curl

# ==========================================
# Verify Python
# ==========================================
run_step "Checking Python version" \
    python3.14 --version

# ==========================================
# Check Route 53 DNS
# ==========================================
INFO "Checking Route 53 DNS resolution"

for HOST in "$CART_HOST" "$USER_HOST" "$AMQP_HOST"
do
    if getent ahostsv4 "$HOST" >> "$LOG_FILE" 2>&1; then
        SUCCESS "DNS resolved: $HOST"
    else
        WARNING "DNS not resolved: $HOST"
    fi
done

# ==========================================
# Create Application User
# ==========================================
INFO "Checking roboshop user"

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
# Download Payment Application
# ==========================================
run_step "Creating application directory" \
    mkdir -p /app

run_step "Downloading Payment application" \
    curl -fL --retry 3 \
    -o /tmp/payment.zip \
    "https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/payment-v4.zip"

run_step "Extracting Payment application" \
    unzip -o /tmp/payment.zip -d /app

# ==========================================
# Python Virtual Environment
# ==========================================
run_step "Creating Python virtual environment" \
    python3.14 -m venv /app/.venv

# ==========================================
# Install Python Dependencies
# ==========================================
run_step "Installing Python dependencies" \
    /app/.venv/bin/pip install -r /app/requirements.txt

# ==========================================
# Configure Payment Service
# ==========================================
run_step "Copying payment.service" \
    cp "$SERVICE_SOURCE" "$SERVICE_DEST"

INFO "Updating Route 53 hostnames"

if sed -i \
    -e "s|<CART-SERVER-IPADDRESS>|${CART_HOST}|g" \
    -e "s|<USER-SERVER-IPADDRESS>|${USER_HOST}|g" \
    -e "s|<RABBITMQ-SERVER-IPADDRESS>|${AMQP_HOST}|g" \
    "$SERVICE_DEST" >> "$LOG_FILE" 2>&1; then
    SUCCESS "Route 53 hostnames updated"
else
    fail "Failed to update payment.service"
fi

# Check unresolved placeholders
if grep -q '<.*SERVER-IPADDRESS>' "$SERVICE_DEST"; then
    fail "Unresolved placeholders in payment.service"
fi

# ==========================================
# Validate SystemD Configuration
# ==========================================
run_step "Validating systemd service" \
    systemd-analyze verify "$SERVICE_DEST"

# ==========================================
# Application Permissions
# ==========================================
run_step "Setting application permissions" \
    chown -R roboshop:roboshop /app

# ==========================================
# Start Payment Service
# ==========================================
run_step "Reloading systemd" \
    systemctl daemon-reload

run_step "Enabling Payment service" \
    systemctl enable payment

run_step "Restarting Payment service" \
    systemctl restart payment

# ==========================================
# Verify Service Status
# ==========================================
INFO "Checking Payment service status"

if systemctl is-active --quiet payment; then
    SUCCESS "Payment service is running"
else
    journalctl -u payment -n 50 --no-pager \
        >> "$LOG_FILE" 2>&1

    fail "Payment service is not running"
fi

# ==========================================
# Payment Health Check
# ==========================================
INFO "Checking Payment health API"

HEALTH_OK=0

attempt=1

while [ "$attempt" -le 5 ]
do
    if curl -fsS --max-time 10 \
        http://localhost:8080/health \
        >> "$LOG_FILE" 2>&1; then

        SUCCESS "Payment health API responded"
        HEALTH_OK=1
        break
    fi

    WARNING "Health check attempt $attempt failed"

    attempt=$((attempt + 1))
    sleep 3
done

if [ "$HEALTH_OK" -ne 1 ]; then
    journalctl -u payment -n 50 --no-pager \
        >> "$LOG_FILE" 2>&1

    fail "Payment health check failed"
fi

INFO "=========================================="
SUCCESS "All Payment setup steps completed"
INFO "=========================================="
