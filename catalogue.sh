#!/bin/bash

APP_NAME=catalogue
DOMAIN_NAME=sodhichebutha.online
MONGODB_HOST="mongodb-${DOMAIN_NAME}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

LOGS_FOLDER="/tmp/roboshop-logs"
mkdir -p $LOGS_FOLDER

LOG_FILE=${LOGS_FOLDER}/${APP_NAME}-$(date +%F-%H-%M-%S).log

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOG() {
    echo -e "$(date '+%F %T') : $1"
}

STATUS_CHECK() {
    if [ $1 -eq 0 ]; then
        echo -e "${G}SUCCESS${N}"
    else
        echo -e "${R}FAILED${N}"
        echo "Check Log: $LOG_FILE"
        exit 1
    fi
}

LOG "Disable old NodeJS version"
dnf module disable nodejs -y &>>$LOG_FILE
STATUS_CHECK $?

LOG "Enable NodeJS 24"
dnf module enable nodejs:24 -y &>>$LOG_FILE
STATUS_CHECK $?

if node -v &>/dev/null; then
    LOG "NodeJS already installed - SKIPPING"
else
    LOG "Install NodeJS"
    dnf install nodejs -y &>>$LOG_FILE
    STATUS_CHECK $?
fi

id roboshop &>/dev/null

if [ $? -ne 0 ]; then
    LOG "Creating roboshop user"

    useradd --system \
        --home /app \
        --shell /sbin/nologin \
        --comment "roboshop system user" roboshop \
        &>>$LOG_FILE

    STATUS_CHECK $?
else
    LOG "roboshop user already exists - SKIPPING"
fi

LOG "Preparing application directory"

rm -rf /app
mkdir -p /app &>>$LOG_FILE

LOG "Downloading Catalogue Application"

curl -L -o /tmp/catalogue.zip \
https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/catalogue-v4.zip \
&>>$LOG_FILE

STATUS_CHECK $?

cd /app

unzip -o /tmp/catalogue.zip &>>$LOG_FILE
STATUS_CHECK $?

chown -R roboshop:roboshop /app

if [ -d "/app/node_modules" ]; then
    LOG "Dependencies already installed - SKIPPING"
else
    LOG "Installing Dependencies"
    npm install &>>$LOG_FILE
    STATUS_CHECK $?
fi

LOG "Copying Catalogue Service"

cp ${SCRIPT_DIR}/catalogue.service \
/etc/systemd/system/catalogue.service \
&>>$LOG_FILE

STATUS_CHECK $?

sed -i "s|MONGO_ENDPOINT|${MONGODB_HOST}|g" \
/etc/systemd/system/catalogue.service

STATUS_CHECK $?

if [ -f /etc/yum.repos.d/mongo.repo ]; then
    LOG "mongo.repo already exists - SKIPPING"
else
    LOG "Copying mongo.repo"

    cp ${SCRIPT_DIR}/mongo.repo \
    /etc/yum.repos.d/mongo.repo \
    &>>$LOG_FILE

    STATUS_CHECK $?
fi

if rpm -q mongodb-mongosh &>/dev/null; then
    LOG "Mongo Client already installed - SKIPPING"
else
    LOG "Installing Mongo Client"

    dnf install mongodb-mongosh -y \
    &>>$LOG_FILE

    STATUS_CHECK $?
fi

PRODUCT_COUNT=$(mongosh --host ${MONGODB_HOST} \
--quiet \
--eval 'db.getSiblingDB("catalogue").products.countDocuments()' 2>/dev/null)

if [ "$PRODUCT_COUNT" = "11" ]; then
    LOG "Catalogue Data already loaded - SKIPPING"
else
    LOG "Loading Catalogue Master Data"

    mongosh --host ${MONGODB_HOST} \
    </app/db/master-data.js \
    &>>$LOG_FILE

    STATUS_CHECK $?
fi

LOG "Starting Catalogue Service"

systemctl daemon-reload &>>$LOG_FILE
STATUS_CHECK $?

systemctl enable catalogue &>>$LOG_FILE
STATUS_CHECK $?

systemctl restart catalogue &>>$LOG_FILE
STATUS_CHECK $?

LOG "Catalogue Setup Completed"