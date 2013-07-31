#!/bin/bash
#  cPanel Migration Script "CopyPasta"
#  (c) 2013 cPanel, Inc
#  by Phil Stark
#
# Purpose:  to find all accounts existing on the Source server that do not exist
# on the destination server, package and transfer those accounts,  and restore
# them on the Destination  server automatically.  This is intended to use either
# in lieu of the WHM tools or as a followup to manually  package accounts that
# otherwise failed in WHM "Copy multiple accounts ..."
#
# usage: run on destination server
# $ sh copyscript <ticket> <sourceIP>
####################
# This script copies all accounts from the source server that do not exist
# on the destination server already.
# This should always be run on the destination server
# NOTE:  a RSA key should be set up Destination > Source before running
# this script for password-less login.
#############################################

#############################################
# Variables that need to be set for every ticket
#############################################
args=("$@")

# the relevant ticket number
ticket="${args[0]}";

# a RSA key should be set up Destination > Source before running this script for password-less login.
sourceserver="${args[1]}";

#############################################
# options operators
#############################################

# Package accounts on the source server
pkgaccounts=1

# Restore packages on the destination server
restorepkg=1

# Delete cpmove files from the source once transferred to the destination server
removesourcepkgs=0

# Delete cpmove files from the destination server once restored
removedestpkgs=0

#############################################
### Parse a list of accounts that need to be copied
#############################################

# Make cp ticket directory
mkdir /root/cp$ticket

# grab source accounts list
scp root@$sourceserver:/etc/trueuserdomains /root/cp$ticket/.sourcetudomains

# sort source accounts list
sort /root/cp$ticket/.sourcetudomains > /root/cp$ticket/.sourcedomains

# grab and sort local (destination) accounts list
sort /etc/trueuserdomains > /root/cp$ticket/.destdomains

# diff out the two lists,  parse out usernames only and remove whitespace.  Output to copyaccountlist :) 
diff -y /root/cp$ticket/.sourcedomains /root/cp$ticket/.destdomains | grep \< | awk -F':' '{ print $2 }' | sed -e 's/^[ \t]*//' | awk -F' ' '{ print $1 }' > /root/cp$ticket/.copyaccountlist


#############################################
# Process loop
#############################################
i=1
count=`cat /root/cp$ticket/.copyaccountlist | wc -l`
for user in `cat /root/cp$ticket/.copyaccountlist`
do
		progresspercent=`expr $i / $count` * 100
		echo Processing account $user.  $i/$count \($progresspercent%\)

		# Package accounts on source server (if set)
		if [ $pkgaccounts == 1 ]
			then
			ssh root@$sourceserver "/scripts/pkgacct $user;exit"	
		fi

		# copy (scp) the cpmove file from the source to destination server
		scp root@$sourceserver:/home/cpmove-$user.tar.gz /home/

		# Remove cpmove from source server (if set)
		if [ $removesourcepkgs == 1 ]
			then
			ssh root@$sourceserver "rm -f /home/cpmove-$user.tar.gz ;exit"	
		fi

		# Restore package on the destination server (if set)
		if [ $restorepkg == 1 ]
			then
			/scripts/restorepkg /home/cpmove-$user.tar.gz
		fi

		# Remove cpmove from destination server (if set)
		if [ $removedestpkgs == 1 ]
			then
			rm -f /home/cpmove-$user.tar.gz	
		fi		
		i=`expr $i + 1`
done
