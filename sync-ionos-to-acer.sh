#!/bin/bash
# Sync IONOS pre-prod-stage to acer-hl (make acer-hl identical to IONOS)

set -e  # Exit on any error

IONOS_HOST="deploy@ionos-4c8g"
ACER_HOST="deploy@acer-hl.local"
SYNC_PATH="/home/deploy/pre-prod-stage/"

echo "🔄 Syncing IONOS → acer-hl..."
echo "Source: $IONOS_HOST:$SYNC_PATH"
echo "Dest:   $ACER_HOST:$SYNC_PATH"
echo

# Test connectivity first
echo "🔍 Testing connectivity..."
ssh -o ConnectTimeout=5 $IONOS_HOST "echo 'IONOS connected ✅'" || { echo "❌ Cannot connect to IONOS"; exit 1; }
ssh -o ConnectTimeout=5 $ACER_HOST "echo 'acer-hl connected ✅'" || { echo "❌ Cannot connect to acer-hl"; exit 1; }

# Create temporary local sync directory
TEMP_DIR="/tmp/ionos-sync-$$"
mkdir -p "$TEMP_DIR"

# Show what would be synced (dry run)
echo
echo "📋 Preview (dry run) - downloading from IONOS:"
rsync -avz --delete --dry-run \
  --exclude='.env*' \
  --exclude='*.log' \
  --exclude='.git' \
  --exclude='node_modules' \
  $IONOS_HOST:$SYNC_PATH "$TEMP_DIR/"

echo
read -p "🤔 Proceed with actual sync? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Step 1: Downloading from IONOS..."
    rsync -avz --delete --progress \
      --exclude='.env*' \
      --exclude='*.log' \
      --exclude='.git' \
      --exclude='node_modules' \
      $IONOS_HOST:$SYNC_PATH "$TEMP_DIR/"
    
    echo "🚀 Step 2: Uploading to acer-hl..."
    # Ensure target directory exists on acer-hl
    ssh $ACER_HOST "mkdir -p $SYNC_PATH"
    
    rsync -avz --delete --progress \
      "$TEMP_DIR/" $ACER_HOST:$SYNC_PATH
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    echo "✅ Sync complete: IONOS → acer-hl"
else
    rm -rf "$TEMP_DIR"
    echo "❌ Sync cancelled"
fi