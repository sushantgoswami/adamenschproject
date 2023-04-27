#!/bin/bash

#-------------------------------------------------------------------------------
#- Original Author...: Sushant Goswami
#- Creation Date.....: 10 Feb 2023
#- Purpose...........: Script is intended to deploy the code	
#-------------------------------------------------------------------------------
# description: deploy_new_code.sh
#-------------------------------------------------------------------------------                                                                                          
############### User defines Variables ##############

GIT_USER=teknozest
GIT_TOKEN=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
GIT_PULL_URL="https://$GIT_USER:$GIT_TOKEN@github.com/datechadmin/damenschstorefront.git"
BRANCH_NAME="main"

APPUSER=BetterAdmin
APP_DATA_DIR=damenschstorefront
TEST_URL="http://beta-test.damensch.com:8443" ##check the port 8443 should be open if you are testing from outside##
SITE=damensch.com
BETASITE=beta-damensch.com
BETA_CHECK_URL="https://haproxy.beta-damensch.com:9443/stats_main"
MAIN_CHECK_URL="https://haproxy.damensch.com:9443/stats_main"
LOGFILE0=/var/log/damensch_0.log

############################# Do not Edit below, use Variables above #############################

Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
ENDCOLOR='\033[0m'        # No Color

RAND01=`od -vAn -N4 -tu4 < /dev/urandom | cut -c 3,4,5,6,7,8`

echo "$0: script initiated" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0

HAPROXY_MAIN_STATUS=`ps -ef | grep "/usr/sbin/haproxy" | grep -v grep | grep -v reverse | wc -l`
HAPROXY_REVERSE_STATUS=`ps -ef | grep "/usr/sbin/haproxy" | grep -v grep | grep reverse | wc -l`
echo "#------------------------------------------------------------------------------------------#"
if [ $USER == "$APPUSER" ]; then
 echo -e "${Green} User is $APPUSER not root, proceeding ...${ENDCOLOR}"
else
 echo -e "${Red} You must run this script using $APPUSER user ${ENDCOLOR}"
 exit 0;
fi
echo "#------------------------------------------------------------------------------------------#"
if [ $HAPROXY_MAIN_STATUS == 4 ]; then
 echo -e "${Green} The haproxy loadbalancer is running on SLOT 01 (main), means the main website in running from SLOT 01 ${ENDCOLOR}"
else
 echo -e "${Red} The haproxy loadbalancer is running on SLOT 02 (shadow), means the main website in running from SLOT 02 ${ENDCOLOR}"
fi
echo "#------------------------------------------------------------------------------------------#"

#------------------------------------------------------------------------------------------#
copy_on_slot02()
{
 echo "copying the code to SLOT 02"
 rm -rf /home/$APPUSER/$APP_DATA_DIR-shadow
 cp -rfp /home/$APPUSER/$APP_DATA_DIR /home/$APPUSER/$APP_DATA_DIR-shadow
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    ssh $IP '/home/$USER/stop-shadow.sh'
    ssh $IP 'rm -rf /home/$USER/damenschstorefront-shadow'
    rsync -arp /home/$APPUSER/$APP_DATA_DIR-shadow $IP:/home/$APPUSER
    timeout 3s ssh $IP '/home/$USER/start-shadow.sh'
    sleep 2
    echo "Code copy to $IP is done"
   else
    echo "Ping to $IP is unreachable, hence not copied files to $IP node"
   fi
  done
  echo "Code copy completed on all nodes. You can now switch the slots using "sudo /etc/init.d/haproxy_admin script""
  echo "$0: ran copy_on_slot02" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
}
#------------------------------------------------------------------------------------------#
copy_on_slot01()
{
 echo "copying the code to SLOT 01"
 rm -rf /home/$APPUSER/$APP_DATA_DIR-main
 cp -rfp /home/$APPUSER/$APP_DATA_DIR /home/$APPUSER/$APP_DATA_DIR-main
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    ssh $IP '/home/$USER/stop-main.sh'
    ssh $IP 'rm -rf /home/$USER/damenschstorefront-main'
    rsync -arp /home/$APPUSER/$APP_DATA_DIR-main $IP:/home/$APPUSER
    timeout 3s ssh $IP '/home/$USER/start-main.sh'
    sleep 2
    echo "Code copy to $IP is done"
   else
    echo "Ping to $IP is unreachable, hence not copied files to $IP node"
   fi
  done
   echo "Code copy completed on all nodes. You can now switch the slots using "sudo /etc/init.d/haproxy_admin script""
   echo "$0: ran copy_on_slot01" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
}
#------------------------------------------------------------------------------------------#

pull_git()
{
LASTCODE=`cat /home/$APPUSER/$APP_DATA_DIR/revision_no.txt`
echo "-----------------------------------------------------------------------"
echo "The Current compiled code revision no. on Jumpserver is:"
echo "-----------------------------------------------------------------------"
echo "$LASTCODE"
echo "-----------------------------------------------------------------------"
echo "The Current source uncompiled code revision no. on GITHUB is:"
echo "-----------------------------------------------------------------------"
git ls-remote $GIT_PULL_URL refs/heads/main
echo -e "${Yellow}-----------------------------------------------------------------------"
echo "Script will download the new or existing code from GIT and re compile it in $APP_DATA_DIR, give no if you"
echo "want to push existing compiled in $APP_DATA_DIR folder codes to attached nodes or other options"
echo "-----------------------------------------------------------------------"
echo "Yes -> To copy the code from GITHUB and remove the existing code in $APP_DATA_DIR folder"
echo "No or Any other input -> To proceed with the existing compiled code in the $APP_DATA_DIR folder"
echo "-----------------------------------------------------------------------"
echo -e "${ENDCOLOR}"
read -p "Enter your Input (yes/no): " ANSWER

if [ $ANSWER == "yes" ]; then
 echo "Proceeding with yes ..., downloading fresh code from GIT"
 echo "-----------------------------------------------------------------------"
 cd /home/$APPUSER
 if [ -d $APP_DATA_DIR ]; then
  echo "Removing: existing $APP_DATA_DIR Directory"
  rm -rf $APP_DATA_DIR
 fi
 echo "###############################################################################################################"
 echo "We are now able to pull the code, you can mention the branch name"
 echo "###############################################################################################################"
 read -p "Please enter the branch Name: " BRANCH_NAME
 git clone -b $BRANCH_NAME $GIT_PULL_URL
 if [ -d $APP_DATA_DIR ]; then
  cd $APP_DATA_DIR
 else
  echo "Git is not able to pull $APP_DATA_DIR directory, Exitting.."
  exit 0;
 fi
 git ls-remote $GIT_PULL_URL refs/heads/main > revision_no.txt

 echo "###############################################################################################################"
 echo "#--Please Enter the env file name for the compilation--#"
 echo "#--Below env files are present in the git code--#"
 echo "###############################################################################################################"
 ls -l .env.*
 echo "###############################################################################################################"
 read -p "Enter the filename: " ENV01
 if [ -f $ENV01 ]; then
  cp $ENV01 .env
 else
  echo "$ENV01 file not found in pulled git code"
  exit 0;
 fi

 echo "Running: npm install --force"
 npm install --force | tee -a /tmp/npm-install-log-$RAND01.txt
 echo "Running: npm run build"
 npm run build | tee -a /tmp/npm-run-build-log-$RAND01.txt
 echo "-----------------------------------------------------------------------"
 echo "Completed: run build - Check for errors. Install and log files are created and located in /tmp/npm-install-log-$RAND01.txt and /tmp/npm-run-build-log-$RAND01.txt"
 echo "-----------------------------------------------------------------------"
 echo "$0: pull_git completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
fi

if [ $ANSWER == "no" ]; then
 echo "Proceeding with no ..., continue with existing code in $APP_DATA_DIR"
 echo "-----------------------------------------------------------------------"
 cd $APP_DATA_DIR
 echo "###############################################################################################################"
 echo "#--Please Enter the env file name for the compilation--#"
 echo "#--Below env files are present in the git code--#"
 echo "###############################################################################################################"
 ls -l .env.*
 echo "###############################################################################################################"
 read -p "Enter the filename: " ENV01
 if [ -f $ENV01 ]; then
  cp $ENV01 .env
 else
  echo "$ENV01 file not found in pulled git code"
  exit 0;
 fi

 echo "Running: npm install --force"
 npm install --force | tee -a /tmp/npm-install-log-$RAND01.txt
 echo "Running: npm run build"
 npm run build | tee -a /tmp/npm-run-build-log-$RAND01.txt
 echo "-----------------------------------------------------------------------"
 echo "Completed: run build - Check for errors. Install and log files are created and located in /tmp/npm-install-log-$RAND01.txt and /tmp/npm-run-build-log-$RAND01.txt"
 echo "-----------------------------------------------------------------------"
 echo "$0: no pull_git completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
fi

if [ $ANSWER != "yes" ] || [ $ANSWER != "no" ]; then
 echo "No Answer found in code downloading or existing compilation change. Proceeding with deployment..."
fi

echo -e "${Yellow}"
echo "###############################################################################################################"
echo "The Script can try to bring the app in test URL on $TEST_URL                          ##"
echo "###############################################################################################################"
echo "## yes - To bring up the app on test URL $TEST_URL, to exit from nodeJS logs press control + c one time only"
echo "## No - To contineu without testing the application on $TEST_URL"
echo "###############################################################################################################"
echo -e "${ENDCOLOR}"
read -p "Enter your Input yes/no: " INPUT
if [ $INPUT == "yes" ]; then
 echo "Proceeding with yes ..., trying to bring up the application on $TEST_URL"
 echo "press control + C only one time to stop the nodejs testing and back to script"
 cd /home/$APPUSER/$APP_DATA_DIR
 npm start -- --port=8443
fi

echo "---------------------------------------------------------------------"
if [ $HAPROXY_MAIN_STATUS = 4 ]; then
 echo "The haproxy loadbalancer main website $SITE is running on SLOT 01 (main)"
 echo "Do you want to copy the code in $APP_DATA_DIR to all nodes to SLOT 02 (yes/no)"
fi

if [ $HAPROXY_REVERSE_STATUS = 4 ]; then
 echo "The haproxy loadbalancer main website $SITE is running on SLOT 02 (shadow)"
 echo "Do you want to copy the code in $APP_DATA_DIR to all nodes to SLOT 01 (yes/no)"
fi
echo "---------------------------------------------------------------------"

read -p "Enter your Input yes/no: " INPUT

if [ $INPUT == "yes" ]; then
 echo "Proceeding with yes ..."
else
 echo "Exiting the script"
 exit 0;
fi

if [ $HAPROXY_MAIN_STATUS = 4 ]; then
 LASTCODE=`cat /home/$APPUSER/$APP_DATA_DIR-shadow/revision_no.txt`
 echo "Current compiled code on SLOT 02 (shadow)"
 echo "---------------------------------------------------------------------"
 echo "$LASTCODE"
 echo "---------------------------------------------------------------------"
 echo "Do you want to continue"
 read -p "Enter your Input yes/no: " INPUT
 if [ $INPUT == "yes" ]; then
  echo "Proceeding with yes ..."
 else
  echo "Exiting the script"
  exit 0;
 fi
 copy_on_slot02
fi

if [ $HAPROXY_REVERSE_STATUS = 4 ]; then
 LASTCODE=`cat /home/$APPUSER/$APP_DATA_DIR-main/revision_no.txt`
 echo "Current compiled code on SLOT 01 (main)"
 echo "---------------------------------------------------------------------"
 echo "$LASTCODE"
 echo "---------------------------------------------------------------------"
 echo "Do you want to continue"
 read -p "Enter your Input yes/no: " INPUT
 if [ $INPUT == "yes" ]; then
  echo "Proceeding with yes ..."
 else
  echo "Exiting the script"
  exit 0;
 fi
 copy_on_slot01
fi
}

copy_code_single_slot01()
{
 echo -e "Task: copying the code to "${Green}"SLOT 01 (main)"${ENDCOLOR}" on single node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where source need to re-deploy"
  read -p "Enter the IP: " COPYIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   ssh $COPYIP '/home/$USER/stop-main.sh'
   ssh $COPYIP 'rm -rf /home/$USER/damenschstorefront-main'
   rsync -arp /home/$APPUSER/$APP_DATA_DIR-main $COPYIP:/home/$APPUSER
   timeout 3s ssh $COPYIP '/home/$USER/start-main.sh'
   sleep 2
   echo "Code copy to $COPYIP is done, check url http://haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: copy_code_single_slot01 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}

copy_code_single_slot02()
{
 echo -e "Task: copying the code to "${Red}"SLOT 02 (shadow)"${ENDCOLOR}" on single node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where source need to re-deploy"
  read -p "Enter the IP: " COPYIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   ssh $COPYIP '/home/$USER/stop-shadow.sh'
   ssh $COPYIP 'rm -rf /home/$USER/damenschstorefront-shadow'
   rsync -arp /home/$APPUSER/$APP_DATA_DIR-shadow $COPYIP:/home/$APPUSER
   timeout 3s ssh $COPYIP '/home/$USER/start-shadow.sh'
   sleep 2
   echo "Code copy to $COPYIP is done, check url http://beta-haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: copy_code_single_slot02 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}

restart_nodejs_single_slot01()
{
echo -e "Task: Restart the code to "${Green}"SLOT 01 (main)"${ENDCOLOR}" on single node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where nodejs need to restart"
  read -p "Enter the IP: " NODEIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   ssh $NODEIP '/home/$USER/stop-main.sh'
   timeout 3s ssh $NODEIP '/home/$USER/start-main.sh'
   sleep 2
   echo "Restart hodejs service to $NODEIP is done, check url http://beta-haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: restart_nodejs_single_slot01 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
  menu
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}

restart_nodejs_single_slot02()
{
echo -e "Task: Restart the code to "${Red}"SLOT 02 (shadow)"${ENDCOLOR}" on single node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where nodejs need to restart"
  read -p "Enter the IP: " NODEIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   ssh $NODEIP '/home/$APPUSER/stop-shadow.sh'
   timeout 3s ssh $NODEIP '/home/$APPUSER/start-shadow.sh'
   sleep 2
   echo "Restart hodejs service to $NODEIP is done, check url http://haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: restart_nodejs_single_slot02 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
   menu
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}

restart_nodejs_all_slot01()
{
echo -e "Task: Restart the code to "${Green}"SLOT 01 (main)"${ENDCOLOR}" on all node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
    echo "Do you want to continue yes/no"
    read -p "Enter the input: " INPUT
    if [ $INPUT == "yes" ]; then
     ssh $IP '/home/$USER/stop-main.sh'
     timeout 3s ssh $IP '/home/$USER/start-main.sh'
     echo "Restart hodejs service to $IP is done, check url $BETA_CHECK_URL or $MAIN_CHECK_URL"
     echo "$0: restart_nodejs_all_slot01 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
    fi
   fi
  done
}

restart_nodejs_all_slot02()
{
        echo -e "Task: Restart the code to "${Red}"SLOT 02 (shadow)"${ENDCOLOR}" on all node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
    echo "Do you want to continue yes/no"
    read -p "Enter the input: " INPUT
    if [ $INPUT == "yes" ]; then
     ssh $IP '/home/$USER/stop-shadow.sh'
     timeout 3s ssh $IP '/home/$USER/start-shadow.sh'
     echo "Restart hodejs service to $IP is done, check url $BETA_CHECK_URL or $MAIN_CHECK_URL"
     echo "$0: restart_nodejs_all_slot02 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
    fi
   fi
  done
}

start_nodejs_single_slot01()
{
echo -e "Task: Start Nodejs to "${Green}"SLOT 01 (main)"${ENDCOLOR}" on single node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where nodejs need to restart"
  read -p "Enter the IP: " NODEIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   timeout 3s ssh $NODEIP '/home/$USER/start-main.sh'
   sleep 2
   echo "Start hodejs service to $NODEIP is done, check url http://haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: start_nodejs_single_slot01 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
   menu
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}

start_nodejs_single_slot02()
{
echo -e "Task: Start Nodejs to "${Red}"SLOT 02 (main)"${ENDCOLOR}" on single node"
 for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where nodejs need to restart"
  read -p "Enter the IP: " NODEIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   timeout 3s ssh $NODEIP '/home/$USER/start-shadow.sh'
   sleep 2
   echo "Start hodejs service to $NODEIP is done, check url http://haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: start_nodejs_single_slot02 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
   menu
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}

stop_nodejs_single_slot01()
{
echo -e "Task: Stop Nodejs to "${Green}"SLOT 01 (main)"${ENDCOLOR}" on single node"
  for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where nodejs need to stop"
  read -p "Enter the IP: " NODEIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   timeout 3s ssh $NODEIP '/home/$USER/stop-main.sh'
   sleep 2
   echo "Stop hodejs service to $NODEIP is done, check url http://haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: stop_nodejs_single_slot01 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
   menu
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}

stop_nodejs_single_slot02()
{
echo -e "Task: Stop Nodejs to "${Red}"SLOT 02 (shadow)"${ENDCOLOR}" on single node"
  for i in `ls /home/$APPUSER/balance_member`
  do
   IP=`cat /home/$APPUSER/balance_member/$i`
   PING_CHK=`ping -c 1 $IP | grep "1 received" | wc -l`
   if [ $PING_CHK != 0 ]; then
    echo "Found node IP: $IP"
   fi
  done
  echo "Paste the node IP where nodejs need to stop"
  read -p "Enter the IP: " NODEIP
  echo "Do you want to continue yes/no"
  read -p "Enter the input: " INPUT
  if [ $INPUT == "yes" ]; then
   timeout 3s ssh $NODEIP '/home/$USER/stop-shadow.sh'
   sleep 2
   echo "Stop hodejs service to $NODEIP is done, check url http://haproxy.b-events.co.uk/stats_main or http://beta-haproxy.b-events.co.uk/stats_main"
   echo "$0: stop_nodejs_single_slot02 completed" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $LOGFILE0
   menu
  else
   echo "no input found as yes, exitting to main menu"
   menu
  fi
}


redeploy_beta()
{
 echo "code is in progress"
}

menu()
{
echo -e "${Yellow}"
echo -e "#########################################################################"
echo -e "##  New Deployment Script for the code - Version .02 26-mar-23         ##"
echo -e "#########################################################################"
echo -e "##   1.   Start the script (code compile and deployment)               ##"
echo -e "##   2.   Change the env file to beta and re-deploy (after swap slots) ##"
echo -e "##   3.   More options                                                 ##"
echo -e "##   ==========Any other key will Quit the script==========            ##"
echo -e "#########################################################################"${ENDCOLOR}""
read -p "  Enter your Input : " INPUT
if [ $INPUT == "1" ]; then
 pull_git
fi
if [ $INPUT == "2" ]; then
 redeploy_beta
fi
if [ $INPUT == "3" ]; then
 submenu01
else
 echo "Exitting the script..."
 exit 0;
fi
}

submenu01()
{
echo -e "#########################################################################"
if [ $HAPROXY_MAIN_STATUS == 4 ]; then
 echo -e "${Green} The haproxy loadbalancer is running on SLOT 01 (main), means the main website in running from SLOT 01 ${ENDCOLOR}"
else
 echo -e "${Red} The haproxy loadbalancer is running on SLOT 02 (shadow), means the main website in running from SLOT 02 ${ENDCOLOR}"
fi
echo -e "#########################################################################"
echo -e "##   3.   Redeploy the source code on single node on "${Green}"SLOT 01"${ENDCOLOR}"           ##"
echo -e "##   4.   Redeploy the source code on single node on "${Red}"SLOT 02"${ENDCOLOR}"           ##"
echo -e "##   5.   Restart the Nodejs service on single node on "${Green}"SLOT 01"${ENDCOLOR}"         ##"
echo -e "##   6.   Restart the Nodejs service on single node on "${Red}"SLOT 02"${ENDCOLOR}"         ##"
echo -e "##   7.   Stop the Nodejs service on single node on "${Green}"SLOT 01"${ENDCOLOR}"            ##"
echo -e "##   8.   Stop the Nodejs service on single node on "${Red}"SLOT 02"${ENDCOLOR}"            ##"
echo -e "##   9.   Start the Nodejs service on single node on "${Green}"SLOT 01"${ENDCOLOR}"           ##"
echo -e "##  10.   Start the Nodejs service on single node on "${Red}"SLOT 02"${ENDCOLOR}"           ##"
echo -e "##  11.   Restart the Nodejs service on All node on "${Green}"SLOT 01"${ENDCOLOR}"            ##"
echo -e "##  12.   Restart the Nodejs service on All node on "${Red}"SLOT 02"${ENDCOLOR}"            ##"
echo -e ""${Yellow}"#########################################################################"
echo -e "##   ========== Any other key will quit to main menu ==========            ##"
echo -e "#########################################################################"
echo -e "${ENDCOLOR}"
read -p "  Enter your Input : " INPUT
if [ $INPUT == "3" ]; then
 copy_code_single_slot01
fi
if [ $INPUT == "4" ]; then
 copy_code_single_slot02
fi
if [ $INPUT == "5" ]; then
 restart_nodejs_single_slot01
fi
if [ $INPUT == "4" ]; then
 restart_nodejs_single_slot02
fi
if [ $INPUT == "9" ]; then
 start_nodejs_single_slot01
fi
if [ $INPUT == "10" ]; then
 start_nodejs_single_slot02
fi
if [ $INPUT == "11" ]; then
 restart_nodejs_all_slot01
fi
if [ $INPUT == "12" ]; then
 restart_nodejs_all_slot02
fi
if [ $INPUT == "7" ]; then
 stop_nodejs_single_slot01
fi
if [ $INPUT == "8" ]; then
 stop_nodejs_single_slot02
fi
menu
}

menu
