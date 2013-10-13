cPMigration
==========

cPMigration is a CLI tool created to streamline the migration process to cPanel
managed servers.  This tool is designed for migrating accounts from Plesk,
DirectAdmin, and Ensim, and even other cPanel servers to the Destination server
from where it is running.

### usage

    ./cpmig -s <hostname or ip> [options]
        
    required:
    -s <hostname or ip>, sourceserver

    optional:
    -p sourceport    
    -a <username or domain>, specify single account
    -l <filename>,  Read accounts from list
    -k keep archives on both servers
    -D use DEVEL scripts on remote setup (3rdparty)
    -S skip remote setup
    -h displays this dialogue

### Options

    -s  -   Source server
            This option specifies the Source server for the migration.  Without
            any additional options,  this will run a migration in default operation.
            
            Example:
            ./cpmig -s 192.168.0.10
            
    -p  -   Source Port
            This option specifies the SSH port on the Source server.  If not set,
            the default is port 22.
            
            Example:
            ./cpmig -s 192.168.0.10 -p 2200
            
    -a  -   Specify Single Account or domain
            Use this option when wanting to only migrate a single account
            
            Example:
            ./cpmig -s 192.168.0.10 -a domuser
            -or-
            ./cpmig -s 192.168.0.10 -a domain.com
            
    -l  -   Read accounts from a list
            When you have a specific list of accounts to migrate,  use this option.
            
            Example:
            ./cpmig -s 192.168.0.10 -l /root/accountlist.com
            
            Contents of /root/accountlist.com:
            domain.com
            domuser
            someguy
            pleasecheck.net
            
            (Note:  Each account can be located by either their domain name or 
            username)
            
    -k  -   Keep archives
            This option prevents the script from deleting the cpmove tar.gz files 
            after it's done with them.
            
    -D  -   Use DEVEL scripts for remote scripts used on third party migrations.
            This option allows the script to use the DEVEL tree for pkgacct instead 
            of PUBLIC
            
    -S  -   Skip remote setup
            This option skips remote setup entirely.  Useful if the scripts on the 
            Source are modified.
            
    -h  -   Displays the help dialogue.

### Default operation

    The default operation of this script is specifically when the script is started
    with the minimal required parameters.  For example:
    
    ./cpmig -s 192.168.0.10
    
    The default operation is as follows:
    
    * Install sshpass for cpmig if not already done
    * Promt user for Source server password
    * Connect to the Source server,  determine it's type,  and set up remote scripts
    (if necessary)
    * Compare a list of accounts from the Destination and the Source to build a list
    of all accounts that do not already exist on the Destination server.
    * Run the process loop on the listed accounts.
    
    Process Loop:
    
    The process loop consists of five phases.
    
    1) Package the account on the Source server.
    2) Transfer the account package from the Source to the Destination server.
    3) Delete the account package from the Source server.
    4) Restore the account package to the Destination server.
    5) Delete the account package from the Destination server.
    
    Error checking is done at every phase of the process and the end of the process
    loop itself.


### Logging

    All cPMigration logging goes to /root/.cpmig/logs .  
    
    There are three files generated for each migration in the following likeness:
    
    2013-08-13-1377862253-after-action.txt
    2013-08-13-1377862253-status.txt
    2013-08-13-1377862253.log

    The after-action.txt is an output of the migration summary,  containing
    information about what accounts were successfull and which ones failed.
    
    The status.txt contains a simple list of usernames indicating whether they had
    "FAILED" or were "OK".
    
    The .log file contains all the raw logs from all the migrations performed in the
    cPMigration run.  If there was a problem,  this is the place to look.
    
### Per-User Logging
    
    In addition to the normal logging,  a migration log is also generated per-user
    and placed at /var/cpanel/logs/ .  These can be conveniently accessed in WHM
    "Review Copied Accounts"
    
