#!/bin/bash

flag=$(systemctl status haproxy &> /dev/null;echo $?)

if [[ $flag != 0 ]];then
        echo "haproxy is down,close the keepalived"
        systemctl stop keepalived
fi
