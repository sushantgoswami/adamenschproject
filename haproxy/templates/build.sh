#!/bin/bash

BALANCE_MEM_PATH=/home/BetterAdmin/balance_member

#################################################
>/tmp/balance_member.txt

for i in `ls $BALANCE_MEM_PATH`
 do
  HOSTNAME=`echo $BALANCE_MEM_PATH/$i | awk -F '/' '{print $NF}'`
  IPADDR=`cat $BALANCE_MEM_PATH/$i`
  PING_CHK=`ping -c 1 $IPADDR | grep "1 received" | wc -l`
  if [ $PING_CHK == 0 ]; then
   echo "#---------------------------------------------------------------"
   echo "Node $HOSTNAME $IPADDR is not reachable, please evict the node later from $BALANCE_MEM_PATH. Currently the script will not add this node for load balancing."
  else
   echo "#---------------------------------------------------------------"
   echo "Node $HOSTNAME $IPADDR added for load balancing" 
   echo $HOSTNAME $IPADDR >> /tmp/balance_member.txt
  fi
 done

sleep 1
echo "#---------------------------------------------------------------#"
echo "#---------------------------------------------------------------#"
echo "##### haproxy-main.cfg #####" > /etc/haproxy/templates/haproxy-main.cfg.backend.runtime
echo "##### haproxy-main.reverse.cfg #####" > /etc/haproxy/templates/haproxy-main.reverse.cfg.backend.runtime
echo "##### haproxy-shadow.cfg #####" > /etc/haproxy/templates/haproxy-shadow.cfg.backend.runtime
echo "##### haproxy-shadow.reverse.cfg #####" > /etc/haproxy/templates/haproxy-shadow.reverse.cfg.backend.runtime

while read -r line;
 do
 echo "    server $line:8080 check" >> /etc/haproxy/templates/haproxy-main.cfg.backend.runtime
 echo "    server $line:8081 check" >> /etc/haproxy/templates/haproxy-main.cfg.backend.runtime_1
 echo "    server $line:8081 check" >> /etc/haproxy/templates/haproxy-main.reverse.cfg.backend.runtime
 echo "    server $line:8080 check" >> /etc/haproxy/templates/haproxy-main.reverse.cfg.backend.runtime_1
 
 echo "    server $line:8081 check" >> /etc/haproxy/templates/haproxy-shadow.cfg.backend.runtime
 echo "    server $line:8080 check" >> /etc/haproxy/templates/haproxy-shadow.cfg.backend.runtime_1
 echo "    server $line:8080 check" >> /etc/haproxy/templates/haproxy-shadow.reverse.cfg.backend.runtime
 echo "    server $line:8081 check" >> /etc/haproxy/templates/haproxy-shadow.reverse.cfg.backend.runtime_1
 done < /tmp/balance_member.txt

echo "Node configuration are created, please verify the nodes below"
for i in `ls /etc/haproxy/templates/*.runtime`
 do
  echo "#---------------------------------------------------------------#"
  cat $i
  echo "#---------------------------------------------------------------#"
 done

read -p "Are you sure to contineu with the current configuration: type yes/no: " ANS

if [ $ANS == "yes" ]; then
 for i in haproxy-main.cfg haproxy-main.reverse.cfg
  do
   cat /etc/haproxy/templates/$i.tpl > /etc/haproxy/templates/$i
   cat /etc/haproxy/templates/$i.frontend >> /etc/haproxy/templates/$i
   cat /etc/haproxy/templates/$i.backend >> /etc/haproxy/templates/$i
   cat /etc/haproxy/templates/$i.backend.runtime >> /etc/haproxy/templates/$i
   cat /etc/haproxy/templates/$i.backend_1 >> /etc/haproxy/templates/$i
   cat /etc/haproxy/templates/$i.backend.runtime_1 >> /etc/haproxy/templates/$i
  done
fi
echo "#---------------------------------------------------------------#"
echo "haproxy configuration files are created, do you want to merge the files to the main configuration"
echo "#---------------------------------------------------------------#"
read -p "Are you sure to contineu with the merging: type yes/no: " ANS

if [ $ANS == "yes" ]; then
 CURRENT_DATE=`date | awk '{print $3"-"$2"-"$6"-"$4"-"$5}'`
 mkdir /etc/haproxy/backup/config-$CURRENT_DATE
 mv /etc/haproxy/haproxy-main.* /etc/haproxy/backup/config-$CURRENT_DATE/
 cp /etc/haproxy/templates/haproxy-main.cfg /etc/haproxy/
 cp /etc/haproxy/templates/haproxy-main.reverse.cfg /etc/haproxy/
 # cp /etc/haproxy/templates/haproxy-shadow.cfg /etc/haproxy/
 # cp /etc/haproxy/templates/haproxy-shadow.reverse.cfg /etc/haproxy/
 echo "#---------------------------------------------------------------#"
 echo "Configuration files are copied in to /etc/haproxy directory, do you want to reload the configuration"
 read -p "Are you sure to contineu with reload the configuration: type yes/no: " ANS
 if [ $ANS == "yes" ]; then
  echo "reloading configuration ........"
  echo "done ..."
 fi
fi

