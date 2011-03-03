#!/bin/sh
#
# Script for backup MySQL databases in crontab
# Tested on ubuntu +10.04 LTS
# 
# Created by Jesper Grann Laursen, powerlauer AT gmail DOT com
# https://github.com/lauer/scripts/blob/master/mysql/backupDatabases.sh
#
# configfile
config=/etc/backupDatabases.conf

### Example of configfile
###
## backuppath
# backupdir='/backup/mysql'
## database informations
# DBuser='backup'
# DBpass='backup'
###
### End of configfile

# Errorvalue
error=0

# day of week
date=$(date +%Y%m%d)
datetime="$date.$(date +%H%M%S)"

# load configfile
if [ -f $config ]; then
	. $config
else
	echo ""
	echo "Error: Need config file: $config"
	echo ""
	exit 1
fi

# Setupcheck
if [ -z "$backupdir" -o -z "$DBuser" -o -z "$DBpass" -o ! -d "$backupdir" ]; then
    echo "Error: Remember to setup the username, password and path to backup"
    exit 1
fi

DBlogin="--user=$DBuser --password=$DBpass"
DBoptions="--opt --hex-blob --force"
dblist=`echo show databases\; | mysql $DBlogin | /usr/bin/tail -n +2 | grep -v information_schema` 
logfile=$backupdir/backup.$datetime.log

# clean from old stopped backup
rm -f $backupdir/inprogress/*
rm -f $backupdir/backup.*.log

echo -n "Backup started: " > $logfile
date >> $logfile
echo "" >> $logfile

# clean old backups (more than 7 days old)
oldbackuplist=`find $backupdir/* -type d -mtime +7`
for olddir in $oldbackuplist
do
	echo ""
	echo "Deleting: $olddir" >> $logfile
	rm -f $olddir/*
	rmdir $olddir 2>> $logfile 
done

mkdir -p $backupdir/inprogress
for dbname in $dblist 
do 
    echo "Backing up $dbname " >> $logfile
    echo " $(date +%H:%M:%S) - Dump cycle" >> $logfile
    mysqldump $DBoptions $DBlogin $dbname > $backupdir/inprogress/${dbname}.$datetime.sql 2>> $logfile
    if [ $? -eq 0 ]; then
    	echo " $(date +%H:%M:%S) - Compression Cycle" >> $logfile
    	gzip $backupdir/inprogress/${dbname}.$datetime.sql >/dev/null 2>&1
    	echo " $(date +%H:%M:%S) - $dbname finished!" >> $logfile
    else
      echo " $(date +%H:%M:%S) - Failed to make dump! ($dbname)" >> $logfile
      error=1
    fi		
    echo "" >> $logfile
done

echo "Moving compressed files into $date" >> $logfile
echo "" >> $logfile
mkdir -p $backupdir/$date
mv $backupdir/inprogress/*.gz $backupdir/$date

echo -n "Backup ended: " >> $logfile
date >> $logfile
mv $logfile $backupdir/$date
rmdir $backupdir/inprogress

if [ $error -eq 1 ]; then
		echo "Error: Some databases were not completed!"
		echo "See logfile: $backupdir/$date/$(basename $logfile)"
    exit 1
fi
