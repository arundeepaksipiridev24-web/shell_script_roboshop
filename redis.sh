#!/bin/bash

LOGS_FOLDER="/var/log/roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
TIMESTAMP=$(date +"%F-%H-%M-%S")
LOGFILE="$LOGS_FOLDER/$SCRIPT_NAME-$TIMESTAMP.log"

mkdir -p "$LOGS_FOLDER"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"

log() {
    echo "$(date '+%F %T') : $1" | tee -a "$LOGFILE"
}

check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "$(date '+%F %T') : $2 ... ${GREEN}SUCCESS${NC}"
        echo "$(date '+%F %T') : $2 ... SUCCESS" >> "$LOGFILE"
    else
        echo -e "$(date '+%F %T') : $2 ... ${RED}FAILURE${NC}"
        echo "$(date '+%F %T') : $2 ... FAILURE" >> "$LOGFILE"
        echo "Check Logs : $LOGFILE"
        exit 1
    fi
}

USER_ID=$(id -u)

if [ "$USER_ID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run this script as root user${NC}"
    exit 1
fi

START_TIME=$(date +%s)

log "Redis Configuration Started"

dnf module disable redis -y &>>"$LOGFILE"
check_status $? "Disabling Default Redis Module"

dnf module enable redis:7 -y &>>"$LOGFILE"
check_status $? "Enabling Redis 7 Module"

dnf install redis -y &>>"$LOGFILE"
check_status $? "Installing Redis"

sed -i \
-e 's/^bind 127.0.0.1/bind 0.0.0.0/' \
-e 's/^protected-mode yes/protected-mode no/' \
/etc/redis/redis.conf &>>"$LOGFILE"
check_status $? "Updating Redis Configuration"

systemctl enable redis &>>"$LOGFILE"
check_status $? "Enabling Redis Service"

systemctl start redis &>>"$LOGFILE"
check_status $? "Starting Redis Service"

redis-cli ping &>>"$LOGFILE"
check_status $? "Verifying Redis Connectivity"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME-START_TIME))

log "Redis Configuration Completed"
log "Total Execution Time : ${TOTAL_TIME} seconds"

echo -e "${GREEN}Redis Setup Completed Successfully${NC}"
echo -e "${YELLOW}Log File : ${LOGFILE}${NC}"