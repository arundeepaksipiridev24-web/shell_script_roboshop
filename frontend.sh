
#!/bin/sh

set -eu

# ==========================================
# Domain Configuration
# ==========================================
DOMAIN_NAME="sodhichebutha.online"

# ==========================================
# Colors
# ==========================================
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
N='\033[0m'

# ==========================================
# Paths and Logs
# ==========================================
LOG_DIR="/var/log/roboshop"
LOG_FILE="$LOG_DIR/frontend.log"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

START_TIME=$(date +%s)
START_DATE=$(date '+%F %T')

mkdir -p "$LOG_DIR"

timestamp() {
    date '+%F %T'
}

info() {
    printf "${B}%s [INFO] %s${N}\n" "$(timestamp)" "$1" | tee -a "$LOG_FILE"
}

success() {
    printf "${G}%s [SUCCESS] %s${N}\n" "$(timestamp)" "$1" | tee -a "$LOG_FILE"
}

error() {
    printf "${R}%s [ERROR] %s${N}\n" "$(timestamp)" "$1" | tee -a "$LOG_FILE"
}

# ==========================================
# Show Execution Time
# ==========================================
finish() {
    EXIT_CODE=$?

    END_TIME=$(date +%s)
    TOTAL_TIME=$((END_TIME - START_TIME))

    if [ "$EXIT_CODE" -eq 0 ]; then
        success "Frontend deployment completed"
    else
        error "Frontend deployment failed: exit $EXIT_CODE"
        tail -20 "$LOG_FILE"
    fi

    info "Start Time : $START_DATE"
    info "End Time   : $(timestamp)"
    info "Duration   : $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s"
    info "Log File   : $LOG_FILE"
}

trap finish EXIT

# Capture all command output in log file
exec >> "$LOG_FILE" 2>&1

# ==========================================
# Root Check
# ==========================================
if [ "$(id -u)" -ne 0 ]; then
    error "Run using sudo sh frontend.sh"
    exit 1
fi

info "=========================================="
info "Starting Frontend Installation"
info "Domain: $DOMAIN_NAME"
info "=========================================="

# ==========================================
# Install Nginx
# ==========================================
info "Installing Nginx and utilities"

dnf install -y nginx unzip curl

success "Nginx installed"

# ==========================================
# Download Frontend
# ==========================================
info "Downloading Frontend Application"

curl -fL --retry 3 \
    -o /tmp/frontend.zip \
    "https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/frontend-v4.zip"

success "Frontend downloaded"

# ==========================================
# Extract Frontend
# ==========================================
info "Extracting Frontend"

mkdir -p /usr/share/nginx/html

rm -rf /usr/share/nginx/html/*

unzip -o /tmp/frontend.zip -d /usr/share/nginx/html

success "Frontend extracted"

# ==========================================
# Configure Nginx
# ==========================================
info "Copying Nginx Configuration"

mkdir -p /etc/nginx/default.d

cp "$SCRIPT_DIR/roboshop.conf" \
    /etc/nginx/default.d/roboshop.conf

# Domain replacement
sed -i "s/sodhichebutha\.online/${DOMAIN_NAME}/g" \
    /etc/nginx/default.d/roboshop.conf

success "Nginx configuration copied"

# ==========================================
# Validate Nginx
# ==========================================
info "Validating Nginx Configuration"

nginx -t

success "Nginx configuration valid"

# ==========================================
# Start Nginx
# ==========================================
info "Starting Nginx"

systemctl enable nginx
systemctl restart nginx

if systemctl is-active --quiet nginx; then
    success "Nginx running"
else
    error "Nginx failed to start"
    exit 1
fi

# ==========================================
# Health Check
# ==========================================
info "Checking Frontend Health"

if curl -fsS --max-time 10 http://localhost/health; then
    success "Frontend health check passed"
else
    error "Frontend health check failed"
    exit 1
fi
