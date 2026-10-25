# RoboShop scripts

All service installers use `common.sh` for colors, logging, error handling,
package installation, runtime setup, application downloads, user creation and
systemd operations. Each service script contains only its own configuration.

Run the required script from this directory on its dedicated server:

```bash
sudo bash catalogue.sh
sudo bash shipping.sh
```

Logs are written to `/var/log/roboshop`. `DOMAIN_NAME` and `LOG_DIR` can be
overridden through environment variables.

## Archive logs older than 14 days

Install ZIP on the Linux host:

```bash
sudo dnf install -y zip
```

Archive the logs:

```bash
sudo bash archive-logs.sh
```

The script finds `.log` files older than 14 days in `/var/log/roboshop`, creates
a ZIP in `/var/log/roboshop-archives`, and removes the log only when ZIP creation
succeeds.

Custom paths and retention (including catalogue's older log location):

```bash
sudo bash archive-logs.sh /tmp/roboshop-logs /var/log/catalogue-archives 14
```

For daily cleanup at 02:00 in the server's timezone, add with `sudo crontab -e`
after replacing `/opt/roboshop` with the actual Linux repository path:

```cron
0 2 * * * /bin/bash /opt/roboshop/archive-logs.sh >> /var/log/roboshop-archive.log 2>&1
```

Use Bash, not `sh`, for all scripts.
