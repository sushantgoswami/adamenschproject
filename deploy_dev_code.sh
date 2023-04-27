#!/bin/bash

GIT_USER=teknozest
GIT_TOKEN=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
GIT_PULL_URL="https://$GIT_USER:$GIT_TOKEN@github.com/datechadmin/damenschstorefront.git"
BRANCH_NAME="feature-AK-Page-Speed-Optimization"

APPUSER=BetterAdmin
APP_DATA_DIR=damenschstorefront
SITE=damensch.com

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

