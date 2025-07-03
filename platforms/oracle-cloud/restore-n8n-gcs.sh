#!/bin/bash

# remember to make the script executable 
# chmod +x ~/restore-n8n-gcs.sh

# --- Configuration ---
N8N_DIR="/home/ubuntu/n8n" # Path to your n8n Docker Compose directory
BACKUP_DIR="${N8N_DIR}/backups" # Directory to store local backups temporarily
GCS_BUCKET="gs://n8n-backups-dalenguyen-prod" # CHANGE THIS to your GCS bucket name
BACKUP_PREFIX="n8n_backup" # Prefix for your backup files

# --- Pre-checks ---
echo "Checking environment..."
echo "Current PATH: $PATH"
echo "Current shell: $SHELL"
echo "Script interpreter: $0"

# Function to find Docker (sh-compatible)
find_docker() {
    # Try common Docker locations
    if [ -x "/usr/bin/docker" ]; then
        echo "/usr/bin/docker"
        return 0
    fi
    
    if [ -x "/usr/local/bin/docker" ]; then
        echo "/usr/local/bin/docker"
        return 0
    fi
    
    if [ -x "/opt/homebrew/bin/docker" ]; then
        echo "/opt/homebrew/bin/docker"
        return 0
    fi
    
    # Try which command if available
    if command -v which >/dev/null 2>&1; then
        DOCKER_PATH=$(which docker 2>/dev/null)
        if [ -n "$DOCKER_PATH" ] && [ -x "$DOCKER_PATH" ]; then
            echo "$DOCKER_PATH"
            return 0
        fi
    fi
    
    return 1
}

# Find Docker
DOCKER_CMD=$(find_docker)
if [ -z "$DOCKER_CMD" ]; then
    echo "Error: Docker is not installed or not accessible."
    echo "Tried to find Docker in: /usr/bin/docker, /usr/local/bin/docker, /opt/homebrew/bin/docker, and PATH"
    echo "Please ensure Docker is installed and accessible."
    exit 1
else
    echo "Found Docker at: $DOCKER_CMD"
fi

# Check gsutil
if ! command -v gsutil &> /dev/null; then
    echo "Error: gsutil (Google Cloud SDK) is not installed or not in PATH."
    echo "Current PATH: $PATH"
    exit 1
else
    echo "Found gsutil at: $(which gsutil)"
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# --- Functions ---

# Function to list available backups
list_backups() {
    echo "Available backups in GCS bucket ${GCS_BUCKET}:"
    echo "----------------------------------------"
    
    # Get list of backups from GCS
    BACKUP_LIST=$(gsutil ls "${GCS_BUCKET}/${BACKUP_PREFIX}_*.tar.gz" 2>/dev/null | sort -r)
    
    if [ -z "$BACKUP_LIST" ]; then
        echo "No backups found in GCS bucket."
        return 1
    fi
    
    # Display backups with numbers
    local count=1
    echo "$BACKUP_LIST" | while read -r backup; do
        if [ -n "$backup" ]; then
            # Extract filename from full path
            filename=$(basename "$backup")
            # Extract date from filename (format: n8n_backup_YYYYMMDD_HHMMSS.tar.gz)
            date_part=$(echo "$filename" | sed 's/n8n_backup_\([0-9]\{8\}\)_\([0-9]\{6\}\)\.tar\.gz/\1 \2/')
            formatted_date=$(echo "$date_part" | awk '{print substr($1,1,4) "-" substr($1,5,2) "-" substr($1,7,2) " " substr($2,1,2) ":" substr($2,3,2) ":" substr($2,5,2)}')
            echo "$count. $filename ($formatted_date)"
            count=$((count + 1))
        fi
    done
    
    echo ""
    return 0
}

# Function to get backup by number
get_backup_by_number() {
    local backup_number=$1
    
    # Get list of backups
    BACKUP_LIST=$(gsutil ls "${GCS_BUCKET}/${BACKUP_PREFIX}_*.tar.gz" 2>/dev/null | sort -r)
    
    if [ -z "$BACKUP_LIST" ]; then
        echo "No backups found in GCS bucket."
        return 1
    fi
    
    # Get the nth backup
    local count=1
    echo "$BACKUP_LIST" | while read -r backup; do
        if [ -n "$backup" ]; then
            if [ "$count" -eq "$backup_number" ]; then
                echo "$backup"
                return 0
            fi
            count=$((count + 1))
        fi
    done
    
    return 1
}

# Function to confirm restore
confirm_restore() {
    local backup_file=$1
    local filename=$(basename "$backup_file")
    
    echo ""
    echo "⚠️  WARNING: This will overwrite your current n8n data!"
    echo "Current data will be replaced with: $filename"
    echo ""
    echo "Are you sure you want to proceed? (yes/no)"
    read -r response
    
    if [ "$response" != "yes" ]; then
        echo "Restore cancelled."
        exit 0
    fi
    
    echo "Proceeding with restore..."
}

# --- Main Script ---

echo "=== n8n Restore Script ==="
echo ""

# Check if backup file is provided as argument
if [ $# -eq 1 ]; then
    BACKUP_FILE="$1"
    echo "Using provided backup file: $BACKUP_FILE"
else
    # List available backups
    if ! list_backups; then
        echo "No backups available. Please create a backup first."
        exit 1
    fi
    
    echo "Enter the number of the backup to restore (or 'q' to quit):"
    read -r backup_number
    
    if [ "$backup_number" = "q" ] || [ "$backup_number" = "Q" ]; then
        echo "Restore cancelled."
        exit 0
    fi
    
    # Validate input
    if ! [[ "$backup_number" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a number."
        exit 1
    fi
    
    # Get backup file by number
    BACKUP_FILE=$(get_backup_by_number "$backup_number")
    if [ -z "$BACKUP_FILE" ]; then
        echo "Invalid backup number."
        exit 1
    fi
    
    echo "Selected backup: $BACKUP_FILE"
fi

# Confirm restore
confirm_restore "$BACKUP_FILE"

# Extract filename for local use
BACKUP_FILENAME=$(basename "$BACKUP_FILE")
LOCAL_BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILENAME}"

echo "--- Starting n8n restore ---"

# --- Download backup from GCS ---
echo "Downloading backup from GCS..."
gsutil cp "$BACKUP_FILE" "$LOCAL_BACKUP_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download backup from GCS."
    exit 1
fi
echo "Backup downloaded: $LOCAL_BACKUP_PATH"

# --- Stop n8n and DB containers ---
echo "Stopping n8n and database containers..."
cd "$N8N_DIR" || { echo "Error: Could not change to n8n directory."; exit 1; }
"$DOCKER_CMD" compose stop || { echo "Error: Failed to stop Docker Compose services."; exit 1; }
echo "Containers stopped."

# --- Backup current data (safety measure) ---
echo "Creating safety backup of current data..."
SAFETY_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SAFETY_BACKUP="${BACKUP_PREFIX}_safety_${SAFETY_TIMESTAMP}.tar.gz"

if [ -d "n8n_data" ] || [ -d "pg_data" ]; then
    "$DOCKER_CMD" run --rm \
      -v "$(pwd)/n8n_data:/n8n_data:ro" \
      -v "$(pwd)/pg_data:/pg_data:ro" \
      -v "$(pwd)/backups:/backups" \
      alpine:latest \
      tar -czf "/backups/${SAFETY_BACKUP}" -C / n8n_data pg_data 2>/dev/null || echo "Warning: Could not create safety backup"
    echo "Safety backup created: $SAFETY_BACKUP"
fi

# --- Remove existing data directories ---
echo "Removing existing data directories..."
# Use Docker to remove directories to avoid permission issues
"$DOCKER_CMD" run --rm \
  -v "$(pwd):/workspace" \
  alpine:latest \
  sh -c "rm -rf /workspace/n8n_data /workspace/pg_data"
echo "Existing data removed."

# --- Extract backup ---
echo "Extracting backup archive..."
"$DOCKER_CMD" run --rm \
  -v "$(pwd):/workspace" \
  -v "$(pwd)/backups:/backups" \
  alpine:latest \
  tar -xzf "/backups/${BACKUP_FILENAME}" -C /workspace

if [ $? -eq 0 ]; then
    echo "Backup extracted successfully."
else
    echo "Error: Failed to extract backup archive."
    echo "Attempting to start containers with existing data..."
    "$DOCKER_CMD" compose start || { echo "Error: Failed to start Docker Compose services."; exit 1; }
    exit 1
fi

# --- Start n8n and DB containers ---
echo "Starting n8n and database containers..."
"$DOCKER_CMD" compose start || { echo "Error: Failed to start Docker Compose services."; exit 1; }
echo "Containers started."

# --- Clean up downloaded backup ---
echo "Cleaning up downloaded backup file..."
rm -f "$LOCAL_BACKUP_PATH"
echo "Cleanup complete."

echo "--- n8n restore process complete ---"
echo ""
echo "✅ Restore completed successfully!"
echo "📁 Restored from: $BACKUP_FILENAME"
echo "🔒 Safety backup: $SAFETY_BACKUP"
echo ""
echo "Your n8n instance should now be running with the restored data."
echo "You can access it at your usual n8n URL." 