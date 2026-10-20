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

validate() {
    if [ $1 -eq 0 ]; then
        echo -e "$(date '+%F %T') : $2 ... ${GREEN}SUCCESS${NC}"
        echo "$(date '+%F %T') : $2 ... SUCCESS" >> "$LOGFILE"
    else
        echo -e "$(date '+%F %T') : $2 ... ${RED}FAILURE${NC}"
        echo "$(date '+%F %T') : $2 ... FAILURE" >> "$LOGFILE"
        echo "Refer Log File : $LOGFILE"
        exit 1
    fi
}

USER_ID=$(id -u)

if [ "$USER_ID" -ne 0 ]; then
    echo -e "${RED}Run this script as root user${NC}"
    exit 1
fi

START_TIME=$(date +%s)

log "RabbitMQ Configuration Started"

cp rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo &>>"$LOGFILE"
validate $? "Copying RabbitMQ Repo"

dnf install erlang rabbitmq-server -y &>>"$LOGFILE"
validate $? "Installing Erlang and RabbitMQ"

systemctl enable rabbitmq-server &>>"$LOGFILE"
validate $? "Enabling RabbitMQ Service"

systemctl start rabbitmq-server &>>"$LOGFILE"
validate $? "Starting RabbitMQ Service"

rabbitmqctl add_user roboshop roboshop123 &>>"$LOGFILE"
validate $? "Creating RabbitMQ User"

rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>>"$LOGFILE"
validate $? "Setting Permissions"

rabbitmqctl list_users &>>"$LOGFILE"
validate $? "Verifying RabbitMQ Users"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME-START_TIME))

log "RabbitMQ Configuration Completed"
log "Total Execution Time : ${TOTAL_TIME} Seconds"

echo -e "${GREEN}RabbitMQ Setup Completed Successfully${NC}"
echo -e "${YELLOW}Log File : $LOGFILE${NC}"