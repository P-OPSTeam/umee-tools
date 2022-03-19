#!/bin/bash

###    packages required: jq, bc
REQUIRED_PKG="bc"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

REQUIRED_PKG="jq"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

###    if suppressing error messages is preferred, run as './nodemonitor.sh 2> /dev/null'

###    CONFIG    ##################################################################################################
CONFIG=""                # config location Umee
PASSWORD=""              # keyring password needed to access wallet
BINARY="umeed"           # network specific Binary
VALIDATORNAME=""         # Name of the validator
### optional:            #
NPRECOMMITS="20"         # check last n precommits, can be 0 for no checking
VALIDATORADDRESS=""      # if left empty default is from status call (validator)
NETWORKVALIDATORADDRESS="" #if left empty default is from status call (NETWORK validator)
CHECKPERSISTENTPEERS="1" # if 1 the number of disconnected persistent peers is checked (when persistent peers are configured in config.toml)
VALIDATORMETRICS="on"    # metrics for validator node
LOGNAME="nodemonitor_umee.log"               # a custom log file name can be chosen, if left empty default is nodecheck-<username>.log
LOGPATH="$HOME/umee-tools"         # the directory where the log file is stored, for customization insert path like: /my/path
LOGSIZE=200              # the max number of lines after that the log will be trimmed to reduce its size
LOGROTATION="1"          # options for log rotation: (1) rotate to $LOGNAME.1 every $LOGSIZE lines;  (2) append to $LOGNAME.1 every $LOGSIZE lines; (3) truncate $logfile to $LOGSIZE every iteration
SLEEP1="15s"             # polls every SLEEP1 sec
###  internal:           #
colorI='\033[0;32m'      # black 30, red 31, green 32, yellow 33, blue 34, magenta 35, cyan 36, white 37
colorD='\033[0;90m'      # for light color 9 instead of 3
colorE='\033[0;31m'      #
colorW='\033[0;33m'      #
noColor='\033[0m'        # no color
###  END CONFIG  ##################################################################################################

################### VARIABLE CONFIG #######################

usage() {

  cat <<EOF

Usage: $(basename "${BASH_SOURCE[0]}") [-k] [-p]
Script description here.

Available options:
        -h, --help                    Print this help and exit
        -c, --config-file             location of config file. [default: ]
        -k, --key-name                Name of key [default: ]
        -p, --password                keyring password [default: ]
EOF
  exit
}

parse_params() {

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -c | --config-file)
      CONFIG="${2-}"
      shift
      ;;
    -k | --key-name)
      VALIDATORNAME="${2-}"
      shift
      ;;
    -p | --password)
      PASSWORD="${2-}"
      shift
      ;;
    *) break ;;
    esac
    shift
  done

args=("$@")

}

parse_params "$@"
################### END VARIABLE CONFIG ###################

################### NOTIFICATION CONFIG ###################
enable_notification="true" #true of false
# TELEGRAM
enable_telegram="false"
BOT_ID="bot<ENTER_YOURBOT_ID>"
CHAT_ID="<ENTER YOUR CHAT_ID>"
# DISCORD
enable_discord="false"
DISCORD_URL="<ENTER YOUR DISCORD WEBHOOK>"

#variable below avoid spams for the same notification state along with their notification message
#catchup
synced_n="catchingup"  # notification state either synced of catchingup (value possible catchingup/synced)
nmsg_synced="Your node is now in synced"
nmsg_unsynced="Your node is no longer in synced"

#umee binary run (emeed)
umeed_run_n="true" # true or false indicating whether umeed is running or not
nmsg_umeed_run_ok="$HOSTNAME: Your umee node is running ok now"
nmsg_umeed_run_nok="@here $HOSTNAME: Your umee node has just stop running, fix it !"
umeed_run_status="NA" #umeed test status to print out to log file 

#peggo process run (peggo)
peggo_run_n="true" # true or false indicating whether peggo process is running or not
nmsg_peggo_run_ok="$HOSTNAME: Your peggo process is running ok now"
nmsg_peggo_run_nok="@here $HOSTNAME: Your peggo process has just stop running, fix it !"
peggo_run_status="NA" #peggo test status to print out to log file 

#Jailed status
jailed_status_n="true" # true or false indicating jailed status
msg_jailed_status_ok="$HOSTNAME: Validator is not jailed"
msg_jailed_status_nok="@here $HOSTNAME: Validator is jailed, please check"
jailed_status="NA" #jailed status to print out to log file

#Bonded status
bonded_status_n="true" # true or false indicating bonded status
msg_bonded_status_ok="$HOSTNAME: Validator is bonded"
msg_bonded_status_nok="@here $HOSTNAME: Validator is unbonding or unbonded, please check"
bonded_status="NA" #jailed status to print out to log file

#Peggo log status
log_status_n="true" # true or false indicating bonded status
msg_log_status_ok="$HOSTNAME: Peggo does not have errors in the logs"
msg_log_status_nok="@here $HOSTNAME: Peggo has errors, check $HOME/umee-tools/monitoring-cli/errlog.log for the error"

#node stuck
lastblockheight=0
node_stuck_n="false" # true or false indicating the notification state of a node stuck
nmsg_nodestuck="Your node is now stuck"
nmsg_node_no_longer_stuck="Your node is no longer stuck, Yeah !"
node_stuck_status="NA" #node stucktest status to print out to log file


################### END NOTIFICATION CONFIG ###################

echo "Notification enabled on telegram : ${enable_telegram} / on discord : ${enable_discord}"

send_notification() {
    if [ "$enable_notification" == "true" ]; then
        message=$1
        
        if [ "$enable_telegram" == "true" ]; then
            curl -s -X POST https://api.telegram.org/${BOT_ID}/sendMessage -d parse_mode=html -d chat_id=${CHAT_ID=} -d text="<b>$(hostname)</b> - $(date) : ${message}" > /dev/null 2>&1
        fi
        if [ "$enable_discord" == "true" ]; then
            curl -s -X POST $DISCORD_URL -H "Content-Type: application/json" -d "{\"content\": \"${message}\"}" > /dev/null 2>&1
        fi
    fi
}


if [ -z $CONFIG ]; then
    CONFIG=$HOME/.umee/config/config.toml
fi

if [ -z $PASSWORD ]; then
    read -p "Enter your keyring password :" PASSWORD
fi

url=$(sudo sed '/^\[rpc\]/,/^\[/!d;//d' $CONFIG | grep "^laddr\b" | awk -v FS='("tcp://|")' '{print $2}')
chainid=$(jq -r '.result.node_info.network' <<<$(curl -s "$url"/status))
if [ -z $url ]; then
    send_notification "nodemonitor exited : please configure config.toml in script correctly"
    echo "please configure config.toml in script correctly"
    exit 1
fi
url="http://${url}"

if [ -z $LOGNAME ]; then LOGNAME="nodemonitor-${USER}.log"; fi

logfile="${LOGPATH}/${LOGNAME}"
touch $logfile

echo "log file: ${logfile}"
echo "rpc url: ${url}"
echo "chain id: ${chainid}"

if [ -z $VALIDATORADDRESS ]; then VALIDATORADDRESS=$(jq -r ''.result.validator_info.address'' <<<$(curl -s "$url"/status)); fi
if [ -z $VALIDATORADDRESS ]; then
    echo "rpc appears to be down, start script again when data can be obtained"
    exit 1
fi

if [ -z $NETWORKVALIDATORADDRESS ];
then 
    if [ -z $VALIDATORNAME ];
    then
        echo "validator is used as the name of the validator account"
        VALIDATORNAME=validator
    fi
    NETWORKVALIDATORADDRESS=$(echo $PASSWORD | $BINARY keys show $VALIDATORNAME --bech val -a)
fi

# Checking validator RPC endpoints status
consdump=$(curl -s "$url"/dump_consensus_state)
validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)

echo "validator address: $NETWORKVALIDATORADDRESS"

if [ "$CHECKPERSISTENTPEERS" -eq 1 ]; then
    persistentpeers=$(sudo sed '/^\[p2p\]/,/^\[/!d;//d' $CONFIG | grep "^persistent_peers\b" | awk -v FS='("|")' '{print $2}')
    persistentpeerids=$(sed 's/,//g' <<<$(sed 's/@[^ ^,]\+/ /g' <<<$persistentpeers))
    totpersistentpeerids=$(wc -w <<<$persistentpeerids)
    npersistentpeersmatchcount=0
    netinfo=$(curl -s "$url"/net_info)
    if [ -z "$netinfo" ]; then
        echo "lcd appears to be down, start script again when data can be obtained"
        exit 1
    fi
    for id in $persistentpeerids; do
        npersistentpeersmatch=$(grep -c "$id" <<<$netinfo)
        if [ $npersistentpeersmatch -eq 0 ]; then
            persistentpeersmatch="$id $persistentpeersmatch"
            npersistentpeersmatchcount=$(expr $npersistentpeersmatchcount + 1)
        fi
    done
    npersistentpeersoff=$(expr $totpersistentpeerids - $npersistentpeersmatchcount)
    echo "$totpersistentpeerids persistent peer(s): $persistentpeerids"
    echo "$npersistentpeersmatchcount persistent peer(s) off: $persistentpeersmatch"
fi

if [ $NPRECOMMITS -eq 0 ]; then echo "precommit checks: off"; else echo "precommit checks: on"; fi
if [ $CHECKPERSISTENTPEERS -eq 0 ]; then echo "persistent peer checks: off"; else echo "persistent peer checks: on"; fi
echo ""

status=$(curl -s "$url"/status)
blockheight=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
blockinfo=$(curl -s "$url"/block?height="$blockheight")
if [ $blockheight -gt $NPRECOMMITS ]; then
    if [ "$(grep -c 'precommits' <<<$blockinfo)" != "0" ]; then versionstring="precommits"; elif [ "$(grep -c 'signatures' <<<$blockinfo)" != "0" ]; then versionstring="signatures"; else
        echo "json parameters of this version not recognised"
        exit 1
    fi
else
    echo "wait for $NPRECOMMITS blocks and start again..."
    exit 1
fi

nloglines=$(wc -l <$logfile)
if [ $nloglines -gt $LOGSIZE ]; then sed -i "1,$(expr $nloglines - $LOGSIZE)d" $logfile; fi # the log file is trimmed for logsize

date=$(date --rfc-3339=seconds)
echo "$date status=scriptstarted chainid=$chainid" >>$logfile

while true ; do
        # Checking validator status
        consdump=$(curl -s "$url"/dump_consensus_state)
        validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
        isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)
        if [ "$isvalidator" != "0" ]; then
            # Checking emeed process running
            if pgrep umeed >/dev/null; then
            echo "Is umee binary running: Yes";
            umeed_run_status="OK"
                if [ $umeed_run_n == "false" ]; then #umeed process was not ok
                send_notification "$nmsg_umeed_run_ok"
                umeed_run_n="true"
                fi
            else
            echo "Is umeed binary running: No, please restart it;"
            umeed_run_status="NOK"
                if [ $umeed_run_n == "true" ]; then #umeed process was ok
                send_notification "$nmsg_umeed_run_nok"
                umeed_run_n="false"
                fi
            fi

            # Checking peggo process running
            if pgrep peggo >/dev/null; then
            echo "Is peggo binary running: Yes";
            peggo_run_status="OK"
                if [ $peggo_run_n == "false" ]; then #peggo process was not ok
                send_notification "$nmsg_peggo_run_ok"
                peggo_run_n="true"
                fi
            else
            echo "Is peggo binary running: No, please restart it;"
            peggo_run_status="NOK"
                if [ $peggo_run_n == "true" ]; then #peggo process was ok
                send_notification "$nmsg_peggo_run_nok"
                peggo_run_n="false"
                fi
            fi

            echo -n "Validator is Jailed : "
            jailed=$($BINARY query staking validator $NETWORKVALIDATORADDRESS --output json | jq .jailed)
                if [ $jailed == "true" ]; then
                echo "true"
                jailed_status="NOK"
                    if [ $jailed_status_n == "false" ]; then
                    send_notification "$msg_jailed_status_nok"
                    jailed_status_n="true"
                    fi
                else
                echo "false"
                    if [ $jailed_status_n == "true" ]; then
                    send_notification "$msg_jailed_status_ok"
                    jailed_status_n="false"
                    fi
                fi
            
            echo -n "Validator is Bonded : "
            status=$($BINARY query staking validator $NETWORKVALIDATORADDRESS --output json | jq .status | cut -d '"' -f2 )
                if [ $status == "BOND_STATUS_BONDED" ]; then
                echo "true"
                bonded_status="NOK"
                    if [ $bonded_status_n == "true" ]; then
                    send_notification "$msg_bonded_status_ok"
                    bonded_status_n="false"
                    fi
                else
                echo "false"
                    if [ $bonded_status_n == "false" ]; then
                    send_notification "$msg_bonded_status_nok"
                    bonded_status_n="true"
                    fi
                fi
            
            echo -n "Errors in log : "
            peggolog=$(journalctl -S "5 minutes ago" -U "1 minute ago" -u peggod -f -o cat | head -q | grep ERR)
                if [ -z $peggolog ]; then
                echo "No errors found in peggo log"
                    if [ $log_status_n == "false" ]; then
                    send_notification "$msg_log_status_ok"
                    log_status_n=true
                    fi
                else 
                echo "errors found in peggo log"
                    echo $peggolog >> $HOME/umee-tools/monitoring-cli/errlog.log
                    if [ $log_status_n == "true" ]; then
                    send_notification "$msg_log_status_nok"
                    log_status_n=false
                    fi
                fi              
            
        fi

    echo

    # testing machine/host resource
    free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'
    df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n", $3,$2,$5}'
    top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}'

    echo
    # TBD Alert on resource monitoring 

    status=$(curl -s "$url"/status)
    result=$(grep -c "result" <<<$status)
    if [ "$result" != "0" ]; then
        npeers=$(curl -s "$url"/net_info | jq -r '.result.n_peers')
        if [ -z $npeers ]; then npeers="na"; fi
        blockheight=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
        blocktime=$(jq -r '.result.sync_info.latest_block_time' <<<$status)
        catchingup=$(jq -r '.result.sync_info.catching_up' <<<$status)
        if [ $catchingup == "false" ]; then 
            catchingup="synced";
            if [ $synced_n == "catchingup" ]; then #it was previously synching
                send_notification "$nmsg_synced"
                synced_n="synced" #change notification state
            fi
        elif [ $catchingup == "true" ]; then 
            catchingup="catchingup";
            if [ $synced_n == "synced" ]; then #it was previously synced
                send_notification $nmsg_unsynced 
                synced_n="catchingup" #change notification state
            fi
        fi

        if [ "$CHECKPERSISTENTPEERS" -eq 1 ]; then
            npersistentpeersmatch=0
            netinfo=$(curl -s "$url"/net_info)
            for id in $persistentpeerids; do
                npersistentpeersmatch=$(expr $npersistentpeersmatch + $(grep -c "$id" <<<$netinfo))
            done
            npersistentpeersoff=$(expr $totpersistentpeerids - $npersistentpeersmatch)
        else
            npersistentpeersoff=0
        fi
        if [ "$VALIDATORMETRICS" == "on" ]; then
            #isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$(curl -s "$url"/block?height="$blockheight"))
            consdump=$(curl -s "$url"/dump_consensus_state)
            validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
            isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)
            pcttotcommits=$(jq -r '.result.round_state.last_commit.votes_bit_array' <<<$consdump)
            pcttotcommits=$(grep -Po "=\s+\K[^ ^]+" <<<$pcttotcommits)
            if [ "$isvalidator" != "0" ]; then
                isvalidator="yes"
                precommitcount=0
                for ((i = $(expr $blockheight - $NPRECOMMITS + 1); i <= $blockheight; i++)); do
                    validatoraddresses=$(curl -s "$url"/block?height="$i")
                    validatoraddresses=$(jq ".result.block.last_commit.${versionstring}[].validator_address" <<<$validatoraddresses)
                    validatorprecommit=$(grep -c "$VALIDATORADDRESS" <<<$validatoraddresses)
                    precommitcount=$(expr $precommitcount + $validatorprecommit)
                done
                if [ $NPRECOMMITS -eq 0 ]; then pctprecommits="1.0"; else pctprecommits=$(echo "scale=2 ; $precommitcount / $NPRECOMMITS" | bc); fi

                validatorinfo="isvalidator=$isvalidator pctprecommits=$pctprecommits pcttotcommits=$pcttotcommits umeed_run_status=$umeed_run_status peggo_run_status=$peggo_run_status"
            else
                isvalidator="no"
                validatorinfo="isvalidator=$isvalidator"
            fi
        fi

        # test if last block saved and new block height are the same
        if [ $lastblockheight -eq $blockheight ]; then #block are the same
            node_stuck_status="YES"
            if [ $node_stuck_n == "false" ]; then # node_stuck notification state was false
                node_stuck_n="true"
                send_notification "$nmsg_nodestuck"
            fi
        else #new node block is different
            node_stuck_status="NO"
            if [ $node_stuck_n == "true" ]; then # mean it was previously stuck
                node_stuck_n="false"
                send_notification "$nmsg_node_no_longer_stuck"                
            fi
            lastblockheight=$blockheight
        fi

        #finalize the log output
        status="$catchingup"
        now=$(date --rfc-3339=seconds)
        blockheightfromnow=$(expr $(date +%s -d "$now") - $(date +%s -d $blocktime))
        variables="status=$status blockheight=$blockheight node_stuck=$node_stuck_status tfromnow=$blockheightfromnow npeers=$npeers npersistentpeersoff=$npersistentpeersoff $validatorinfo"
    else
        status="error"
        now=$(date --rfc-3339=seconds)
        variables="status=$status"
    fi

    logentry="[$now] $variables"
    echo "$logentry" >>$logfile

    nloglines=$(wc -l <$logfile)
    if [ $nloglines -gt $LOGSIZE ]; then
        case $LOGROTATION in
        1)
            mv $logfile "${logfile}.1"
            touch $logfile
            ;;
        2)
            echo "$(cat $logfile)" >>${logfile}.1
            >$logfile
            ;;
        3)
            sed -i '1d' $logfile
            if [ -f ${logfile}.1 ]; then rm ${logfile}.1; fi # no log rotation with option (3)
            ;;
        *) ;;

        esac
    fi

    case $status in
    synced)
        color=$colorI
        ;;
    error)
        color=$colorE
        ;;
    catchingup)
        color=$colorW
        ;;
    *)
        color=$noColor
        ;;
    esac

    pctprecommits=$(awk '{printf "%f", $0}' <<<"$pctprecommits")
    if [[ "$isvalidator" == "yes" ]] && [[ "$pctprecommits" < "1.0" ]]; then color=$colorW; fi
    if [[ "$isvalidator" == "no" ]] && [[ "$VALIDATORMETRICS" == "on" ]]; then color=$colorW; fi

    logentry="$(sed 's/[^ ]*[\=]/'\\${color}'&'\\${noColor}'/g' <<<$logentry)"
    echo -e $logentry
    echo -e "${colorD}sleep ${SLEEP1}${noColor}"
    echo

    variables_=""
    for var in $variables; do
        var_=$(grep -Po '^[0-9a-zA-Z_-]*' <<<$var)
        var_="$var_=\"\""
        variables_="$var_; $variables_"
    done
    #echo $variables_
    eval $variables_

    sleep $SLEEP1
done