# PGSQL Auto Backup to S3

This project contains a Bash script to automate the backup of a PostgreSQL database and upload it to an Amazon S3 bucket compatible.

## Prerequisites

- PostgreSQL
- AWS CLI configured with appropriate permissions
- Bash

## Usage

1. Clone the repository:
    ```bash
    git clone https://github.com/Agaisme/AutoBackupSQLtoS3.git
    cd BackupDatabaseSQL
    ```

2. Make the script executable:
    ```bash
    chmod +x pgsql_backup.sh
    ```

3. Run the script:
    ```bash
    ./pgsql_backup.sh
    ```

## Configuration

Edit the `backup_to_s3.sh` script to set your PostgreSQL database credentials and S3 bucket details:
```bash
DB_NAME="your_database_name"
DB_USER="your_database_user"
S3_BUCKET="your_s3_bucket_name"
```
