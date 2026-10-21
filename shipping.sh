#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/$(basename "$0").log"
domain_name="sodhichebutha.online"
scripts_dir=$(dirname "$(realpath "$0")")

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

dnf module enable maven:3.9 -y &>>$logs_file
dnf install maven java-25-openjdk-devel unzip mysql -y &>>$logs_file
validate $? "Installing Java 25 and Maven"

alternatives --set java /usr/lib/jvm/java-25-openjdk/bin/java &>>$logs_file

echo "export JAVA_HOME=\$(dirname \$(dirname \$(readlink -f /usr/bin/java)))" \
>/etc/profile.d/java.sh

source /etc/profile.d/java.sh

validate $? "Configuring JAVA_HOME"

java -version &>>$logs_file
mvn -v &>>$logs_file

id roboshop &>>$logs_file

if [ $? -ne 0 ]; then
    useradd --system \
    --home /app \
    --shell /sbin/nologin \
    --comment "roboshop system user" roboshop \
    &>>$logs_file

    validate $? "Creating roboshop user"
else
    echo -e "$(timestamp) [INFO] roboshop user already exists...${Y}SKIPPING${N}"
fi

rm -rf /app

mkdir -p /app
validate $? "Creating App Directory"

curl -L -o /tmp/shipping.zip \
https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/shipping-v4.zip \
&>>$logs_file

validate $? "Downloading Shipping"

cd /app

unzip -o /tmp/shipping.zip &>>$logs_file
validate $? "Extracting Shipping"

mvn clean package &>>$logs_file
validate $? "Building Shipping Package"

mv target/shipping.jar shipping.jar &>>$logs_file
validate $? "Creating shipping.jar"

LOGICAL_HOST=mysql.${domain_name}

mysql -h ${LOGICAL_HOST} -uroot -pRoboShop@1 \
</app/db/master-data.sql \
&>>$logs_file

validate $? "Loading Master Data"

mysql -h ${LOGICAL_HOST} -uroot -pRoboShop@1 \
</app/db/app-user.sql \
&>>$logs_file

validate $? "Creating Shipping User"

sed -i "s/DOMAIN_NAME/${domain_name}/g" \
"${scripts_dir}/shipping.service"

cp "${scripts_dir}/shipping.service" \
/etc/systemd/system/shipping.service

validate $? "Copying Shipping Service"

systemctl daemon-reload &>>$logs_file
systemctl enable shipping &>>$logs_file
systemctl restart shipping &>>$logs_file

validate $? "Starting Shipping Service"

echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file