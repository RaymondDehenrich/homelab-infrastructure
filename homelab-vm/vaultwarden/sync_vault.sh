#!/bin/bash

source .env

if [ -z "$MNT_PATH_TWO" ] || [ ! -d "$MNT_PATH_TWO" ]; then
  echo "Error: MNT_PATH_TWO is not set or doesn't exist"
  exit 1
fi

if [ -z "$MNT_PATH_ONE" ] || [ ! -d "$MNT_PATH_ONE" ]; then
  echo "Error: MNT_PATH_ONE is not set or doesn't exist"
  exit 1
fi

if mountpoint -q /mnt/turbo_backup && mountpoint -q /mnt/vault_backup && [ -d "$MNT_PATH_ONE" ] && [ -d "$MNT_PATH_TWO" ]; then
    MNT_ENABLED=true
else
    echo "ERROR: Backup drive not mounted. Skipping MNT sync but proceeding with local sync."
    MNT_ENABLED=false
fi


#Tell VPS to create a clean DB backup to avoid corruption
ssh -i $KEY_PATH $SOURCE_USER@$SOURCE_IP "sqlite3 ${SOURCE_PATH}db.sqlite3 '.backup ${SOURCE_PATH}db.sqlite3.bak'"

#Rsync
rsync -avz --delete -e "ssh -i $KEY_PATH" "$SOURCE_USER@$SOURCE_IP:$SOURCE_PATH" "$DEST_PATH"


if [ "$MNT_ENABLED" = true ]; then
    echo "Syncing Homelab Docker -> External Mount..."
    BACKUP_DATE=$(date +%Y-%m-%d)
    rsync -av "$DEST_PATH/" "$MNT_PATH_ONE/backup_$BACKUP_DATE/"
    rsync -av --no-perms --no-owner --no-group --delete "$DEST_PATH/" "$MNT_PATH_TWO/backup_$BACKUP_DATE/"

    find "$MNT_PATH_TWO" -maxdepth 1 -name "backup_*" -mtime +24 -exec rm -rf {} +
    find "$MNT_PATH_ONE" -maxdepth 1 -name "backup_*" -mtime +24 -exec rm -rf {} +

fi

echo "Vaultwarden sync completed at $(date)"
