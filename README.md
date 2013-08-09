copyscript
==========

copyscript is a tool created to streamline the manual migration process, moving accounts from Plesk, DirectAdmin, and Ensim, to cPanel.

### usage

<code>
./copyscript -s <hostname or ip>
        
required:
-s <hostname or ip>, sourceserver

optional:
-a <username or domain>, single account mode
-p sourceport
-k keep archives on both servers
-h displays this dialogue
</code>
