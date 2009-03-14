#! /bin/sh
#
# Safekeep client script
# API:	$1 = Step, $2 = Safekeep ID, $3 = Backup Root Directory
#
# Sample script, please configure as appropriate for your site.
#
# Note: output from this script is normally only seen in debug mode.
#

case $1 in
'STARTUP') mail -s "Safekeep Backup: Started $2" root < /dev/null ;;
'PRE-SETUP') ;;
'POST-SETUP') /etc/init.d/autofs condrestart 2>&1 | mail -s "Safekeep Backup: $1 $2" root ;;
'POST-BACKUP') /etc/init.d/autofs condrestart 2>&1 | mail -s "Safekeep Backup: $1 $2" root ;;
'POST-SCRUB') ;;
esac

exit 0
