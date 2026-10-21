#!/bin/bash

source common.sh

APP_NAME=catalogue
DOMAIN_NAME=sodhichebutha.online
MONGODB_HOST="mongodb-${DOMAIN_NAME}"

# NodeJS

if node -v &>/dev/null; then
    LOG "NodeJS already installed - SKIPPING"
else
    LOG "Disable old NodeJS version"
    dnf module disable nodejs -y &>>$LOG_FILE
    STATUS_CHECK $?

    LOG "Enable NodeJS 24"
    dnf module enable nodejs:24 -y &>>$LOG_FILE
    STATUS_CHECK $?

    LOG "Install NodeJS"
    dnf install nodejs -y &>>$LOG_FILE
    STATUS_CHECK $?
fi

# Application Setup

APP_SETUP

# Dependencies

if [ -d "/app/node_modules" ]; then
    LOG "Node Modules already exist - SKIPPING"
else
    LOG "Install Catalogue Dependencies"
    cd /app
    npm install &>>$LOG_FILE
    STATUS_CHECK $?
fi

# Service File

if [ -f /etc/systemd/system/catalogue.service ]; then
    LOG "Catalogue Service already exists - SKIPPING"
else
    LOG "Copy Catalogue Service"
    cp ${SCRIPT_DIR}/catalogue.service \
    /etc/systemd/system/catalogue.service &>>$LOG_FILE
    STATUS_CHECK $?

    sed -i "s|MONGO_ENDPOINT|${MONGODB_HOST}|g" \
    /etc/systemd/system/catalogue.service

    STATUS_CHECK $?
fi

# Mongo Repo

if [ -f /etc/yum.repos.d/mongo.repo ]; then
    LOG "Mongo Repo already exists - SKIPPING"
else
    LOG "Copy Mongo Repo"
    cp ${SCRIPT_DIR}/mongo.repo \
    /etc/yum.repos.d/mongo.repo &>>$LOG_FILE
    STATUS_CHECK $?
fi

# Mongo Client

if rpm -q mongodb-mongosh &>/dev/null; then
    LOG "Mongo Client already installed - SKIPPING"
else
    LOG "Install Mongo Client"
    dnf install mongodb-mongosh -y &>>$LOG_FILE
    STATUS_CHECK $?
fi

# Load Data

PRODUCT_COUNT=$(mongosh --host ${MONGODB_HOST} \
--quiet \
--eval 'db.getSiblingDB("catalogue").products.countDocuments()' 2>/dev/null)

if [ "$PRODUCT_COUNT" = "11" ]; then
    LOG "Catalogue Data already loaded - SKIPPING"
else
    LOG "Loading Catalogue Master Data"

    mongosh --host ${MONGODB_HOST} \
    </app/db/master-data.js &>>$LOG_FILE

    STATUS_CHECK $?
fi

# SystemD

SYSTEMD_SETUP