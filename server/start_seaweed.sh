#!/bin/bash
systemctl stop seaweedfs 2>/dev/null
pkill -9 -f weed 2>/dev/null
sleep 2
nohup /usr/local/bin/weed server -ip=0.0.0.0 -ip.bind=0.0.0.0 -filer -s3 -s3.port=9000 -s3.config=/etc/seaweedfs/s3.json /var/lib/seaweedfs > /tmp/seaweed.log 2>&1 &
echo $! > /tmp/seaweed.pid
sleep 10
ss -ltnp | grep -E "9000|8888|19333|9333"
