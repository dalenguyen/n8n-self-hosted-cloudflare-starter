# n8n Backup & Restore Scripts for Google Cloud Storage

This directory contains automated backup and restore scripts for n8n instances running on Oracle Cloud Infrastructure, with Google Cloud Storage as the backup destination.

## Prerequisites

1. **Google Cloud Project:** You need an active Google Cloud project.

2. **Google Cloud Storage Bucket:** Create a GCS bucket where you want to store your backups (e.g., `n8n-backups-myproject`). Make sure the bucket name is globally unique.

3. **Service Account:** You'll need a Google Cloud Service Account with the necessary permissions to upload objects to your GCS bucket.

   - Go to **IAM & Admin > Service Accounts** in the GCP Console.
   - Click **"CREATE SERVICE ACCOUNT"**.
   - Give it a name (e.g., `n8n-backup-uploader`).
   - Grant it the `Storage Object Creator` (or `Storage Object User` for broader access, but `Creator` is usually sufficient for just uploading) role on your specific GCS bucket.
   - **Create a new JSON key** for this service account and download it. This file is your service account's credentials. **Keep this file extremely secure on your Oracle instance!** (e.g., save it as `/home/ubuntu/.gcp/n8n-backup-uploader-key.json`). Set strict permissions: `chmod 400 /home/ubuntu/.gcp/n8n-backup-uploader-key.json`.

4. **Google Cloud SDK (`gcloud` CLI) installed on your Oracle instance:**
   This allows you to use `gsutil` commands.

   ```bash
   # Add the gcloud CLI distribution URI as a package source
   echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

   # Import the Google Cloud public key
   curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

   # Update and install
   sudo apt update && sudo apt install google-cloud-cli -y
   ```

5. **Authenticate `gcloud` with your Service Account:**

   ```bash
   gcloud auth activate-service-account --key-file=/home/ubuntu/.gcp/n8n-backup-uploader-key.json
   ```

   This command will authenticate your `gcloud` CLI using the service account key. This authentication will persist for your user.

## Scripts Overview

### Backup Script (`backup-n8n-gcs.sh`)

- Creates compressed backups of n8n workflows and PostgreSQL data
- Uploads backups to Google Cloud Storage
- Includes automatic cleanup of old local and remote backups
- Uses Docker for permission-safe backup creation

### Restore Script (`restore-n8n-gcs.sh`)

- Lists available backups from Google Cloud Storage
- Allows interactive selection of backup to restore
- Creates safety backup before restoring
- Safely restores n8n data with proper error handling

## Setup Instructions

### 1. Configure the Scripts

Before using the scripts, update the configuration variables in both scripts:

```bash
# Edit backup script
nano backup-n8n-gcs.sh

# Edit restore script
nano restore-n8n-gcs.sh
```

Update these variables in both scripts:

- `N8N_DIR`: Path to your n8n Docker Compose directory (default: `/home/ubuntu/n8n`)
- `GCS_BUCKET`: Your GCS bucket name (default: `gs://n8n-backups-dalenguyen-prod`)
- `BACKUP_PREFIX`: Prefix for backup files (default: `n8n_backup`)

### 2. Make Scripts Executable

```bash
chmod +x backup-n8n-gcs.sh
chmod +x restore-n8n-gcs.sh
```

### 3. Test the Backup Script

Run the backup script manually to ensure it works:

```bash
./backup-n8n-gcs.sh
```

Check your GCS bucket in the GCP Console to verify the backup was uploaded successfully.

## Usage

### Manual Backup

```bash
# Run backup script
./backup-n8n-gcs.sh

# Or with bash explicitly
bash backup-n8n-gcs.sh
```

### Manual Restore

```bash
# Interactive mode (recommended)
./restore-n8n-gcs.sh

# Or specify a backup file directly
./restore-n8n-gcs.sh gs://your-bucket/n8n_backup_20250703_005316.tar.gz
```

### Automated Backups with Cron

Schedule automatic backups using cron:

1. **Open your crontab for editing:**

   ```bash
   crontab -e
   ```

2. **Add the cron job entry:**
   To run daily at **2:00 AM Toronto time**:

   ```cron
   # m h dom mon dow command
   0 2 * * * /home/ubuntu/n8n/backup-n8n-gcs.sh >> /var/log/n8n_backup.log 2>&1
   ```

   **Timezone Considerations:**

   - Cron jobs run based on the server's local timezone
   - Your Oracle instance in `ca-toronto-1` will likely default to UTC
   - If you want 2:00 AM Toronto time (EDT/EST), adjust the cron hour accordingly
   - Check your server's timezone: `timedatectl`
   - For Toronto time, consider using: `CRON_TZ=America/Toronto 0 2 * * * /home/ubuntu/n8n/backup-n8n-gcs.sh >> /var/log/n8n_backup.log 2>&1`

## Features

### Backup Script Features

- ✅ **Permission-safe**: Uses Docker to avoid file permission issues
- ✅ **Compressed backups**: Creates efficient tar.gz archives
- ✅ **Automatic cleanup**: Removes old local and remote backups
- ✅ **Error handling**: Graceful error recovery and logging
- ✅ **Environment detection**: Automatically finds Docker and gsutil

### Restore Script Features

- ✅ **Interactive selection**: Lists and selects backups by number
- ✅ **Safety backup**: Creates backup of current data before restore
- ✅ **Confirmation prompts**: Requires explicit confirmation before overwriting
- ✅ **Error recovery**: Attempts to restart containers if restore fails
- ✅ **Cleanup**: Removes temporary files after successful restore

## Important Considerations

### Environment Variables

Cron jobs run in a minimal environment. The scripts include robust environment detection for:

- Docker installation location
- gsutil availability
- PATH configuration

### Permissions

Ensure the user running the scripts has permissions to:

- Read/write to `n8n_data` and `pg_data` directories
- Write to the backup directory
- Execute `docker compose` commands
- Execute `gsutil` commands

### Logging

Always redirect cron output to a log file for debugging:

```bash
>> /var/log/n8n_backup.log 2>&1
```

### GCS Bucket Lifecycle Management

For more robust retention policies, configure [Object Lifecycle Management](https://cloud.google.com/storage/docs/managing-lifecycles) rules directly on your GCS bucket in the GCP Console. This is more reliable than script-based cleanup for complex retention rules.

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**: The scripts use Docker to avoid permission issues with PostgreSQL data directories.

2. **GCS Access Errors**: Ensure your service account has the correct permissions and is properly authenticated.

3. **Docker Not Found**: The scripts automatically detect Docker installation locations.

4. **Backup File Not Found**: Verify the GCS bucket name and ensure backups exist.

### Log Files

- Backup logs: `/var/log/n8n_backup.log`
- Check logs for detailed error information: `tail -f /var/log/n8n_backup.log`

This setup provides a complete disaster recovery solution for your n8n instance with automated backups and easy restore capabilities.
