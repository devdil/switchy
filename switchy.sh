#!/bin/bash

: '
  Display the incoming logs with timestamp on terminal and save the same on switch.log file
'
log()
{
  LEVEL=$1
  TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
  MESSAGE=$2
  echo "$TIMESTAMP $LEVEL $MESSAGE"
  echo "$TIMESTAMP $LEVEL $MESSAGE" >> ./switch.log
}

: '
  Display error message for unsupported OS. Current version supports Mac OS X only.
'
unsupported_type()
{
  log "ERROR" "Unsupported OS Type! Supported OSTYPE: MacOSx.";
  exit 1;
}

: '
  Display detected operating system and initialize script configuration and execution 
'
handle_macos()
{
  log "INFO" "Detected Operating System: ${OS}"
  configure_and_start
  exit 0;
}

: '
  Monitor primary wifi and switch over to fallback wifi in case of primary wifi goes down
'
monitor_and_switch_wifi()
{
  primarywifissid=$1
  primarywifissidpassword=$2
  fallbackwifissid=$3
  fallbackwifissidpassword=$4
  wifiinterface=$5
  MAX_FAILURES_TOLERABLE=3
  FAILURES_TILL_NOW=0

  while :
  do
    #loop infintely
    log "INFO" "🌏 Pinging the Internet"
    if ping -i .5  -t 3 google.com >&/dev/null;then
        log "INFO" "✅ Ping 8.8.8.8 Successfull ✅"
      else
        log "ERROR" "Ping 8.8.8.8 Failed 🥺"
        FAILURES_TILL_NOW=$((FAILURES_TILL_NOW+1))
        if [ "$FAILURES_TILL_NOW" -gt "$MAX_FAILURES_TOLERABLE" ];then
            log "INFO" "Resetting to normal values"
            FAILURES_TILL_NOW=0
            log "INFO" "Switching to healthy wifi..."
            SWITCH_TO_FALLBACK="networksetup -setairportnetwork en0 $fallbackwifissid $fallbackwifissidpassword"
            eval $SWITCH_TO_FALLBACK
            if [ $? -eq 0 ];then
              log "INFO" "✅ Successfully switched to fallback"
            else
              log "ERROR" "🥺 Could not switch to fallback wifi"
              exit 1
            fi
        else
          log "INFO" "Failures $FAILURES_TILL_NOW/$MAX_FAILURES_TOLERABLE"
        fi 
    fi      
    log "INFO" "😴 Sleeping for 3 seconds"    
    sleep 3
  done

}

: '
  Verify wifi configuration existing
'
is_configured()
{
  if [ ! -f ./switchy.conf ]; then
    return 1
  else
    IS_CONFIGURED=`grep configured ./switchy.conf | cut -d'=' -f2`
    if [ -z "$IS_CONFIGURED" ]; then
      log "ERROR" "A configuration does not exist! Prompting for configuration"
      return 1
    else
      log "INFO" "✅ Using existing configuration at ./switchy.conf"
      return 0
    fi
  fi
}

: '
  Load either existing configuration if exist else create new and start the script execution
'
configure_and_start()
{
  if is_configured; then
    primarywifissid=`grep -w primarywifissid ./switchy.conf | cut -d'=' -f2`
    primarywifissidpassword=`grep -w primarywifissidpassword ./switchy.conf | cut -d'=' -f2`
    fallbackwifissid=`grep -w fallbackwifissid ./switchy.conf | cut -d'=' -f2`
    fallbackwifissidpassword=`grep -w fallbackwifissidpassword ./switchy.conf | cut -d'=' -f2`
    wifiinterface=`grep -w wifiinterface ./switchy.conf | cut -d'=' -f2`
    log "INFO" "Primary WiFi: $primarywifissid Fallback WiFi: $fallbackwifissid WifiInterface: $wifiinterface"
    monitor_and_switch_wifi $primarywifissid $primarywifissidpassword $fallbackwifissid $fallbackwifissidpassword $wifiinterface
  else
    log INFO "Searching and Configuring WIFI Port..."
    WIFI_PORT=`networksetup -listallhardwareports -h | grep -A 2  'Wi-Fi' | grep Device | cut -d ' ' -f2`
    if [ -z "$WIFI_PORT" ]; then
      log "ERROR" "Could not search and configure a valid WIFI port :("
      exit 1
    else
      log "INFO" "✅ Found WIFI Hardware port on ${WIFI_PORT} "
    fi

    log "INFO" "Listing all Wifi adapaters..."
    COMMAND="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s"
    eval $COMMAND
    echo "------- Enter your Primary WIFI details -----------------"
    read -p 'Primary WIFI SSID: ' primarywifissid
    stty -echo
    read -s -p 'Primary WIFI Password: ' primarywifissidpassword
    stty echo
    log "INFO" "Your Primary WIFI SSID is ${primarywifissid}"
    echo "-----------------------------------------------------------"
    echo "------- Enter your Fallback WIFI details -------"
    read -p 'Fallback WIFI SSID: ' fallbackwifissid
    stty -echo
    read -s -p 'Fallback WIFI Password: ' fallbackwifissidpassword
    stty echo
    log "INFO" "Your Fallback WIFI SSID is ${fallbackwifissid}"
    echo "-----------------------------------------------------------"
    echo "✅ Saving configurations to ./switchy.conf"
    echo "configured=true" > ./switchy.conf
    echo "primarywifissid=${primarywifissid}" >> ./switchy.conf
    echo "primarywifissidpassword=${primarywifissidpassword}" >> ./switchy.conf
    echo "fallbackwifissid=${fallbackwifissid}" >> ./switchy.conf
    echo "fallbackwifissidpassword=${fallbackwifissidpassword}" >> ./switchy.conf
    echo "wifiinterface=${WIFI_PORT}" >> ./switchy.conf
    echo "✅ Saved configurations to ./switchy.conf"
    monitor_and_switch_wifi $primarywifissid $primarywifissidpassword $fallbackwifissid $fallbackwifissidpassword $wifiinterface
  fi
}

: '
  Detect OS type
'
case "$OSTYPE" in
  solaris*)
    OS="SOLARIS";
    unsupported_type
    ;;
  darwin*)
    OS="OSX" 
    handle_macos;
    ;; 
  linux*)
    OS="LINUX"
    unsupported_type
    ;;
  bsd*)
    OS="BSD"
    unsupported_type
    ;;
  msys*)
    OS="WINDOWS"
    unsupported_type
    ;;
  cygwin*)
    OS="ALSO WINDOWS"
    unsupported_type
    ;;
  *)
    OS="unknown: $OSTYPE"
    unsupported_type
    ;;
esac
