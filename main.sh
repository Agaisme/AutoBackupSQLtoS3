#!/bin/bash

# Enable error handling
set -euo pipefail

# Configuration
VM_NAME="VPS_MACHINE_NAME"
CONTAINER_NAME="my_postgres"
DB_NAME="your_database_name"
DB_USER="your_db_user"
BACKUP_DIR="/home/user/backups"
S3_BUCKET="s3://your-s3-bucket-name"
S3_ENDPOINT="https://your-custom-endpoint.com" 
DATE=$(date +'%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="${BACKUP_DIR}/${VM_NAME}_${DB_NAME}_${DATE}.sql.gz"
LOG_FILE="/var/log/pgsql_backup.log"

# Ensure backup directory exists (sudo only if needed)
if [ ! -d "$BACKUP_DIR" ]; then
    sudo mkdir -p "$BACKUP_DIR"
    sudo chown "$USER:$USER" "$BACKUP_DIR"
fi

# Function for logging with colors
log() {
    local COLOR=$1
    local MESSAGE=$2
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') - ${COLOR}${MESSAGE}\e[0m" | sudo tee -a "$LOG_FILE"
}

# Status messages
INFO="\e[34m[INFO]\e[0m"   # 🔵 Blue
SUCCESS="\e[32m[SUCCESS]\e[0m" # 🟢 Green
ERROR="\e[31m[ERROR]\e[0m"  # 🔴 Red

#  Step 1: Start Backup (Requires `sudo` for Docker)
log "$INFO" "Starting PostgreSQL backup from outside the container..."
sudo docker exec -t "$CONTAINER_NAME" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    log "$SUCCESS" "Backup successful: $BACKUP_FILE"
else
    log "$ERROR" "Backup failed!"
    exit 1
fi

# Step 2: Verify AWS Credentials Before Upload
log "$INFO" "Verify AWS S3 Credential..."
if ! aws s3 ls "$S3_BUCKET" --endpoint-url "$S3_ENDPOINT" > /dev/null 2>&1; then
    log "$ERROR" "AWS credentials not found or incorrect. S3 upload skipped!"
    exit 1
fi

# Step 3: Upload to S3 (No `sudo`, uses normal user credentials)
log "$INFO" "Uploading backup to S3 ($S3_ENDPOINT)..."

aws s3 cp "$BACKUP_FILE" "$S3_BUCKET/" --endpoint-url "$S3_ENDPOINT"

if [ $? -eq 0 ]; then
    log "$SUCCESS" "Backup uploaded successfully to S3."
else
    log "$ERROR" "S3 upload failed!"
    exit 1
fi

# Step 4: Cleanup Old Backups
log "$INFO" "Cleaning up old backups (older than 30 days)..."

# Count matching files before deletion
OLD_BACKUPS=$(find "$BACKUP_DIR" -type f -mtime +30 -name "*.sql.gz" | wc -l)

if [ "$OLD_BACKUPS" -gt 0 ]; then
    sudo find "$BACKUP_DIR" -type f -mtime +30 -name "*.sql.gz" -delete
    log "$SUCCESS" "$OLD_BACKUPS old backups deleted."
else
    log "$INFO" "No old backups found. Skipping deletion."
fi

# Step 5: Backup Completed
log "$SUCCESS" "Backup process completed."
