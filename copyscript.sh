#!/bin/bash
# Original version written by Phil Stark
# Maintained and updated by Phil Stark and Blaine Motsinger
#
VERSION="1.0.19"
scripthome="/root/.copyscript"
#
# Purpose:  to find all accounts existing on the Source server that do not exist
# on the destination server, package and transfer those accounts,  and restore
# them on the Destination  server automatically.  This is intended to use either
# in lieu of the WHM tools or as a followup to manually  package accounts that
# otherwise failed in WHM "Copy multiple accounts ..."
#
# usage: run on destination server
# $ sh copyscript <sourceIP>
####################
# This script copies all accounts from the source server that do not exist
# on the destination server already.
# This should always be run on the destination server
# NOTE:  a RSA key should be set up Destination > Source before running
# this script for password-less login.
#############################################


#############################################
### functions
#############################################

print_intro(){
	echo 'copyscript'
	echo "version $VERSION"
        echo
}

print_help(){
	echo 'usage:'
	echo './copyscript -s <hostname or ip>'
	echo
	echo 'required:' 
	echo '-s <hostname or ip>, sourceserver'
	echo
	echo 'optional:'
	echo '-a <username or domain>, specify single account'
	echo '-l <filename>,  Read accounts from list'
	echo '-p sourceport'
	echo '-k keep archives on both servers'
	echo '-h displays this dialogue'
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
	diff -y $scripthome/.sourcedomains $scripthome/.destdomains | grep \< | awk -F':' '{ print $2 }' | sed -e 's/^[ \t]*//' | awk -F' ' '{ print $1 }' | grep -v "cptkt" > $scripthome/.copyaccountlist
}

mkdir_ifneeded(){
	if [ ! -d $1 ]; then
		mkdir -p $1
	fi
}

set_logging_mode(){
	logfile="$scripthome/log/$epoch.log"
	case "$1" in
		verbose)
			logoutput="&> >(tee --append >((sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' >> $logfile)))"
			;;
		*)
			logoutput=">> $logfile "
			;;
	esac
}

setup_remote(){
   control_panel=`$ssh root@$sourceserver "if [ -e /usr/local/psa/version	 ];then echo plesk; elif [ -e /usr/local/cpanel/cpanel ];then echo cpanel; elif [ -e /usr/bin/getapplversion ];then echo ensim; elif [ -e /usr/local/directadmin/directadmin ];then echo da; else echo unknown;fi;exit"` >> $logfile 2>&1
	#echo "Checking remote server control panel: $control_panel" 
	#echo "CONTROL PANEL: $control_panel"
	if [[ $control_panel = "cpanel" ]]; then : echo "Source is cPanel,  nothing special to do"  # no need to bring over things if cPanel#
	elif [[ $control_panel = "plesk" ]]; then  # wget or curl from httpupdate
		echo "The Source server is Plesk!"  &> >(tee --append >((sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' >> $logfile)))
		echo "Setting up scripts, Updating user domains" &> >(tee --append >((sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' >> $logfile)))
		$ssh root@$sourceserver "
		if [[ ! -d /scripts ]]; then 
		mkdir /scripts ;fi; 
		if [[ ! -f /scripts/pkgacct ]]; then 
		wget http://httpupdate.cpanel.net/cpanelsync/transfers_PUBLIC/pkgacct/pkgacct-pXa -P /scripts;
		mv /scripts/pkgacct-pXa /scripts/pkgacct;
		chmod 755 /scripts/pkgacct
		fi;
		if [[ ! -f /scripts/updateuserdomains-universal ]]; then
		wget http://httpupdate.cpanel.net/cpanelsync/transfers_PUBLIC/pkgacct/updateuserdomains-universal -P /scripts;
		chmod 755 /scripts/updateuserdomains-universal;
		fi;
		/scripts/updateuserdomains-universal;" >> $logfile 2>&1
	elif [[ $control_panel = "ensim" ]]; then
		echo "The Source server is Ensim!"  &> >(tee --append >((sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' >> $logfile)))
		echo "Setting up scripts, Updating user domains" &> >(tee --append >((sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' >> $logfile)))
		$ssh root@$sourceserver "
		if [[ ! -d /scripts ]]; then 
		mkdir /scripts ;fi; 
		if [[ ! -f /scripts/pkgacct ]]; then 
		wget http://httpupdate.cpanel.net/cpanelsync/transfers_PUBLIC/pkgacct/pkgacct-enXim -P /scripts;
		mv /scripts/pkgacct-enXim /scripts/pkgacct;
		chmod 755 /scripts/pkgacct
		fi;
		if [[ ! -f /scripts/updateuserdomains-universal ]]; then
		wget http://httpupdate.cpanel.net/cpanelsync/transfers_PUBLIC/pkgacct/updateuserdomains-universal -P /scripts;
		chmod 755 /scripts/updateuserdomains-universal;
		fi;
		/scripts/updateuserdomains-universal;" >> $logfile 2>&1
	elif [[ $control_panel = "da" ]]; then
		echo "The Source server is Direct Admin!"  &> >(tee --append >((sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' >> $logfile)))
		echo "Setting up scripts, Updating user domains" &> >(tee --append >((sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' >> $logfile)))
		$ssh root@$sourceserver "
		if [[ ! -d /scripts ]]; then 
		mkdir /scripts ;fi; 
		if [[ ! -f /scripts/pkgacct ]]; then 
		wget http://httpupdate.cpanel.net/cpanelsync/transfers_PUBLIC/pkgacct/pkgacct-dXa -P /scripts;
		mv /scripts/pkgacct-dXa /scripts/pkgacct;
		chmod 755 /scripts/pkgacct
		fi;
		if [[ ! -f /scripts/updateuserdomains-universal ]]; then
		wget http://httpupdate.cpanel.net/cpanelsync/transfers_PUBLIC/pkgacct/updateuserdomains-universal -P /scripts;
		chmod 755 /scripts/updateuserdomains-universal;
		fi;
		/scripts/updateuserdomains-universal;" >> $logfile 2>&1
	fi
}


process_loop(){
        logfile="$scripthome/log/`date +%Y-%m-%y`-$epoch.log"

        # Override the normal accounts list if we're in Single user mode
        if [[ $singlemode -eq "1" ]]; then
                grep $targetaccount $scripthome/.sourcetudomains | head -1 | awk '{print $2}' > $scripthome/.copyaccountlist;
        fi
        
        if [[ $listmode -eq "1" ]]; then
                echo > $scripthome/.copyaccountlist
                for targetaccount in `cat $listfile`
                do
                        grep $targetaccount $scripthome/.sourcetudomains | head -1 | awk '{print $2}' >> $scripthome/.copyaccountlist;
                done
        fi

        i=1
        count=`cat $scripthome/.copyaccountlist | wc -l`
        
        for user in `cat $scripthome/.copyaccountlist`; do
                progresspercent=`echo $i $count | awk '{print ( $1 - 1 ) / $2 * 100}'`
                echo -en "\E[40;32m############### \E[40;33mProcessing account \E[40;37m$user \E[40;33m$i/$count \\E[40;33m(\E[40;32m$progresspercent% \E[40;33mCompleted) \E[40;32m################\E[0m \n"
                #Adding a log marker
                echo "################################################################" >> $logfile
                echo "################################################################" >> $logfile
                echo "################################################################" >> $logfile
                echo "#@B# $user BEGIN $i/$count" >> $logfile          
                sleep 1;
                echo -en "\E[40;34mPackaging account on source server...\E[0m \n"
                #Adding a log marker
                logcheck="$logcheck `echo \"#@1# $user - Packaging on Source\" &> >(tee --append $logfile)`"
				logcheck="$logcheck `$ssh root@$sourceserver \"/scripts/pkgacct $user;exit\" &> >(tee --append $logfile)`"
                error_check


                # copy (scp) the cpmove file from the source to destination servcd /er
                
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
                        logcheck="$logcheck `$ssh root@$sourceserver 'rm -f /home/cpmove-$user.tar.gz ;exit' &> >(tee --append $logfile)`"
                        error_check
                fi


                # Restore package on the destination server (if set)
                echo -en "\E[40;34mRestoring the package to the destination...\E[0m \n"
                #Adding a log marker
                logcheck="$logcheck `echo \"#@4# $user - Restoring package\" &> >(tee --append $logfile)`"
                logcheck="$logcheck `/scripts/restorepkg /home/cpmove-$user.tar.gz &> >(tee --append $logfile)`"
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
        done
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
        ####################
        #Critical checks
        ####################
        criticals="`echo \"$logcheck\" | egrep "Critical error strings here"`"
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
        errors="`echo \"$logcheck\" | egrep \"error|Error\"`"
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
        warnings="`echo \"$logcheck\" | egrep \"Warning|warning\"`"
        if [[ ! $errors == "" ]]; then
            echo -en "\E[40;35m Warning(s) detected!\E[0m \n"
            echo "###### Warnings(s) detected! #####" >> $logfile
            echo "$warnings" > >(tee --append $logfile)
            warnusers="$warnusers $userid"
        fi

        #Phase Specific Checks
        	#PHASE 1 - Packaging account
            if [ $segment == '#@1#' ] ; then
            echo > /dev/null
        	#PHASE 2 - Transferring account
        	elif [ $segment = "#@2#" ] ; then
        	echo > /dev/null
           #PHASE 3 - Remove Package from source
        	elif [ $segment = "#@3#" ] ; then
        	echo > /dev/null
        	#PHASE 4 - Rstoring account
        	elif [ $segment = "#@4#" ] ; then
        	echo > /dev/null
        	#PHASE 5 - Remove package from destination
        	elif [ $segment = "#@6#" ] ; then
        	echo > /dev/null

        fi
        logcheck=""
}
### END FUNCTION error_check

#############################################
### get options
#############################################

while getopts ":s:p:a:l:kh" opt; do
	case $opt in
        	s) sourceserver="$OPTARG";;
        	p) sourceport="$OPTARG";;
        	a) singlemode="1"; targetaccount="$OPTARG";;
        	l) listmode="1"; listfile="$OPTARG";;
        	k) keeparchives=1;;
        	h) print_help;;
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
	echo 'copyscript must be run as root'
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

# Make working directory
mkdir_ifneeded $scripthome/log

# Define epoch time
epoch=`date +%s`

# Set logging mode
set_logging_mode

#Setup Remote Server
setup_remote

# Generate accounts list
generate_accounts_list

# initiate variables
failedusers=""
warnusers=""

#############################################
### Process loop
#############################################
process_loop
