#!/bin/bash

# Sample to sync a local chrony log file to an S3 bucket every 5 minutes.
# Sends the sync state to a new log location /var/log/s3-sync which is also added to logrotate

# Update the system
yum update -y

# Ensure cronie (the cron implementation) is installed
yum install -y cronie

# Ensure that cron is up and running
systemctl enable crond
systemctl start crond

# Create the log directory
mkdir -p /var/log/s3-sync

# Create the sync script
cat << 'EOF' > /usr/local/bin/s3-sync.sh
#!/bin/bash
LOG_DIR="/var/log/s3-sync"
PASS_LOG="${LOG_DIR}/sync_pass.log"
FAIL_LOG="${LOG_DIR}/sync_fail.log"


# Run the sync command
if aws s3 sync /var/log/chrony s3://someS3Bucket/chrony/ --exclude "*.tmp"; then
    echo "$(date): Sync successful" >> "$PASS_LOG"
else
    echo "$(date): Sync failed" >> "$FAIL_LOG"
fi
EOF

# Make the script executable
chmod +x /usr/local/bin/s3-sync.sh

# Add the sync command to cron to run every 5 minutes
echo "*/5 * * * * /usr/local/bin/s3-sync.sh" | crontab -

# Create logrotate configuration for s3-sync logs
cat << EOF > /etc/logrotate.d/s3-sync
/var/log/s3-sync/*.log {
    weekly
    rotate 4
    missingok
    notifempty
    compress
    delaycompress
    create 0644 root root
}
EOF

# Force logrotate to refresh its configuration
logrotate /etc/logrotate.conf --force

# Ensure AWS CLI is installed (if not already present)
if ! command -v aws &> /dev/null; then
    yum install -y awscli
fi
