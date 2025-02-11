#!/bin/bash

# CAREFULL THIS SCRIPT WILL DROP YOUR DB (PGSQL) AND NOT BACKUP THAT HAS ALREADY RUN

# Enable error handling
set -e  # Exit on first failure
trap 'echo "❌ An error occurred. Exiting..."; exit 1;' ERR

# Set Variables
CONTAINER_NAME="test-container-name-fdc766-db-1"
DB_NAME="namedb"
DB_USER="userdb"
BACKUP_FILE="db_2025-02-11_02-14-39.sql.gz"
TEMP_FILE="/tmp/$(basename "$BACKUP_FILE" .gz)"  # Extract filename without .gz

echo "🚀 Starting database restore..."

# Step 1: Check if the backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "❌ ERROR: Backup file '$BACKUP_FILE' not found!"
  exit 1
fi

# Step 2: Copy the backup file into the container
echo "📂 Copying backup file into container..."
docker cp "$BACKUP_FILE" "$CONTAINER_NAME:/tmp/"

# Step 3: Safely drop and recreate the database
echo "⚠️ Dropping and recreating database..."
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '$DB_NAME' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME OWNER $DB_USER;
" || { echo "❌ ERROR: Failed to drop and recreate database!"; exit 1; }

# Step 4: Unzip and restore the database using the dynamic temp filename
echo "📦 Restoring the database..."
docker exec -i "$CONTAINER_NAME" sh -c "gunzip -c /tmp/$BACKUP_FILE > $TEMP_FILE" || { echo "❌ ERROR: Failed to unzip backup file!"; exit 1; }
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$TEMP_FILE" || { echo "❌ ERROR: Database restore failed!"; exit 1; }

# Step 5: Verify the restore
echo "🔍 Verifying restoration..."
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "\dt" || { echo "❌ ERROR: Failed to verify tables!"; exit 1; }

# Step 6: Clean up temporary files
echo "🧹 Cleaning up..."
docker exec -i "$CONTAINER_NAME" rm "/tmp/$BACKUP_FILE" "$TEMP_FILE" || { echo "⚠️ WARNING: Cleanup failed, please remove files manually."; }

echo "✅ Database restoration complete!"
