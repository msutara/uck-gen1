# uck-gen1
Unifi Cloud Key Headless Debian Upgrade 

* Start first, by getting into recovery mode.  
* Once in recovery mode, reset to factory, then reboot.

* ssh into your Cloud Key.  Default Username/Password is ubnt/ubnt

* wget https://raw.githubusercontent.com/msutara/uck-gen1/main/update.sh -P ~/UCK/
* Modify the /etc/rc.local file to include this script to run after a reboot.
``` code
For example:
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

# Add your commands here
bash ~/UCK/update.sh

exit 0
```
* Make sure to make /etc/rc.local executable: chmod +x /etc/rc.local
* reboot
