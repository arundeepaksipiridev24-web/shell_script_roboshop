#!/bin/bash

echo "Configuring MongoDB..."

# Copy repo file
cp mongo.repo /etc/yum.repos.d/mongo.repo

# Install MongoDB
dnf install mongodb-org -y

# Enable and start service
systemctl enable mongod
systemctl start mongod

# Allow remote connections
sed -i 's/127.0.0.1/0.0.0.0/' /etc/mongod.conf

# Restart MongoDB
systemctl restart mongod

# Verify
systemctl is-active mongod
ss -lntp | grep 27017

echo "MongoDB configuration completed"