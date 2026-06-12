The service checks in this nep modulue are based on check_snmp and specific SNMP OIDs and needs Sophos SNMP MIB installation on your NetEye system.

- You can download the MIB from https://docs.sophos.com/nsg/sophos-firewall/MIB/SOPHOS-XG-MIB.zip
- Sophos SNMP manual reference: https://docs.sophos.com/nsg/sophos-firewall/18.0/Help/en-us/webhelp/onlinehelp/nsg/sfos/concepts/AdministrationSNMP.html?hl=mib#concept_rrc_3sl_4y__mz3_nm1_vhb
- You need to copy the MIB file in /usr/share/snmp/mibs in all NetEye node(s)


Custom variable to be set:

- nx_hardware_vendor: Sophos

Tested on:

- Firmware > 18.0
- Series XG