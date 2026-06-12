# NEP Network Dell iDRAC
_The nep-network-dell-idrac provides the minimum requirements to implement a basic monitoring of a iDRAC using SNMP protocol._


# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.28 |
| nep-common | 0.0.6 |
| nep-centreon-plugins-base | 0.0.5 |
| nep-network-base |  0.0.6 |

##### Required NetEye Modules

| NetEye Module |
| --- |
| - Core|


### External dependencies

This Package requires installation of Centreon Plugin for Dell iDRAC via SNMP (`centreon-plugin-Hardware-Servers-Dell-IDrac-Snmp`).
On NetEye Environment, this operation is automatically dione by Setup Routine.


### NEP Installation

To install this package, just use `nep-setup` utility:

```
nep-setup install nep-network-dell-idrac
```


## Packet Contents

This section contains a description of all the Objects from this package that can be used to build your own monitoring environment.


### Director/Icinga Objects

| Datalist name | Description |
| --- | --- |
| [NX] Centreon Network Dell iDRAC SNMP Mode List | List of Modes supported by the Monitoring Plugin|


#### Host Templates

This Package does not provide any Host Template. It is suggested to use Host Template `nx-ht-network-ipmi-snmp` provided by NEP `nep-network-base`


#### Service Templates

| Service Template name | Description |
|---|---|
| nx-st-agentless-snmp-centreon-network-dell-idrac-snmp | Provides mointoring of Dell iDRAC |


#### Sercices Sets

| Service Set name | Description |
| --- | --- |
| nx-ss-network-idrac-base | Basic checks for a Dell iDRAC |
| nx-ss-network-dell-idrac-snmp | Obsolete SS, do not use |

#### Command

- nx-c-centreon-dell-idrac-snmp


### Examples
_Usage examples_
```
'/usr/lib/centreon/plugins/centreon_dell_idrac.pl' '--hostname' '192.168.1.1' '--mode' 'hardware' '--snmp-community' 'my_community' '--snmp-timeout' '30' '--snmp-version' '2c'
CRITICAL: Enclosure 'BP12G+ 0:1' status is 'critical' - physical disk 'Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1' state is 'failed' | 'hardware.enclosure.count'=1;;;; 'hardware.fru.count'=6;;;; 'hardware.health.count'=1;;;; 'hardware.memory.count'=2;;;; 'hardware.network.count'=4;;;; 'hardware.pci.count'=23;;;; 'hardware.pdisk.count'=4;;;; 'hardware.processor.count'=2;;;; 'hardware.slot.count'=1;;;; 'hardware.storagebattery.count'=1;;;; 'hardware.storagectrl.count'=1;;;; 'hardware.vdisk.count'=1;;;;
```

