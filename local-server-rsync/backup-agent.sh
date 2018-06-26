#!/bin/bash
# Backup and save data on local storage via rsync. This script should be placed at source server where data need to backup.
# 25/06/2018 - ntv1090@gmail.com

BANDWIDTH_LIMIT="200000"
SOURCE_DIR="/home/"
DEST_DIR="/backup-rsync/data"
DB_DIR="$SOURCE_DIR/dbdump"
BACKUP_AGENT_LOG="/var/log/backup-agent.log"
BACKUP_MYSQL="yes"
BACKUP_MONGO="no"
BACKUP_PERCONA_XTRABACKUP="no"
REVISION_COUNT=7
REVISION_DIR_DIGITS=3

# Enable debug bash shell
set -xv

function padRevisionDirPart {
	 printf "%0${REVISION_DIR_DIGITS}d" "$1"
}

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

# Backup source code and database to $DEST_DIR
[[ ! -d $DEST_DIR ]] && mkdir -p $DEST_DIR 
echo "----- $(date): Begin save backup" >> $BACKUP_AGENT_LOG
rsync -avr --progress --delete --bwlimit=$BANDWIDTH_LIMIT --link-dest "../001" $SOURCE_DIR $DEST_DIR/000

# Remove db dump file
find $DB_DIR -type f -name "*.sql.gz" -delete
echo "----- $(date): End save backup" >> $BACKUP_AGENT_LOG

# Rotate backup
# Remove oldest backup
echo "----- $(date): Begin rotate backup" >> $BACKUP_AGENT_LOG
revisionDirRegexp="^[0-9]{${REVISION_DIR_DIGITS}}$"
IFS=$'\n'
for backupBaseDir in $(ls -1 "$DEST_DIR/."); do
	revisionDir="$DEST_DIR/$backupBaseDir"

	# skip anything not a directory or not exactly three digits
	if [[
		(! -d $revisionDir) ||
		(! $backupBaseDir =~ $revisionDirRegexp)
	]]; then
		continue
	fi

	# convert to revision integer
	revision=$((10#$backupBaseDir))

	# above revision retention count?
	if [[ $revision -ge $REVISION_COUNT ]]; then
		# drop revision outside range
		chmod --recursive u+w "$revisionDir"
		rm --force --recursive "$revisionDir"
		echo "Info: Removed revision [$revisionDir]" >> $BACKUP_AGENT_LOG
	fi
done

unset IFS

revision=$REVISION_COUNT
while [[ $revision -gt 0 ]]; do
	((revision--))
	revisionDir="$DEST_DIR/$(padRevisionDirPart $revision)"

	if [[ -d $revisionDir ]]; then
		revisionDirNext="$DEST_DIR/$(padRevisionDirPart $(($revision + 1)))"
		mv "$revisionDir" "$revisionDirNext"

		echo "Moved [$revisionDir] -> [$revisionDirNext]" >> $BACKUP_AGENT_LOG
	fi
done
echo "----- $(date): End rotate backup" >> $BACKUP_AGENT_LOG
