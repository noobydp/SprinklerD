#!/bin/bash
#
# ROOT=/nas/data/Development/Raspberry/gpiocrtl/test-install
#


BUILD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SERVICE="sprinklerd"

BIN="sprinklerd"
CFG="sprinklerd.conf"
SRV="sprinklerd.service"
DEF="sprinklerd"
MDNS="sprinklerd.service"

BINLocation="/usr/local/bin"
CFGLocation="/etc"
SRVLocation="/etc/systemd/system"
DEFLocation="/etc/default"
WEBLocation="/var/www/sprinklerd/"
MDNSLocation="/etc/avahi/services/"

function check_cron() {

  # Look for cron running with LSB name support
  if [[ ! $(pgrep -af cron | grep '\-l') ]]; then
    # look for cron running
    if [[ ! $(pgrep -af cron) ]]; then
      # look for cron installed
      if [[ ! $(command -v cron) ]]; then
        echo "Can't find cron, please install"
      else
        echo "cron is not running, please start cron"
      fi
    else
    # Cron is running, but not with LSB name support 
      if [ ! -d "/etc/cron.d" ] || [ ! -f "/etc/default/cron" ]; then
        echo "The version of Cron may not support chron.d, if so the calendar schedule will not work"
        echo "Please check cron for LSB name support before using calendar schedule feature of $SERVICE"
       else
        # Check and see if we can add LSB support
        #if [ -f "/etc/default/cron" ]; then
        echo ...
      fi
    fi
  fi
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ $(mount | grep " / " | grep "(ro,") ]]; then
  echo "Root filesystem is readonly, can't install" 
  exit 1
fi

check_cron
exit 0

if [ ! -d "/etc/cron.d" ]; then
  echo "The version of Cron may not support chron.d, if so the calendar schedule will not work"
  echo "Please check before starting"
else
  if [ -f "/etc/default/cron" ]; then
    CD=$(cat /etc/default/cron | grep -v ^# | grep "\-l")
    if [ -z "$CD" ]; then
      echo "Please enabled cron.d support, if not the calendar will not work"
      echo "Edit /etc/default/cron and look for the -l option"
    fi
  else
    echo "Please make sure the version if Cron supports chron.d, if not the calendar schedule will not work"
  fi
fi

exit 0


if [ "$1" == "uninstall" ] || [ "$1" == "-u" ] || [ "$1" == "remove" ]; then
  systemctl stop $SERVICE > /dev/null 2>&1
  systemctl disable $SERVICE  > /dev/null 2>&1
  rm -f $BINLocation/$BIN
  rm -f $SRVLocation/$SRV
  rm -f $DEFLocation/$DEF
  rm -f $MDNSLocation/$MDNS
  rm -rf $WEBLocation
  if [ -f $CFGLocation/$CFG ]; then
    cache=$(cat $CFGLocation/$CFG | grep CACHE | cut -d= -f2 | sed -e 's/^[ \t]*//' | sed -e 's/ *$//')
    rm -f $cache
    rm -f $CFGLocation/$CFG 
  fi
  rm -f "/etc/cron.d/sprinklerd"
  echo "SprinklerD & configuration removed from system"
  exit
fi

# Check cron.d options
if [ ! -d "/etc/cron.d" ]; then
  echo "The version of Cron may not support chron.d, if so the calendar will not work"
  echo "Please check before starting"
else
  if [ -f "/etc/default/cron" ]; then
    CD=$(cat /etc/default/cron | grep -v ^# | grep "\-l")
    if [ -z "$CD" ]; then
      echo "Please enabled cron.d support, if not the calendar will not work"
      echo "Edit /etc/default/cron and look for the -l option"
    fi
  else
    echo "Please make sure the version if Cron supports chron.d, if not the calendar will not work"
  fi
fi

# Exit if we can't find systemctl
command -v systemctl >/dev/null 2>&1 || { echo "This script needs systemd's systemctl manager, Please check path or install manually" >&2; exit 1; }

# stop service, hide any error, as the service may not be installed yet
systemctl stop $SERVICE > /dev/null 2>&1
SERVICE_EXISTS=$(echo $?)

# copy files to locations, but only copy cfg if it doesn;t already exist

cp $BUILD/$BIN $BINLocation/$BIN
cp $BUILD/$SRV $SRVLocation/$SRV

if [ -f $CFGLocation/$CFG ]; then
  echo "Config exists, did not copy new config, you may need to edit existing! $CFGLocation/$CFG"
else
  cp $BUILD/$CFG $CFGLocation/$CFG
fi

if [ -f $DEFLocation/$DEF ]; then
  echo "Defaults exists, did not copy new defaults to $DEFLocation/$DEF"
else
  cp $BUILD/$DEF.defaults $DEFLocation/$DEF
fi

if [ -f $MDNSLocation/$MDNS ]; then
  echo "Avahi/mDNS defaults exists, did not copy new defaults to $MDNSLocation/$MDNS"
else
  if [ -d "$MDNSLocation" ]; then
    cp $BUILD/$MDNS.avahi $MDNSLocation/$MDNS
  else
    echo "Avahi/mDNS may not be installed, not copying $MDNSLocation/$MDNS"
  fi
fi

if [ ! -d "$WEBLocation" ]; then
  mkdir -p $WEBLocation
fi

cp -r $BUILD/../web/* $WEBLocation

systemctl enable $SERVICE
systemctl daemon-reload

if [ $SERVICE_EXISTS -eq 0 ]; then
  echo "Starting daemon $SERVICE"
  systemctl start $SERVICE
fi

