#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/$(basename "$0").log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access.."
    exit 1
fi

mkdir -p $logs_folder

timestamp(){
    date "+%F %T"
}

validate(){
    if [ $1 -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}..${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${2}..${G}SUCCESS${N}" | tee -a $logs_file
    fi
}

echo "$(timestamp) [INFO] ==== Script started Execution =====" | tee -a $logs_file

dnf module disable nginx -y &>>$logs_file

dnf module enable nginx:1.26 -y &>>$logs_file

dnf install nginx unzip -y &>>$logs_file

validate $? "Installing Nginx"

systemctl enable nginx &>>$logs_file
systemctl start nginx &>>$logs_file

validate $? "Starting Nginx"

rm -rf /usr/share/nginx/html/*

validate $? "Removing Default Website"

curl -L -o /tmp/frontend.zip \
https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/frontend-v4.zip \
&>>$logs_file

validate $? "Downloading Frontend"

cd /usr/share/nginx/html

unzip -o /tmp/frontend.zip &>>$logs_file

validate $? "Extracting Frontend"

cp roboshop.conf /etc/nginx/default.d/roboshop.conf &>>$logs_file

validate $? "Copying Nginx Config"

nginx -t &>>$logs_file

validate $? "Validating Nginx Config"

systemctl restart nginx &>>$logs_file

validate $? "Restarting Nginx"

echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file