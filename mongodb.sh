#!/bin/bash

LOGFILE="/tmp/mongodb.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

check_status() {
  if [ $1 -eq 0 ]; then
    echo -e "$2 ... ${G}SUCCESS${N}"
  else
    echo -e "$2 ... ${R}FAILURE${N}"
    echo "Check Logs: $LOGFILE"
    exit 1
  fi
}

USER_ID=$(id -u)

if [ $USER_ID -ne 0 ]; then
  echo -e "${R}Please run this script as root user${N}"
  exit 1
fi

echo -e "${Y}Configuring MongoDB...${N}"

cp mongo.repo /etc/yum.repos.d/mongo.repo &>>$LOGFILE
check_status $? "Copying MongoDB Repo"

dnf install mongodb-org -y &>>$LOGFILE
check_status $? "Installing MongoDB"

systemctl enable mongod &>>$LOGFILE
check_status $? "Enabling MongoDB"

systemctl start mongod &>>$LOGFILE
check_status $? "Starting MongoDB"

sed -i 's/127.0.0.1/0.0.0.0/' /etc/mongod.conf &>>$LOGFILE
check_status $? "Configuring MongoDB Listen Address"

systemctl restart mongod &>>$LOGFILE
check_status $? "Restarting MongoDB"

systemctl is-active mongod &>>$LOGFILE
check_status $? "MongoDB Service Status"

echo -e "${G}MongoDB Configuration Completed Successfully${N}"
