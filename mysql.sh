#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script mysql
mysql_password=${MYSQL_ROOT_PASSWORD:-RoboShop@1}

run 'Enabling MySQL 8.4 module' dnf module enable mysql:8.4 -y
install_packages mysql-server
start_service mysqld
if mysql -uroot -p"$mysql_password" -e 'SELECT 1;' >> "$LOG_FILE" 2>&1; then
    info 'MySQL root password is already configured; skipping'
else
    run 'Configuring MySQL root users' mysql -uroot -e "
    ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysql_password';
    CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$mysql_password';
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;"
fi
run 'Verifying MySQL' mysql -uroot -p"$mysql_password" -e 'SELECT VERSION();'
