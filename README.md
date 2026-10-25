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

## Daily log cleanup

Create the archive directory once:

```bash
sudo mkdir -p /var/log/roboshop-archives
```

Run cleanup manually:

```bash
sudo bash cleanup.sh /var/log/roboshop /var/log/roboshop-archives 14
```

The script finds `.log` files older than 14 days, creates one timestamped
`.tar.gz` archive, and deletes the source files only when compression succeeds.

For daily cleanup at 02:00 in the server's timezone, add with `sudo crontab -e`
after replacing `/opt/roboshop` with the actual Linux repository path:

```cron
0 2 * * * /bin/bash /opt/roboshop/cleanup.sh /var/log/roboshop /var/log/roboshop-archives 14 >> /var/log/roboshop-cleanup.log 2>&1
```

Use Bash, not `sh`, for all scripts.
