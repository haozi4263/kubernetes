#!/bin/bash
exec_shell=/shell/rotate.sh
touch $exec_shell
echo '#!/bin/bash' >> $exec_shell
echo 'process_time="235959"' >> $exec_shell
# process_time=235959
echo 'while true ; do ' >> $exec_shell
echo '   now_date=$(date "+%H%M%S") '>> $exec_shell
echo '   if [ $now_date = "$process_time" ]; then ' >> $exec_shell
echo '     mv /var/log/nginx/access.log /var/log/nginx/access.log.1' >> $exec_shell
echo '     kill -USR1 `cat /run/nginx.pid` ' >> $exec_shell
echo '   fi' >> $exec_shell
echo '   sleep 1s' >> $exec_shell
echo 'done' >> $exec_shell
chmod 777 $exec_shell
nohup $exec_shell > /dev/null  2>&1 &
exit 0
