#!/bin/bash -e
# Bastion Bootstraping
# authors: tonynv@amazon.com, sancard@amazon.com
# date Nov,9,2016
# NOTE: This requires GNU getopt.  On Mac OS X and FreeBSD you must install GNU getopt and mod the checkos fuction so its supported


# Configuration
PROGRAM='Linux Bastion'

##################################### Functions
function checkos () {
platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
    platform='linux'
else
    echo "[WARINING] This script is not supported on MacOS or freebsd"
    exit 1
fi
}

function usage () {
    echo "$0 <usage>"
    echo " "
    echo "options:"
    echo -e "--help \t show options for this script"
    echo -e "--banner \t Bastion Message"
    echo -e "--enable \t SSH Banner"
}

function chkstatus () {
if [ $? -eq 0 ]
then
    echo "Script [PASS]"
else
    echo "Script [FAILED]" >&2
    exit 1
fi
}
##################################### Functions

# Call checkos to ensure platform is Linux
checkos

## set an initial value
SSH_BANNER="LINUX BASTION"

# Read the options from cli input
TEMP=`getopt -o h:  --long help,banner:,enable: -n $0 -- "$@"`
eval set -- "$TEMP"


if [ $# == 1 ] ; then echo "No input provided! type ($0 --help) to see usage help" >&2 ; exit 1 ; fi

# extract options and their arguments into variables.
while true; do
    case "$1" in
        -h | --help)
            usage
            exit 1
            ;;
        --banner)
            BANNER_PATH="$2";
            shift 2
            ;;
        --enable)
            ENABLE="$2";
            shift 2
            ;;
        --)
            break
            ;;
        *)
            break
            ;;
    esac
done

# BANNER CONFIGURATION
BANNER_FILE="/etc/ssh_banner"
if [[ $ENABLE == "true" ]];then
    if [ -z ${BANNER_PATH} ];then
        echo "BANNER_PATH is null skipping ..."
    else
        echo "BANNER_PATH = ${BANNER_PATH}"
        echo "Creating Banner in ${BANNER_FILE}"
        echo "curl  -s ${BANNER_PATH} > ${BANNER_FILE}"
        curl  -s ${BANNER_PATH} > ${BANNER_FILE}
        if [ $BANNER_FILE ] ;then
            echo "[INFO] Installing banner ... "
            echo -e "\n Banner ${BANNER_FILE}" >>/etc/ssh/sshd_config
        else
            echo "[INFO] banner file is not accessible skipping ..."
            exit 1;
        fi
    fi
else
    echo "Banner message is not enabled!"
fi

# LOGGING CONFIGURATION
declare -rx BASTION_MNT="/var/log/bastion"
declare -rx BASTION_LOG="bastion.log"
echo "Setting up bastion session log in ${BASTION_MNT}/${BASTION_LOG}"
mkdir -p ${BASTION_MNT}
declare -rx BASTION_LOGFILE="${BASTION_MNT}/${BASTION_LOG}"
declare -rx BASTION_LOGFILE_SHADOW="${BASTION_MNT}/.${BASTION_LOG}"
touch ${BASTION_LOGFILE}
ln ${BASTION_LOGFILE} ${BASTION_LOGFILE_SHADOW}
# CentOS Linux
if [ -f /etc/redhat-release ]; then
    /bin/systemctl restart  sshd.service
    echo -e "\nDefaults env_keep += \"SSH_CLIENT\"" >>/etc/sudoers
cat <<'EOF' >> /etc/bashrc
#Added by linux bastion bootstrap
declare -rx IP=$(echo $SSH_CLIENT | awk '{print $1}')
EOF
    echo "declare -rx BASTION_LOG=${BASTION_MNT}/${BASTION_LOG}" >> /etc/bashrc
cat <<'EOF' >> /etc/bashrc
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: ${TIME}   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOF
    chown root:adm  ${BASTION_LOGFILE}
    chown root:adm  ${BASTION_LOGFILE_SHADOW}
    chmod 622 ${BASTION_LOGFILE}
    chmod 622 ${BASTION_LOGFILE_SHADOW}
    chattr +a ${BASTION_LOGFILE}
    chattr +a ${BASTION_LOGFILE_SHADOW}
# Ubuntu Linux
elif [ -f /etc/lsb-release ]; then
    service ssh restart
cat <<'EOF' >> /etc/bash.bashrc
#Added by linux bastion bootstrap
declare -rx IP=$(who am i --ips|awk '{print $5}')
declare -rx TIME=$(date)
EOF
echo " declare -rx BASTION_LOG=${BASTION_MNT}/${BASTION_LOG}" >> /etc/bash.bashrc
cat <<'EOF' >> /etc/bash.bashrc
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: ${TIME}   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOF
    chown syslog:adm  ${BASTION_LOGFILE}
    chown syslog:adm  ${BASTION_LOGFILE_SHADOW}
    chmod 622 ${BASTION_LOGFILE}
    chmod 622 ${BASTION_LOGFILE_SHADOW}
    chattr +a ${BASTION_LOGFILE}
    chattr +a ${BASTION_LOGFILE_SHADOW}
# AMZN Linux
elif [[ -f /etc/system-release && ! -f /etc/redhat-release ]]; then
    service sshd restart
    echo -e "\nDefaults env_keep += \"SSH_CLIENT\"" >>/etc/sudoers
cat <<'EOF' >> /etc/bashrc
#Added by linux bastion bootstrap
declare -rx IP=$(echo $SSH_CLIENT | awk '{print $1}')
declare -rx TIME=$(date)
EOF
    echo " declare -rx BASTION_LOG=${BASTION_MNT}/${BASTION_LOG}" >> /etc/bashrc
cat <<'EOF' >> /etc/bashrc
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: ${TIME}   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOF
    chown root:ec2-user  ${BASTION_LOGFILE}
    chown root:ec2-user  ${BASTION_LOGFILE_SHADOW}
    chmod 622 ${BASTION_LOGFILE}
    chmod 622 ${BASTION_LOGFILE_SHADOW}
    chattr +a ${BASTION_LOGFILE}
    chattr +a ${BASTION_LOGFILE_SHADOW}
fi
