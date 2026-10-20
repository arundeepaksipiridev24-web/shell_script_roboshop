#!/bin/bash

LOGS_FOLDER="/var/log/roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="$LOGS_FOLDER/$SCRIPT_NAME-$TIMESTAMP.log"

mkdir -p $LOGS_FOLDER

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

START_TIME=$(date)

echo "===================================" | tee -a $LOGFILE
echo "Execution Started : $START_TIME" | tee -a $LOGFILE
echo "Log File          : $LOGFILE" | tee -a $LOGFILE
echo "===================================" | tee -a $LOGFILE

check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "$2 ... ${G}SUCCESS${N}"
    else
        echo -e "$2 ... ${R}FAILURE${N}"
        echo "Check Log File: $LOGFILE"
        exit 1
    fi
}

USER_ID=$(id -u)

if [ $USER_ID -ne 0 ]; then
    echo -e "${R}ERROR:${N} Please run this script as root user"
    exit 1
fi

echo -e "${Y}MongoDB Configuration Started${N}"

cp mongo.repo /etc/yum.repos.d/mongo.repo &>>$LOGFILE
check_status $? "Copying MongoDB Repo"

dnf install mongodb-org -y &>>$LOGFILE
check_status $? "Installing MongoDB"

systemctl enable mongod &>>$LOGFILE
check_status $? "Enabling MongoDB"

systemctl start mongod &>>$LOGFILE
check_status $? "Starting MongoDB"

sed -i 's/127.0.0.1/0.0.0.0/' /etc/mongod.conf &>>$LOGFILE
check_status $? "Updating MongoDB Listen Address"

systemctl restart mongod &>>$LOGFILE
check_status $? "Restarting MongoDB"

systemctl is-active mongod &>>$LOGFILE
check_status $? "Verifying MongoDB Service"

END_TIME=$(date)

echo "===================================" >> $LOGFILE
echo "Execution Completed : $END_TIME" >> $LOGFILE
echo "===================================" >> $LOGFILE

echo -e "${G}MongoDB Configuration Completed Successfully${N}"
echo -e "${Y}Log File:${N} $LOGFILE"