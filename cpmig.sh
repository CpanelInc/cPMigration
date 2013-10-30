#!/bin/bash
# Original version written by Phil Stark
# Maintained by Phil Stark
# Co-maintained by Blaine Motsinger
#
# README
# https://raw.github.com/philstark/cPMigration/DEVELOPMENT/README.md
#
# https://github.com/philstark/cPMigration/
#
VERSION="1.1.4"
scripthome="/root/.cpmig"
#
#############################################


#############################################
### functions
#############################################

print_intro(){
  echo 'cPMigration'
  echo "version $VERSION"
  echo
}

print_help(){
  echo 'usage:'
  echo './cpmig -s <hostname or ip>'
  echo
  echo 'required:'
  echo '-s ,<hostname or ip>, sourceserver'
  echo
  echo 'optional:'
  echo '-a <username or domain>, specify single account'
  echo '-i <ip address>,  specify ip address to restore to'
  echo '-l <filename>,  Read accounts from list'
  echo '-p <sourceport>'
  echo '-k keep archives on both servers'
  echo '-D use DEVEL scripts on remote setup (3rdparty)'
  echo '-S skip remote setup'
  echo '-h displays this dialogue'
  echo '-R <destip>, Set up Remote MySQL grants for destination ip (cPanel > cPanel migration only)'
  echo; echo; exit 1
}

install_sshpass(){
  echo 'Installing sshpass...'
  mkdir_ifneeded $scripthome/.sshpass
  cd $scripthome/.sshpass
  wget -P $scripthome/.sshpass/ http://downloads.sourceforge.net/project/sshpass/sshpass/1.05/sshpass-1.05.tar.gz
  tar -zxvf $scripthome/.sshpass/sshpass-1.05.tar.gz -C $scripthome/.sshpass/
  cd $scripthome/.sshpass/sshpass-1.05/
  ./configure
  make
  echo; echo
}

generate_accounts_list(){
  echo 'Generating accounts lists...'
  # grab source accounts list
  $scp root@$sourceserver:/etc/trueuserdomains $scripthome/.sourcetudomains >> $logfile 2>&1
  
  # sort source accounts list
  sort $scripthome/.sourcetudomains > $scripthome/.sourcedomains
  
  # grab and sort local (destination) accounts list
  sort /etc/trueuserdomains > $scripthome/.destdomains
  
  # diff out the two lists,  parse out usernames only and remove whitespace.  Output to copyaccountlist :)
  copyaccountlist="`diff -y $scripthome/.sourcedomains $scripthome/.destdomains | grep \< | awk -F':' '{ print $2 }' | sed -e 's/^[ \t]*//' | awk -F' ' '{ print $1 }' | grep -v \"cptkt\" `"
}

mkdir_ifneeded(){
  if [ ! -d $1 ]; then
    mkdir -p $1
  fi
}

set_logging_mode(){
  logfile="$scripthome/log/`date +%Y-%m-%y`-$epoch.log"
  case "$1" in
    verbose)
      logoutput="&> >(tee --append $logfile)"
    ;;
    *)
      logoutput=">> $logfile "
    ;;
  esac
}

setup_remote(){
  if [[ $develmode == "1" ]]; then
    echo "DEVEL Mode set for setup_remote" &> >(tee --append $logfile)
    pkgacctbranch="DEVEL"
  else
    pkgacctbranch="PUBLIC" &> >(tee --append $logfile)
  fi
  
  control_panel=`$ssh root@$sourceserver "if [ -e /usr/local/psa/version	 ];then echo plesk; elif [ -e /usr/local/cpanel/cpanel ];then echo cpanel; elif [ -e /usr/bin/getapplversion ];then echo ensim; elif [ -e /usr/local/directadmin/directadmin ];then echo da; else echo unknown;fi;exit"` >> $logfile 2>&1
  #echo "Checking remote server control panel: $control_panel"
  #echo "CONTROL PANEL: $control_panel"
  if [[ $control_panel = "cpanel" ]]; then : echo "Source is cPanel,  nothing special to do"  # no need to bring over things if cPanel#
    elif [[ $control_panel = "plesk" ]]; then  # wget or curl from httpupdate
    echo "The Source server is Plesk!"  &> >(tee --append $logfile)
    echo "Setting up scripts, Updating user domains" &> >(tee --append $logfile)
    $ssh root@$sourceserver "
if [[ ! -d /scripts ]]; then
mkdir /scripts ;fi;
if [[ ! -f /scripts/pkgacct ]]; then
wget http://httpupdate.cpanel.net/cpanelsync/transfers_$pkgacctbranch/pkgacct/pkgacct-pXa -P /scripts;
mv /scripts/pkgacct-pXa /scripts/pkgacct;
chmod 755 /scripts/pkgacct
fi;
if [[ ! -f /scripts/updateuserdomains-universal ]]; then
wget http://httpupdate.cpanel.net/cpanelsync/transfers_$pkgacctbranch/pkgacct/updateuserdomains-universal -P /scripts;
chmod 755 /scripts/updateuserdomains-universal;
fi;
    /scripts/updateuserdomains-universal;" >> $logfile 2>&1
    elif [[ $control_panel = "ensim" ]]; then
    echo "The Source server is Ensim!"  &> >(tee --append $logfile)
    echo "Setting up scripts, Updating user domains" &> >(tee --append $logfile)
    $ssh root@$sourceserver "
if [[ ! -d /scripts ]]; then
mkdir /scripts ;fi;
if [[ ! -f /scripts/pkgacct ]]; then
wget http://httpupdate.cpanel.net/cpanelsync/transfers_$pkgacctbranch/pkgacct/pkgacct-enXim -P /scripts;
mv /scripts/pkgacct-enXim /scripts/pkgacct;
chmod 755 /scripts/pkgacct
fi;
if [[ ! -f /scripts/updateuserdomains-universal ]]; then
wget http://httpupdate.cpanel.net/cpanelsync/transfers_$pkgacctbranch/pkgacct/updateuserdomains-universal -P /scripts;
chmod 755 /scripts/updateuserdomains-universal;
fi;
    /scripts/updateuserdomains-universal;" >> $logfile 2>&1
    elif [[ $control_panel = "da" ]]; then
    echo "The Source server is Direct Admin!"  &> >(tee --append $logfile)
    echo "Setting up scripts, Updating user domains" &> >(tee --append $logfile)
    $ssh root@$sourceserver "
if [[ ! -d /scripts ]]; then
mkdir /scripts ;fi;
if [[ ! -f /scripts/pkgacct ]]; then
wget http://httpupdate.cpanel.net/cpanelsync/transfers_$pkgacctbranch/pkgacct/pkgacct-dXa -P /scripts;
mv /scripts/pkgacct-dXa /scripts/pkgacct;
chmod 755 /scripts/pkgacct
fi;
if [[ ! -f /scripts/updateuserdomains-universal ]]; then
wget http://httpupdate.cpanel.net/cpanelsync/transfers_$pkgacctbranch/pkgacct/updateuserdomains-universal -P /scripts;
chmod 755 /scripts/updateuserdomains-universal;
fi;
    /scripts/updateuserdomains-universal;" >> $logfile 2>&1
  fi
}


process_loop(){
  
  # Override the normal accounts list if we're in Single user mode
  if [[ $singlemode -eq "1" ]]; then
    copyaccountlist="`grep -w $targetaccount $scripthome/.sourcetudomains | head -1 | awk '{print $2}'`"
  fi
  
  if [[ $listmode -eq "1" ]]; then
    copyaccountlist=""
    for targetaccount in `cat $listfile`
    do
      copyaccountlist="$copyaccountlist `grep -w $targetaccount $scripthome/.sourcetudomains | head -1 | awk '{print $2}'`"
    done
  fi
  
  i=1
  count=`echo $copyaccountlist | wc -w`
  for user in `echo $copyaccountlist`; do
    userepoch="`date +%s`"
    progresspercent=`echo $i $count | awk '{print ( $1 - 1 ) / $2 * 100}'`
    echo -en "\E[40;32m############### \E[40;33mProcessing account \E[40;37m$user \E[40;33m$i/$count \E[40;33m(\E[40;32m$progresspercent% \E[40;33mCompleted) \E[40;32m################\E[0m \n"
    
    #Adding a log marker
    echo "################################################################" >> $logfile
    echo "################################################################" >> $logfile
    echo "################################################################" >> $logfile
    echo "#@B# $user BEGIN $i/$count" >> $logfile
    sleep 1;
    echo -en "\E[40;34mPackaging account on source server...\E[0m \n"
    
    #Adding a log marker
    logcheck="$logcheck `echo \"#@1# $user - Packaging on Source\" &> >(tee --append $logfile)`"
    logcheck="$logcheck `$ssh root@$sourceserver \"/scripts/pkgacct $skipdbpkgacct $user;exit\" &> >(tee --append $logfile)`"
    error_check
    
    # copy (scp) the cpmove file from the source to destination server
    echo -en "\E[40;34mCopying the package from source to destination...\E[0m \n"
    
    #Adding a log marker
    logcheck="$logcheck `echo \"#@2# $user - Transferring package Destination < Source\" &> >(tee --append $logfile)`"
    logcheck="$logcheck `$scp root@$sourceserver:/home/cpmove-$user.tar.gz /home/ &> >(tee --append $logfile)`"
    error_check
    
    # Remove cpmove from source server (if set)
    if [[ $keeparchives == 1 ]]; then :
    else
      echo -en "\E[40;34mRemoving the package from the source...\E[0m \n"
      #Adding a log marker
      logcheck="$logcheck `echo \"#@3# $user - Remove package from Source\" &> >(tee --append $logfile)`"
      logcheck="$logcheck `$ssh root@$sourceserver \"rm -f /home/cpmove-$user.tar.gz ;exit\" &> >(tee --append $logfile)`"
      error_check
    fi
    
    # Restore package on the destination server (if set)
    echo -en "\E[40;34mRestoring the package to the destination...\E[0m \n"
    
    # Determine if account should get a dedicated IP
    if [[ $dedicatedips -eq  1 ]]; then
      if [[ "`cat $scripthome/.sourcededicatedaccounts | awk '{ print $1 }' | grep $user | wc -l`" -eq  1 ]]; then
        update_ipdata
        echo "DEDICATED IP: $destnextavailableip" &> >(tee --append $logfile)
        restoreipflag="--ip $destnextavailableip"
      else
        restoreipflag=""
      fi
    fi
    
    # Restore IP Address
    if [[ $restoreipmode -eq 1 ]]; then
      echo "RESTORE IP: $restoreip" &> >(tee --append $logfile)
      restoreipflag="--ip $restoreip"
    fi
    
    #Adding a log marker
    logcheck="$logcheck `echo \"#@4# $user - Restoring package\" &> >(tee --append $logfile)`"
    logcheck="$logcheck `/scripts/restorepkg $forceremoterestore $restoreipflag /home/cpmove-$user.tar.gz &> >(tee --append $logfile)`"
    error_check
    
    
    
    # Remove cpmove from destination server (if set)
    if [[ $keeparchives == 1 ]]; then :
    else
      echo -en "\E[40;34mRemoving the package from the destination...\E[0m \n"
      #Adding a log marker
      logcheck="$logcheck `echo \"#@5# $user - Remove package from Destination\" &> >(tee --append $logfile)`"
      logcheck="$logcheck `rm -fv /home/cpmove-$user.tar.gz &> >(tee --append $logfile)`"
      error_check
    fi
    i=`expr $i + 1`
    echo "#@E# $user END" >> $logfile
    
    
    logfile_status="$scripthome/log/`date +%Y-%m-%y`-$epoch-status.txt"
    #User check
    if [[ $(ls -1 /var/cpanel/users | grep $user | wc -w) -eq 0 ]]; then
      echo -en "\E[40;31m User DOES NOT exist on destination.  This user ($user) was not migrated.  Please check the logs at $logfile for more details.\E[0m \n"
      echo "#@V# ERROR $user was not found on the destination!  Something went wrong."  >> $logfile
      missingusers="$missingusers $user"
      #user status file
      echo "$user ... FAILED" >> $logfile_status
    else
      echo "$user completed."
      echo "#@V# $user VERIFIED EXISTS" >> $logfile
      verifiedusers="$verifiedusers $user"
      echo "$user ... OK" >> $logfile_status
    fi
    
    # Fix Remote MySQL Grants
    if [[ $remotemysql -eq 1 ]]; then
      $scp root@$sourceserver:/var/cpanel/databases/$user.* /var/cpanel/databases/ &> $logfile 2>&1
      authorization="\"Authorization: WHM root:$sourceaccesshash\""
      addhost="\"https://localhost:2087/xml-api/cpanel?user=$user&cpanel_xmlapi_user=$user&cpanel_xmlapi_module=Mysql&cpanel_xmlapi_func=addhost&cpanel_xmlapi_apiversion=1&arg-0=$grantip\""
      $ssh root@$sourceserver "
curl -s -k -H $authorization $addhost
      " >> $logfile 2>&1
    fi
    
  done
}

update_ipdata(){
  
  curl -s -k -H "Authorization: WHM root:$sourceaccesshash" "https://$sourceserver:2087/xml-api/listips" | sed -e :a -e N -e '$!ba' -e 's/\n/ /g' -e  "s/<result>/\\`echo -e '\n\r'`<result>/g" -e "s/<\!/\\`echo -e '\n\r'`<\!>/g" | sed -e 's/ //g' -e '/<listips>/d' -e '/<\!>/d' -e 's/<\/[^>]*>//g' -e 's/<result>//g' -e 's/</ </g' > $scripthome/.ipdatasource
  
  curl -s -k -H "Authorization: WHM root:$destaccesshash" "https://localhost:2087/xml-api/listips" | sed -e :a -e N -e '$!ba' -e 's/\n/ /g' -e  "s/<result>/\\`echo -e '\n\r'`<result>/g" -e "s/<\!/\\`echo -e '\n\r'`<\!>/g" | sed -e 's/ //g' -e '/<listips>/d' -e '/<\!>/d' -e 's/<\/[^>]*>//g' -e 's/<result>//g' -e 's/</ </g' > $scripthome/.ipdatadest
  
  sourcededicatedipcount="`cat $scripthome/.ipdatasource | grep -e "<used>1" | grep "<dedicated>1" | wc -l`"
  
  destavailableips="`cat $scripthome/.ipdatadest | grep -e "<used>0" | grep -e "<dedicated>1" | wc -l`"
  destnextavailableip="`cat $scripthome/.ipdatadest | grep -e "<used>0" | grep -e "<dedicated>1" | awk '{print $5}' | sed 's/<[^>]\+>//g' | head -1`"
  
}

check_dedicatedips(){
  if [[ $sourcededicatedipcount -eq  0 ]]; then
    echo "No dedicated IP addresses detected"
    dedicatedips="0"
  else
    if [[ $sourcededicatedipcount -gt  $destavailableips ]]; then
      echo "NOT ENOUGH IPS:"
      echo "Dedicated IPs Needed:  $sourcededicatedipcount           Dedicated IPs Available:  $destavailableips"
      echo "Would you like to proceed by copying all accounts with dedicated IPs to the Main IP? [y/N] "
      read -n 1 -r
      if [[ $REPLY =~ ^[Yy]$ ]]
      then
        echo "Operator chose override.  Ignoring dedicated IPs."
        dedicatedips="0"
      else
        echo "Operator chose abort.  Aborting script..."
        exit
      fi
    else
      echo "Dedicated IPs detected.  There is sufficient supply on the Destination."
      echo "Dedicated IPs Needed:  $sourcededicatedipcount           Dedicated IPs Available:  $destavailableips"
      echo "Assigning Dedicated IP addresses automatically"
      dedicatedips="1"
      $ssh root@$sourceserver "grep 'IP=' /var/cpanel/users/* | grep -v \"\`cat /var/cpanel/mainip\`\" | sed -e 's/\/var\/cpanel\/users\///g' -e 's/:IP=/ /g' " > $scripthome/.sourcededicatedaccounts
    fi
  fi
}

#############################################
### function error_check
#############################################
### This function checks the last segment of
### the logs for known errors.  It also looks
### for fail/bailout conditions
#############################################
error_check(){
  userid="`echo $logcheck | head -1 | awk {'print $2'}`"
  segment="`echo $logcheck | head -1 | awk {'print $1'}`"
  
  
  # GLOBAL CHECKS
  ###################
  #Critical checks
  ####################
  criticals="`echo \"$logcheck\" | egrep "putsomethinghere"`"
  if [[ ! $criticals == "" ]]; then
    echo -en "\E[30;41m Critical error(s) detected!\E[0m \n"
    echo "######!!!!! Critical error(s) detected! !!!!!#####" >> $logfile
    echo "$criticals" > >(tee --append $logfile)
    echo -en "\E[30;41m cP Migrations is bailing out \E[0m \n"
    exit
  fi
  ####################
  #Error checks
  ####################
  errors="`echo \"$logcheck\" | egrep \"putsomethinghere\"`"
  if [[ ! $errors == "" ]]; then
    echo -en "\E[40;31m Error(s) detected!\E[0m \n"
    echo "###### Error(s) detected! #####" >> $logfile
    echo "$errors" > >(tee --append $logfile)
    echo "cP Migrations is skipping further processing of $userid"
    stopcurrentuser="1"
    failedusers="$failedusers $userid"
  fi
  ####################
  #Warning checks
  ####################
  warnings=""
  warnings="$warnings `echo \"$logcheck\" | egrep \"/bin/gtar: Error\"`"
  if [[ ! $warnings == "" ]]; then
    #echo -en "\E[40;35m Warning(s) detected!\E[0m \n"
    echo "###### Warnings(s) detected! #####" >> $logfile
    echo "$warnings" >> $logfile
    warnusers="$warnusers $userid"
  fi
  
  #Phase Specific Checks
  #PHASE 1 - Packaging account
  #if [ $segment == '#@1#' ] ; then
  #echo > /dev/null
  #PHASE 2 - Transferring account
  #elif [ $segment = "#@2#" ] ; then
  #echo > /dev/null
  #PHASE 3 - Remove Package from source
  #elif [ $segment = "#@3#" ] ; then
  #echo > /dev/null
  #PHASE 4 - Rstoring account
  #elif [ $segment = "#@4#" ] ; then
  #echo > /dev/null
  #PHASE 5 - Remove package from destination
  #elif [ $segment = "#@6#" ] ; then
  #echo > /dev/null
  
  #fi
  echo "<plaintext> $logcheck </plaintext>" >> /var/cpanel/logs/copyacct_`echo $user`_`echo $sourceserver`_`echo $userepoch`_cPMigration
  logcheck=""
}
### END FUNCTION error_check

#############################################
### function after_action_report
#############################################
### This function prints and logs an after
### action report for the user at the end
### of the process.
#############################################
after_action_report(){
  logfile_afteraction="$scripthome/log/`date +%Y-%m-%y`-$epoch-after-action.txt"
  
  
  
  after_action_data="$after_action_data `echo \"cPMigration After-Action Report\" &> >(tee --append $logfile_afteraction)`"
  after_action_data="$after_action_data `echo \"  \" &> >(tee --append $logfile_afteraction)`"
  after_action_data="$after_action_data `echo \" Accounts that were migrated: \" &> >(tee --append $logfile_afteraction)`"
  after_action_data="$after_action_data `echo \"$verifiedusers\" &> >(tee --append $logfile_afteraction)`"
  after_action_data="$after_action_data `echo \"  \" &> >(tee --append $logfile_afteraction)`"
  after_action_data="$after_action_data `echo \" Accounts that were not migrated (see logs): \" &> >(tee --append $logfile_afteraction)`"
  after_action_data="$after_action_data `echo \"$missingusers\" &> >(tee --append $logfile_afteraction)`"
  
  cat $logfile_afteraction
  
}



#############################################
### get options
#############################################

while getopts ":s:p:a:i:l:kDhSR:" opt; do
  case $opt in
    s) sourceserver="$OPTARG";;
    p) sourceport="$OPTARG";;
    a) singlemode="1"; targetaccount="$OPTARG";;
    i) restoreipmode="1"; restoreip="$OPTARG";;
    l) listmode="1"; listfile="$OPTARG";;
    k) keeparchives=1;;
    D) develmode="1";;
    S) skipremotesetup="1";;
    h) print_help;;
    R) remotemysql="1";grantip="$OPTARG";;
    \?) echo "invalid option: -$OPTARG"; echo; print_help;;
    :) echo "option -$OPTARG requires an argument."; echo; print_help;;
  esac
done

if [[ $# -eq 0 || -z $sourceserver ]]; then print_help; fi  # check for existence of required var


#############################################
### initial checks
#############################################

# check for root
if [ $EUID -ne 0 ]; then
  echo 'cpmig must be run as root'
  echo; exit
fi

# check for resolving sourceserver
if [[ $sourceserver =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then :
  elif [[ -z $(dig $sourceserver +short) ]]; then
  echo "$sourceserver does not appear to be resolving"
  echo; exit 1
fi


#############################################
### Pre-Processing
#############################################

# print into
print_intro

# install sshpass
if [ ! -f $scripthome/.sshpass/sshpass-1.05/sshpass ]; then
  install_sshpass
fi

# set SSH/SCP commands
read -s -p "Enter source ($sourceserver) root password: " SSHPASSWORD; echo
sshpass="$scripthome/.sshpass/sshpass-1.05/sshpass -p $SSHPASSWORD"
if [[ $sourceport != '' ]]; then  # [todo] check into more elegant solution
  ssh="$sshpass ssh -p $sourceport -o StrictHostKeyChecking=no"
  scp="$sshpass scp -P $sourceport"
else
  ssh="$sshpass ssh -o StrictHostKeyChecking=no"
  scp="$sshpass scp"
fi

#Get access hashes (for API calls)
sourceaccesshash=`$ssh root@$sourceserver "cat ~/.accesshash" | tr -d "\n"`
destaccesshash=`cat ~/.accesshash | tr -d "\n"`

# Make working directory
mkdir_ifneeded $scripthome/log

# Define epoch time
epoch=`date +%s`

# Set logging mode
set_logging_mode

# Setup Remote Server
if [[ $skipremotesetup == "1" ]]; then
  echo "REMOTE SETUP SKIPPED" &> >(tee --append $logfile)
else
  setup_remote
fi

# Generate accounts list
generate_accounts_list

# initiate variables
failedusers=""
warnusers=""

# Set Remote MySQL variables
if [[ $remotemysql -eq 1 ]]; then
  echo "REMOTE MYSQL MODE" &> >(tee --append $logfile)
  forceremoterestore="--force"
  skipdbpkgacct="--skipdb"
fi


if [[ $control_panel = "cpanel" ]]; then
  #Get IP data
  update_ipdata
  
  # Check dedicated IPs
  check_dedicatedips
fi

#############################################
### Process loop
#############################################
process_loop
after_action_report
