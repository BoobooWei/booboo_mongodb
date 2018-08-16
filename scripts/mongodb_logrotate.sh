#!/bin/bash
# 2017/12/15 Apple
#Rotate the MongoDB logs to prevent a single logfile from consuming too much disk space.

cmd=mongod
mongodpath=/opt/mongodb/bin
pidarray=`pidof ${mongodpath}/$cmd`
LOGPATH_SHARD=/data/mongodb/shard1/logs

for pid in $pidarray;do
if [ $pid ]
then
kill -SIGUSR1 $pid
fi
done
#clear logfile more than 7 days
cd $LOGPATH_SHARD
find ./ -xdev -mtime +7 -name "shard.log.*" -exec rm -f {} \;