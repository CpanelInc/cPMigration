#!/bin/bash
# Original version written by Phil Stark
# Maintained and updated by Phil Stark and Blaine Motsinger
#
VERSION="1.0.15"
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
}

print_help(){
	echo 'usage:'
	echo './copyscript -s <hostname or ip>'
	echo
	echo 'required:' 
	echo '-s <hostname or ip>, sourceserver'
	echo
	echo 'optional:'
	echo '-a <username or domain>, single account mode'
	echo '-p sourceport'
        echo '-k keep archives on both servers'
	echo '-h displays this dialogue'
	echo; echo; exit 1
}

install_sshpass(){
	mkdir_ifneeded $scripthome/.sshpass
	cd $scripthome/.sshpass
	wget -P $scripthome/.sshpass/ http://downloads.sourceforge.net/project/sshpass/sshpass/1.05/sshpass-1.05.tar.gz
	tar -zxvf $scripthome/.sshpass/sshpass-1.05.tar.gz -C $scripthome/.sshpass/
	cd $scripthome/.sshpass/sshpass-1.05/
	./configure
 	make
}

generate_accounts_list(){
	# grab source accounts list
	$scp root@$sourceserver:/etc/trueuserdomains $scripthome/.sourcetudomains

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
			logoutput="> >(tee --append $logfile )"
			;;
		*)
			logoutput=">> $logfile "
			;;
	esac
}

setup_remote(){
        control_panel=`$ssh root@sourceserver "if [ -e /usr/local/psa/version ];then echo plesk; elif [ -e /usr/local/cpanel/cpanel ];then echo cpanel; elif [ -e /usr/bin/getapplversion ];then echo ensim; elif [ -e /usr/local/directadmin/directadmin ];then echo da; else echo unknown;fi;exit"`
	if [ $control_panel -eq 'cpanel' ]; then :  # no need to bring over things if cPanel#
	elif [ $control_panel -eq 'plesk' ]; then  # wget or curl from httpupdate
		echo # What stuff do we send over?  What scripts need to be run in preparation?
	elif [ $control_panel -eq 'ensim' ]; then
		echo # What stuff do we send over?  What scripts need to be run in preparation?
	elif [ $control_panel -eq 'da' ]; then
		echo # What stuff do we send over?  What scripts need to be run in preparation?
	else echo 'your source control panel isnt supported at this time' ; exit
	fi
}


process_loop(){
        logfile="$scripthome/log/$epoch.log"
        logoutput=">> $logfile "

        # Override the normal accounts list if we're in Single user mode
        if [[ $singlemode -eq "1" ]]; then
                grep $targetaccount $scripthome/.sourcetudomains | head -1 | awk '{print $2}' > $scripthome/.copyaccountlist;
        fi

        i=1
        count=`cat $scripthome/.copyaccountlist | wc -l`

        for user in `cat $scripthome/.copyaccountlist`; do
                progresspercent=`echo $i $count | awk '{print ( $1 - 1 ) / $2 * 100}'`
                echo Processing account $user.  $i/$count \($progresspercent% Completed\) > >(tee --append $logfile )

                # Package accounts on source server
                echo "Packaging account on source server..."  > >(tee --append $logfile )
                $ssh root@$sourceserver "/scripts/pkgacct $user;exit"   >> $logfile

                # copy (scp) the cpmove file from the source to destination server
                echo "Copying the package from source to destination..."  > >(tee --append $logfile )
                $scp root@$sourceserver:/home/cpmove-$user.tar.gz /home/ >> $logfile

                # Remove cpmove from source server (if set)
                if [[ $keeparchives == 1 ]]; then :
		else
                        echo "Removing the package from the source..."  > >(tee --append $logfile )
                        $ssh root@$sourceserver "rm -f /home/cpmove-$user.tar.gz ;exit"  >> $logfile
                fi

                # Restore package on the destination server (if set)
                echo "Restoring the package to the destination..."  > >(tee --append $logfile )
                /scripts/restorepkg /home/cpmove-$user.tar.gz >> $logfile

                # Remove cpmove from destination server (if set)
                if [[ $keeparchives == 1 ]]; then :
		else
                        echo "Removing the package from the destination..."  > >(tee --append $logfile )
                        rm -fv /home/cpmove-$user.tar.gz         >> $logfile
                fi
                i=`expr $i + 1`
        done
}


#############################################
### get options
#############################################

while getopts ":s:p:a:kh" opt; do
	case $opt in
        	s) sourceserver="$OPTARG";;
        	p) sourceport="$OPTARG";;
        	a) singlemode="1"; targetaccount="$OPTARG";;
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

# install sshpass
if [ ! -f $scripthome/.sshpass/sshpass-1.05/sshpass ]; then
	install_sshpass
fi

# set SSH/SCP commands
read -s -p "Enter Source server's root password:" SSHPASSWORD
sshpass="$scripthome/.sshpass/sshpass-1.05/sshpass -p $SSHPASSWORD"
if [[ $sourceport != '' ]]; then  # [todo] check into more elegant solution
	ssh="$sshpass ssh -p $sourceport"
	scp="$sshpass scp -P $sourceport"
else
	ssh="$sshpass ssh"
	scp="$sshpass scp"
fi

# Make working directory
mkdir_ifneeded $scripthome/log

# Define epoch time
epoch=`date +%s`

# Generate accounts list
generate_accounts_list

# Set logging mode
set_logging_mode


#############################################
### Process loop
#############################################
process_loop
