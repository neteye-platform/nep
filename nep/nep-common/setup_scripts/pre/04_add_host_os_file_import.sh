#!/usr/bin/env bash

# Load and test arguments from command line
NEP_STAGE_DIR=/usr/share/neteye/nep/
SETUP_LIBRARY=${NEP_STAGE_DIR}/setup/library
. ${SETUP_LIBRARY}/setup_scripts/get_arguments_from_command_line.sh


##########################################
## Script main code: add your code here ##
##########################################
. /usr/share/neteye/scripts/rpm-functions.sh

function create_default_os_list() {
    SERVICE="php-fpm"
    if systemctl is-active "$SERVICE" > /dev/null; then
        echo "[i] Check default OS list"

        FILE="/neteye/shared/icingaweb2/data/modules/fileshipper/nx-file-data/nx-host_os-list.csv"

        if [ -f $FILE ]; then
            echo " - Default OS list already present... Nothing to do."
        else
            echo " - Creating Default OS list as FileShipper file source."
        cat << EOF >> $FILE
"entry_name","entry_value","format","allowed_roles"
linux_centos_6,"Linux CentOS 6",string,null
linux_centos_7,"Linux CentOS 7",string,null
linux_debian_8,"Linux Debian 8",string,null
linux_debian_9,"Linux Debian 9",string,null
linux_debian_10,"Linux Debian 10",string,null
linux_debian_11,"Linux Debian 11",string,null
linux_debian_12,"Linux Debian 12",string,null
linux_opensuse_leap_15,"Linux OpenSUSE Leap 15",string,null
linux_opensuse_tumbleweed,"Linux OpenSUSE Tumbleweed",string,null
linux_redhat_6,"Linux Red Hat Enterprise 6",string,null
linux_redhat_7,"Linux Red Hat Enterprise 7",string,null
linux_redhat_8,"Linux Red Hat Enterprise 8",string,null
linux_redhat_9,"Linux Red Hat Enterprise 9",string,null
linux_suse_sles_11,Linux SUSE SLES 11,string,null
linux_suse_sles_12,Linux SUSE SLES 12,string,null
linux_suse_sles_15,Linux SUSE SLES 15,string,null
linux_ubuntu_20,Linux Ubuntu 22,string,null
linux_ubuntu_22,Linux Ubuntu 20 LTS,string,null
linux_ubuntu_23,Linux Ubuntu 23,string,null
linux_ubuntu_24,Linux Ubuntu 24 LTS,string,null
linux_ubuntu_26,Linux Ubuntu 26 LTS,string,null
windows_server_2003,"Windows Server 2003",string,null
windows_xp_professional,"Windows XP Professional",string,null
windows_7_professional,"Windows 7 Professional",string,null
windows_10_home,"Windows 10 Home",string,null
windows_10_pro,"Windows 10 Pro",string,null
windows_10_enterprise,"Windows 10 Enterprise",string,null
windows_11_home,"Windows 11 Home",string,null
windows_11_pro,"Windows 11 Pro",string,null
windows_11_enterprise,"Windows 11 Enterprise",string,null
windows_embedded_standard,"Windows Embedded Standard",string,null
windows_server_2008_r2_standard,"Windows Server 2008 R2 Standard",string,null
windows_server_2008_standard,"Windows Server 2008 Standard",string,null
windows_server_2012_r2_standard,"Windows Server 2012 R2 Standard",string,null
windows_server_2012_standard,"Windows Server 2012 Standard",string,null
windows_server_2016_standard,"Windows Server 2016 Standard",string,null
windows_server_2016_datacenter,"Windows Server 2016 Datacenter",string,null
windows_server_2019_standard,"Windows Server 2019 Standard",string,null
windows_server_2019_datacenter,"Windows Server 2019 Datacenter",string,null
windows_server_2019_standard_evaluation,"Windows Server 2019 Standard Evaluation",string,null
windows_server_2022_standard,"Windows Server 2022 Standard",string,null
windows_server_2022_datacenter,"Windows Server 2022 Datacenter",string,null
windows_server_2025_standard,"Windows Server 2025 Standard",string,null
windows_server_2025_datacenter,"Windows Server 2025 Datacenter",string,null
ibm_imm,"IBM IMM",string,null
hp_oneview,"HP OneView",string,null
hp_bladechassis,"HP Blade Chassis",string,null
EOF
        fi
    else
        echo "[i] Icingaweb2 is not active. Skipping."
    fi
}

if [[ $neteye_deployment == 'single_node' ]]; then
    create_default_os_list
    exit 0
fi
if [[ $neteye_deployment == 'cluster' ]]; then
    if [[ $neteye_node_type == 'node' ]]; then
        create_default_os_list
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