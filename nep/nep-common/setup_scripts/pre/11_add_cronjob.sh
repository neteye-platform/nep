#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
function add_crontab_for_holidays() {
crontab_line="* 0 1 * * systemctl is-active icinga-director && sh /usr/share/icingaweb2/modules/nep/support-scripts/holidays/run_holiday.sh"
	echo 'search in cronjob for holiday generation'

	crontab -l 2>/dev/null | grep '/usr/share/icingaweb2/modules/nep/support-scripts/holidays/run_holiday.sh'
	if [ $? -eq 1 ]; then
		echo "Add line at crontab: $crontab_line"
		(crontab -l 2>/dev/null; echo "$crontab_line") | crontab -
	else
		"cronjob found nothing to do"
	fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    add_crontab_for_holidays
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        add_crontab_for_holidays
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