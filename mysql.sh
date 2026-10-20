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

MYSQL_ROOT_PASSWORD="RoboShop@1"

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

log "MySQL Configuration Started"

dnf module enable mysql:8.4 -y &>>"$LOGFILE"
check_status $? "Enabling MySQL 8.4 Module"

dnf install mysql-server -y &>>"$LOGFILE"
check_status $? "Installing MySQL Server"

systemctl enable mysqld &>>"$LOGFILE"
check_status $? "Enabling MySQL Service"

systemctl start mysqld &>>"$LOGFILE"
check_status $? "Starting MySQL Service"

mysql -uroot -e "
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
" &>>"$LOGFILE"

check_status $? "Configuring Root User Password"

mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT VERSION();" &>>"$LOGFILE"
check_status $? "Verifying MySQL Login"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

log "MySQL Configuration Completed"
log "Total Execution Time : ${TOTAL_TIME} seconds"

echo -e "${GREEN}MySQL Setup Completed Successfully${NC}"
echo -e "${YELLOW}Log File : ${LOGFILE}${NC}"