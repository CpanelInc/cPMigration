CPMigration
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

### Logging

    All cPMigration logging goes to /root/.cpmig/logs .  
    
    There are two files generated for each migration in the following likeness:
    
    2013-08-13-1377862253-after-action.txt
    2013-08-13-1377862253.log

    The after-action.txt is an output of the migration summary,  containing
    information about what accounts were successfull and which ones failed.
    
    The .log file contains all the raw logs from all the migrations performed in the
    cPMigration run.  If there was a problem,  this is the place to look.
    
### Per-User Logging
    
    In addition to the normal logging,  a migration log is also generated per-user
    and placed at /var/cpanel/logs/ .  These can be conveniently accessed in WHM
    "Review Copied Accounts"
    
