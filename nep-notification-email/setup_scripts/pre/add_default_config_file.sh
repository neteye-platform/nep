#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function add_config_file() {
    FILE="/neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.cfg"


    if [ -f $FILE ]; then
        echo "Config file '$FILE' already present... Nothing to do."
    else
    cat << EOF >> $FILE
# This is the logo image file, the path must point to a valid JPG, GIF or PNG file, i.e.
# the Monitor logo or your company logo or whatelse. Best size is rectangular up to 160x80px.
# example: /var/www/html/images/our_company_logo-112x46.png

our \$logofile = "/usr/share/icingaweb2/public/img/neteye/neteye-logo.png";

# SMTP related data: If the commandline argument -H/--smtphost was not
# given, we use the provided value in \$smtphost below as the default.
# If the mailserver requires auth, an example is further down the code.

our \$smtphost = "127.0.0.1";

# Here I define the HTML color values for each Nagios notification type.
# The color values are used for highlighting the background of the
# notification type cell.

our %NOTIFICATIONCOLOR=('PROBLEM'=>'#FF8080',
                       'PROBLEM_WARN'=>'#FFFF80',
                       'RECOVERY'=>'#80FF80',
                       'ACKNOWLEDGEMENT'=>'#FFFF80',
                       'DOWNTIMESTART'=>'#80FFFF',
                       'DOWNTIMEEND'=>'#80FF80',
                       'DOWNTIMECANCELLED'=>'#FFFF80',
                       'FLAPPINGSTART'=>'#FF8080',
                       'FLAPPINGSTOP'=>'#80FF80',
                       'FLAPPINGDISABLED'=>'#FFFF80',
                       'CRITICAL'=>'#FFEBEB',
                       'WARNING'=>'#FFFFC0',
                       'OK'=>'#C0FFC0',
                       'UNKNOWN'=>'#FFDDBB',
                       'UP'=>'#C0FFC0',
                       'DOWN'=>'#FFEBEB',
                       'UNREACHABLE'=>'#FFDDBB');


our \$tablelabel = "#000000";

EOF

    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_config_file
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        SERVICE="icinga2-master"
        if systemctl is-active "$SERVICE" > /dev/null ; then
            add_config_file
        else
            echo "[i] Inactive Cluster Node. Skipping."
        fi

        exit 0
    fi
    if [[ $neteye_node_type == 'elastic_only' ]]; then
        exit 0
    fi
    if [[ $neteye_node_type == 'voting_only' ]]; then
        exit 0
    fi
fi
if [[ $neteye_deployment == 'satellite' ]]; then
    exit 0
fi


# This point should never be reached!
# Ensure all possible execution branches are managed.
echo '[!] Fatal: You should not see me!'
exit 255
