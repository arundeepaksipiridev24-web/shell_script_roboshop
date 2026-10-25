
#!/bin/bash

set -Eeuo pipefail

# ==========================================
# Colors
# ==========================================
R="\e[31m"
G="\e[32m"
Y="\e[33m"
B="\e[34m"
N="\e[0m"

# ==========================================
# Log Configuration
# ==========================================
LOG_DIR="/var/log/roboshop"
LOG_FILE="$LOG_DIR/payment.log"

mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

# ==========================================
# Start Time
# ==========================================
START_TIME=$(date +%s)
START_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# ==========================================
# Logging Functions
# ==========================================
INFO() {
    echo -e "${B}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1${N}"
}

SUCCESS() {
    echo -e "${G}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1${N}"
}

WARNING() {
    echo -e "${Y}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1${N}"
}

ERROR() {
    echo -e "${R}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1${N}"
}

# ==========================================
# Execution Time
# ==========================================
show_execution_time() {
    END_TIME=$(date +%s)
    END_DATE=$(date '+%Y-%m-%d %H:%M:%S')

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
on_error() {
    local exit_code=$1
    local line_number=$2

    trap - ERR

    ERROR "Payment installation failed at line $line_number"
    ERROR "Exit Code: $exit_code"

    show_execution_time
    exit "$exit_code"
}

trap 'on_error "$?" "$LINENO"' ERR

# ==========================================
# Validate Arguments
# ==========================================
if [[ "$EUID" -ne 0 ]]; then
    ERROR "Run this script using sudo"
    exit 1
fi

DOMAIN_NAME="${1:-}"

if [[ -z "$DOMAIN_NAME" ]]; then
    ERROR "Domain name is missing"
    INFO "Usage: sudo bash payment.sh sodhichebutha.online"
    exit 1
fi

# Remove accidental trailing dot
DOMAIN_NAME="${DOMAIN_NAME%.}"

# ==========================================
# Route 53 DNS Hostnames
# ==========================================
CART_HOST="cart.${DOMAIN_NAME}"
USER_HOST="user.${DOMAIN_NAME}"
AMQP_HOST="rabbitmq.${DOMAIN_NAME}"

# Find service file relative to script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICE_SOURCE="$SCRIPT_DIR/payment.service"
SERVICE_DEST="/etc/systemd/system/payment.service"

INFO "=========================================="
INFO "Starting Payment Service Installation"
INFO "=========================================="

INFO "Domain      : $DOMAIN_NAME"
INFO "Cart Host   : $CART_HOST"
INFO "User Host   : $USER_HOST"
INFO "RabbitMQ    : $AMQP_HOST"
INFO "Started At  : $START_DATE"

# ==========================================
# Validate Service File
# ==========================================
INFO "Checking payment.service file"

if [[ ! -f "$SERVICE_SOURCE" ]]; then
    ERROR "payment.service not found at $SERVICE_SOURCE"
    exit 1
fi

SUCCESS "payment.service file found"

# ==========================================
# Install Dependencies
# ==========================================
INFO "Installing Python 3.14 and utilities"

dnf install -y \
    python3.14 \
    python3.14-pip \
    unzip \
    curl

SUCCESS "System dependencies installed"

# ==========================================
# Validate Route 53 DNS
# ==========================================
INFO "Checking Route 53 DNS resolution"

for HOST in "$CART_HOST" "$USER_HOST" "$AMQP_HOST"
do
    if getent ahostsv4 "$HOST" >/dev/null; then
        SUCCESS "DNS resolved: $HOST"
    else
        WARNING "DNS not resolving: $HOST"
    fi
done

# ==========================================
# Create Application User
# ==========================================
INFO "Creating roboshop user"

if ! id roboshop &>/dev/null; then
    useradd --system \
        --home /app \
        --shell /sbin/nologin \
        --comment "roboshop system user" \
        roboshop
fi

SUCCESS "Roboshop user ready"

# ==========================================
# Download Application
# ==========================================
INFO "Downloading Payment Application"

mkdir -p /app

curl -fL \
    -o /tmp/payment.zip \
    "https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/payment-v4.zip"

cd /app

unzip -o /tmp/payment.zip

SUCCESS "Payment application downloaded"

# ==========================================
# Python Virtual Environment
# ==========================================
INFO "Creating Python virtual environment"

python3.14 -m venv /app/.venv

SUCCESS "Virtual environment ready"

# ==========================================
# Install Python Dependencies
# ==========================================
INFO "Installing Payment dependencies"

/app/.venv/bin/pip install -r /app/requirements.txt

SUCCESS "Payment dependencies installed"

# ==========================================
# Configure Payment Service
# ==========================================
INFO "Copying payment.service"

cp "$SERVICE_SOURCE" "$SERVICE_DEST"

INFO "Updating Route 53 DNS hostnames"

sed -i \
    -e "s|<CART-SERVER-IPADDRESS>|${CART_HOST}|g" \
    -e "s|<USER-SERVER-IPADDRESS>|${USER_HOST}|g" \
    -e "s|<RABBITMQ-SERVER-IPADDRESS>|${AMQP_HOST}|g" \
    "$SERVICE_DEST"

# Ensure no placeholders remain
if grep -q '<.*SERVER-IPADDRESS>' "$SERVICE_DEST"; then
    ERROR "Unresolved placeholders found in payment.service"
    exit 1
fi

# Validate systemd service syntax
systemd-analyze verify "$SERVICE_DEST"

SUCCESS "Payment service configured"

# ==========================================
# Application Permissions
# ==========================================
INFO "Setting application permissions"

chown -R roboshop:roboshop /app

SUCCESS "Application permissions updated"

# ==========================================
# Start Payment Service
# ==========================================
INFO "Starting Payment Service"

systemctl daemon-reload
systemctl enable payment
systemctl restart payment

SUCCESS "Systemd startup command completed"

# ==========================================
# Verify Service Status
# ==========================================
INFO "Checking Payment service status"

if systemctl is-active --quiet payment; then
    SUCCESS "Payment service is running"
else
    ERROR "Payment service failed"
    journalctl -u payment -n 30 --no-pager
    exit 1
fi

# ==========================================
# Health Check
# ==========================================
INFO "Checking Payment health API"

HEALTH_OK=false

for attempt in {1..5}
do
    if curl -fsS --max-time 10 \
        http://localhost:8080/health; then
        echo
        SUCCESS "Payment health API responded"
        HEALTH_OK=true
        break
    fi

    WARNING "Health check attempt $attempt failed"
    sleep 3
done

if [[ "$HEALTH_OK" != "true" ]]; then
    ERROR "Payment health API failed"
    journalctl -u payment -n 30 --no-pager
    exit 1
fi

# ==========================================
# Completed
# ==========================================
echo
SUCCESS "=========================================="
SUCCESS "Payment Installation Completed"
SUCCESS "=========================================="

show_execution_time
