#!/bin/bash
# Sync acer-hl pre-prod-stage to IONOS (make IONOS identical to acer-hl)

set -e  # Exit on any error

ACER_HOST="funhome@acer-hl.local"
IONOS_HOST="deploy@ionos-4c8g"
SYNC_PATH="/home/deploy/pre-prod-stage/"

echo "🔄 Syncing acer-hl → IONOS..."
echo "Source: $ACER_HOST:$SYNC_PATH"
echo "Dest:   $IONOS_HOST:$SYNC_PATH"
echo

# Test connectivity first
echo "🔍 Testing connectivity..."
ssh -o ConnectTimeout=5 $ACER_HOST "echo 'acer-hl connected ✅'" || { echo "❌ Cannot connect to acer-hl"; exit 1; }
ssh -o ConnectTimeout=5 $IONOS_HOST "echo 'IONOS connected ✅'" || { echo "❌ Cannot connect to IONOS"; exit 1; }

# Show what would be synced (dry run)
echo
echo "📋 Preview (dry run):"
rsync -avz --delete --dry-run \
  --exclude='.env*' \
  --exclude='*.log' \
  --exclude='.git' \
  --exclude='node_modules' \
  $ACER_HOST:$SYNC_PATH $IONOS_HOST:$SYNC_PATH

echo
read -p "🤔 Proceed with actual sync? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting sync..."
    rsync -avz --delete --progress \
      --exclude='.env*' \
      --exclude='*.log' \
      --exclude='.git' \
      --exclude='node_modules' \
      $ACER_HOST:$SYNC_PATH $IONOS_HOST:$SYNC_PATH
    echo "✅ Sync complete: acer-hl → IONOS"
else
    echo "❌ Sync cancelled"
fi