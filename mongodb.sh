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
        exit 1
    fi
}

USER_ID=$(id -u)

if [ "$USER_ID" -ne 0 ]; then
    echo -e "${RED}Run this script as root user${NC}"
    exit 1
fi

START_TIME=$(date +%s)

log "MongoDB Configuration Started"

cp mongo.repo /etc/yum.repos.d/mongo.repo &>> "$LOGFILE"
check_status $? "Copying MongoDB Repo"

dnf install mongodb-org -y &>> "$LOGFILE"
check_status $? "Installing MongoDB"

systemctl enable mongod &>> "$LOGFILE"
check_status $? "Enabling MongoDB"

systemctl start mongod &>> "$LOGFILE"
check_status $? "Starting MongoDB"

sed -i 's/127.0.0.1/0.0.0.0/' /etc/mongod.conf &>> "$LOGFILE"
check_status $? "Updating Listen Address"

systemctl restart mongod &>> "$LOGFILE"
check_status $? "Restarting MongoDB"

systemctl is-active mongod &>> "$LOGFILE"
check_status $? "Verifying MongoDB Service"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

log "MongoDB Configuration Completed"
log "Total Execution Time : ${TOTAL_TIME} seconds"

echo -e "${GREEN}MongoDB Setup Completed Successfully${NC}"
echo -e "${YELLOW}Log File : ${LOGFILE}${NC}"