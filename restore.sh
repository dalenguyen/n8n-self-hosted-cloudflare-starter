#!/bin/bash

# n8n Restore Script
# This script safely restores n8n data from a backup file

# Configuration
BACKUP_DIR="./backups"
N8N_DATA_DIR="./n8n_data"

echo "🔄 n8n Restore Script"
echo "====================="

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Error: Backup directory not found at $BACKUP_DIR"
    echo "   Make sure you have created backups first using ./backup.sh"
    exit 1
fi

# List available backups
echo "📁 Available backups:"
ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null | nl

if [ $? -ne 0 ]; then
    echo "❌ No backup files found in $BACKUP_DIR"
    exit 1
fi

# Get backup file from user
echo ""
echo "Please enter the backup filename to restore (or press Enter for the latest):"
read -r BACKUP_FILE

# If no file specified, use the latest backup
if [ -z "$BACKUP_FILE" ]; then
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
    if [ -z "$BACKUP_FILE" ]; then
        echo "❌ No backup files found"
        exit 1
    fi
    echo "📦 Using latest backup: $(basename "$BACKUP_FILE")"
else
    # Check if the specified file exists
    if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        echo "❌ Error: Backup file $BACKUP_FILE not found"
        exit 1
    fi
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
fi

echo ""
echo "⚠️  WARNING: This will replace your current n8n data!"
echo "   Current data will be backed up as n8n_data_old"
echo ""

# Confirm restore
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Restore cancelled"
    exit 1
fi

echo "🛑 Stopping n8n container..."
docker-compose down

# Backup current data
if [ -d "$N8N_DATA_DIR" ]; then
    echo "💾 Backing up current data..."
    mv "$N8N_DATA_DIR" "${N8N_DATA_DIR}_old_$(date +%Y%m%d_%H%M%S)"
fi

# Extract backup
echo "📦 Extracting backup..."
tar -xzf "$BACKUP_FILE"

# Check if extraction was successful
if [ $? -eq 0 ]; then
    echo "✅ Backup restored successfully!"
    
    # Get restored data size
    RESTORED_SIZE=$(du -sh "$N8N_DATA_DIR" 2>/dev/null | cut -f1)
    echo "📊 Restored data size: $RESTORED_SIZE"
else
    echo "❌ Error: Failed to restore backup"
    exit 1
fi

echo ""
echo "🚀 Starting n8n container..."
docker-compose up -d

echo ""
echo "🎉 Restore completed successfully!"
echo "📋 Summary:"
echo "   - Restored from: $(basename "$BACKUP_FILE")"
echo "   - Data size: $RESTORED_SIZE"
echo "   - n8n container: Started"
echo ""
echo "🌐 Access your n8n instance at: http://localhost:5678" 