#!/bin/bash
# Backup and save data on rsync daemon server via rsync. This script should be placed at source server where data need to backup.
# 25/06/2018 - ntv1090@gmail.com

RSYNC_DAEMON_SERVER="125.212.217.193"
REMOTE_MODULE_NAME="SERVER57"
BANDWIDTH_LIMIT="200000"
SOURCE_DIR="/home/"
DB_DIR="$SOURCE_DIR/dbdump"
BACKUP_AGENT_LOG="/var/log/backup-agent.log"
BACKUP_MYSQL="yes"
BACKUP_MONGO="no"
BACKUP_PERCONA_XTRABACKUP="no"

# Enable debug bash shell
set -xv

# Check rsync is available
[[ -z $(which rsync) ]] && echo "Error: rsync command not found !" && exit 1

# Check server load
if [[ `cat /proc/loadavg | awk -F. {'print $1'}` -gt 9 ]]; then
	echo "Info: Server is under hight load... pause script 300s " >> $BACKUP_AGENT_LOG
	sleep 300
fi

# Dump database
[[ ! -d $DB_DIR ]] && mkdir -p $DB_DIR 
if [[ $BACKUP_MYSQL == "yes" ]]; then
	echo "----- $(date): Begin dump mysql database" >> $BACKUP_AGENT_LOG
	dblists=`mysql --defaults-extra-file=/root/.my.cnf -Bse 'show databases'`
	if [[ -z $dblists ]]; then 
		echo "Warning: No database found. MySQL is not running" >> $BACKUP_AGENT_LOG
	else
		for db in $dblists; do
			mysqldump --defaults-extra-file=/root/.my.cnf --single-transaction --complete-insert $db | gzip -9 > $DB_DIR/$db.`date +"%Y-%m-%d"`.sql.gz && echo "Info: Backup database $db success !" >> $BACKUP_AGENT_LOG || echo "Warning: Dump database $db to fail !" >> $BACKUP_AGENT_LOG
		done
	fi
	echo "----- $(date): End dump mysql database" >> $BACKUP_AGENT_LOG
fi

# Backup source code and database to rsync daemon server
echo "----- $(date): Begin transfer data to rsync daemon server" >> $BACKUP_AGENT_LOG
rsync -avr --progress --delete --bwlimit=$BANDWIDTH_LIMIT --link-dest "../001" $SOURCE_DIR $RSYNC_DAEMON_SERVER::$REMOTE_MODULE_NAME/000
# Remove db dump file
find $DB_DIR -type f -name "*.sql.gz" -delete
echo "----- $(date): End transfer data to rsync daemon server" >> $BACKUP_AGENT_LOG
