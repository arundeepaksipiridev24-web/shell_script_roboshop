#!/bin/bash
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

init_script shipping
mysql_host="mysql.$DOMAIN_NAME"

install_java
create_app_user
download_app shipping
run 'Building shipping application' mvn -f "$APP_DIR/pom.xml" clean package
run 'Installing shipping package' mv "$APP_DIR/target/shipping.jar" "$APP_DIR/shipping.jar"
run 'Loading shipping master data' bash -c "mysql -h '$mysql_host' -uroot -pRoboShop@1 < '$APP_DIR/db/master-data.sql'"
run 'Creating shipping database user' bash -c "mysql -h '$mysql_host' -uroot -pRoboShop@1 < '$APP_DIR/db/app-user.sql'"
run 'Setting application ownership' chown -R "$APP_USER:$APP_USER" "$APP_DIR"
install_service shipping
run 'Configuring service endpoints' sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" /etc/systemd/system/shipping.service
start_service shipping
