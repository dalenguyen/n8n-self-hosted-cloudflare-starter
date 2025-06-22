#!/bin/bash

# n8n Backup Script
# This script creates a compressed backup of the n8n_data directory
# and automatically cleans up old backups to save disk space

# Configuration
BACKUP_DIR="./backups"
N8N_DATA_DIR="./n8n_data"
MAX_BACKUPS=7  # Keep only the last 7 backups

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp for backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="n8n_backup_${TIMESTAMP}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILENAME"

echo "🚀 Starting n8n backup..."

# Check if n8n_data directory exists
if [ ! -d "$N8N_DATA_DIR" ]; then
    echo "❌ Error: n8n_data directory not found at $N8N_DATA_DIR"
    echo "   Make sure you're running this script from the project root directory"
    exit 1
fi

# Create backup
echo "📦 Creating backup: $BACKUP_FILENAME"
tar -czf "$BACKUP_PATH" -C . n8n_data

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "✅ Backup created successfully: $BACKUP_PATH"
    
    # Get backup size
    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    echo "📊 Backup size: $BACKUP_SIZE"
else
    echo "❌ Error: Failed to create backup"
    exit 1
fi

# Clean up old backups (keep only the last MAX_BACKUPS)
echo "🧹 Cleaning up old backups (keeping last $MAX_BACKUPS)..."
cd "$BACKUP_DIR"
ls -tp | grep -v '/$' | tail -n +$((MAX_BACKUPS + 1)) | xargs -I {} rm -- {}

# Count remaining backups
REMAINING_BACKUPS=$(ls -1 *.tar.gz 2>/dev/null | wc -l)
echo "📁 Remaining backups: $REMAINING_BACKUPS"

echo "🎉 Backup process completed successfully!"
echo ""
echo "📋 Backup summary:"
echo "   - Backup file: $BACKUP_PATH"
echo "   - Backup size: $BACKUP_SIZE"
echo "   - Total backups kept: $REMAINING_BACKUPS"
echo ""
echo "💡 To restore from this backup, use:"
echo "   tar -xzf $BACKUP_PATH" 