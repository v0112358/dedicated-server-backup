#!/bin/bash
# Script backup

DES_DIR="/home/backup/data/source"
SOURCE_DIR="/abserver/www/"
TODAY="$(date +"%Y-%m-%d")"
CYCLE_BACKUP=1
LAST_DAY_BACKUP=`date -d "$CYCLE_BACKUP day ago" +'%Y-%m-%d'`
KEEP_BK=7

[ ! -d $DES_DIR ] && mkdir -p $DES_DIR
# Remove old backup
[ `cat /proc/loadavg |awk -F. {'print $1'}` -gt 16 ] && sleep 300 && echo "Hight load... sleep 300s " >> /var/log/backupd.log

list_bk_folder=`ls -l $DES_DIR | grep root | grep -v ./ | awk '{print$9}'`
array_bk_folder=( $list_bk_folder );

for (( i=0;i< ${#array_bk_folder[@]}; i++ ))

do
        stat11=`stat -c %Y $DES_DIR/${array_bk_folder[$i]}`
        array_bk_stat[$i]=$stat11
done
for ((i=0;i< ${#array_bk_stat[@]};i++))
do
        stat1=${array_bk_stat[$i]}
        for (( j=1; j < ${#array_bk_stat[@]}; j++ ))
        do
                stat2=${array_bk_stat[$j]}
                if [ $((stat1)) -lt $((stat2)) ];
                then
                         tempstring=$stat1
                         stat1=$stat2
                         stat2=$tempstring
                         array_bk_stat[$i]=$stat1
                         array_bk_stat[$j]=$stat2
                fi
        done

done
let "DELETE_BK=${#array_bk_stat[@]}-$KEEP_BK+1"

for ((i=0;i<$DELETE_BK;i++))

do
        for ((j=0;j<${#array_bk_stat[@]};j++))

        do
                stat1=`stat -c %Y $DES_DIR/${array_bk_folder[$i]}`
                stat2=${array_bk_stat[$j]}

                if [ $((stat2)) -eq $((stat1)) ];
                then
                        cd $DES_DIR
                        rm -rf ${array_bk_folder[$i]} && echo Remove ${array_bk_folder[$i]} backup directory completed `date` >> /var/log/backupd.log|| echo Failed to remove ${array_bk_folder[$i]} backup directory on `date` >> /var/log/backupd.log
                        break
                fi
        done
done
# Backup source website

echo "" >> /var/log/backupd.log
echo ==============BEGIN BACKUP SOURCE WEBSITE `date` ================== >> /var/log/backupd.log

#mkdir -p $DES_DIR/$TODAY

[ `cat /proc/loadavg |awk -F. {'print $1'}` -gt 16 ] && sleep 300 && echo "Hight load... sleep 300s " >> /var/log/backupd.log

if [ -d $DES_DIR/$LAST_DAY_BACKUP ] ; then

   cp -al $DES_DIR/$LAST_DAY_BACKUP $DES_DIR/$TODAY && echo Copy source last backup complete >> /var/log/backupd.log || echo Failed copy source last backup >> /var/log/backupd.log

fi

rsync -ar -H --delete --exclude 'backup' $SOURCE_DIR $DES_DIR/$TODAY/ && echo Backup $SOURCE complete `date` >> /var/log/backupd.log || echo Failed to backup $SOURCE directory on `date` >> /var/log/backupd.log


echo ==============END BACKUP `date` ==================== >> /var/log/backupd.log
