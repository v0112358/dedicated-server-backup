#!/bin/bash
# Script backup all database MySQL

DES_DIR="/home/backup/data/database"
TODAY="$(date +"%Y-%m-%d")"
KEEP_BK=7

[ ! -d $DES_DIR ] && mkdir -p $DES_DIR
#Remove old backup
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

#Backup all database MySQL

mkdir -p $DES_DIR/$TODAY

dblist=`mysql --defaults-extra-file=/root/.my.cnf -Bse 'show databases' | grep -v eximstats`

array_db=( $dblist )

echo "" >> /var/log/backupd.log

echo ==============BEGIN BACKUP DATABASE `date` ================== >> /var/log/backupd.log

for((i=0;i<${#array_db[@]};i++))

do
        dbname=${array_db[$i]}
                [ `cat /proc/loadavg |awk -F. {'print $1'}` -gt 16 ] && sleep 300 && echo "Hight load... sleep 300s " >> /var/log/backupd.log
        mysqldump --defaults-extra-file=/root/.my.cnf --complete-insert $dbname  | gzip -9 > $DES_DIR/$TODAY/$dbname.`date +"%Y-%m-%d"`.sql.gz && echo Success backup database $dbname on `date` >> /var/log/backupd.log || echo Failse backup database $dbname on `date` >> /var/log/backupd.log

done
echo ==============END BACKUP DATABASE `date` ==================== >> /var/log/backupd.log
