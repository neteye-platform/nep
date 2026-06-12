# VMWare VMD
The `nep-vmware-vmd` uses NetEye VMD module to deliver VMware monitoring without further access to the VMware infrastructure. With this package, it is possible to monitor:

* VMware Host Systems
* VMware Virtual Machines
* VMware datastores

It has also the ability to automatically create Monitoring Objects, including parent-child relationships, using Icinga Director Automations.

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.25 |
| nep-common | |
| nep-vmware-api | |


##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |
| VMD |


### External dependencies

To perform monitoring, this package makes direct queries to the underlying MariaDB of NetEye. To avoid issues, consider increasing the maximum number of connections that MariaDB allows is adequate. To increase the maximum number of allowed connections, set the `max_connections` variable of `my.cnf` file at an adequate value. Depending on how much objects are monitored, adequate means from a minimum of 200 to a maximum of some thousands.

```
[mysqld]
max_connections=200
```

## Installation

If all requirements are met, you can now install this package.

### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-vmware-vmd
```
#### Finalizing Installation

Find the user and password here:
Go to file /neteye/shared/icingaweb2/conf.resources.ini
Go to [vspheredb] section
Get username (by default, it is vspheredb) and password from that section
Antoher way is to ask to VMWare admin user and password.
Create the following file
```
/neteye/shared/monitoring/plugins/check_vmd_object.conf
```
And insert the username and password
```
username=vsperedb
password=xxxxx
```

## Packet Contents

This section contains a description of all the Objects from this package that can be used to build your own monitoring environment.

### Director/Icinga Objects

#### Host Templates

| Host Template name | Description |
| --- | ----------- |
| nx-ht-status-vmd | Determine the status of a Host Object using the Power Status from VMD. It applyes only to VMs |
| nx-ht-vmd-host-system | Describe a Host System that should be monitored using VMD |
| nx-ht-vmd-vcsa | Describe a VCSA that VMD uses as a gateway to get monitoring data. Only reachability is monitored |
| nx-ht-vmd-virtual-machine | Describe a Virtual Machine that should be monitored using VMD |

#### Service Templates

| Service Template name | Run on Agent | Description |
| --- | --- | -------------|
| nx-st-agentless-vmd | NO | Checks all aspects of a VMD-monitored Object |
| nx-st-agentless-vmd-datastore | NO | Specific version of `nx-st-agentless-vmd` for Datastores |


#### Sercices Sets

| Service Set name | Description |
| --- | -------------|
| nx-ss-vmware-vmd-host-system-status | Monitor all basic aspects of a Host System |
| nx-ss-vmware-vmd-virtual-machine-status | Monitor all basic aspects of a Virtual Machine |

#### Command

* nx-c-check-vmd-object

#### Automation

| Type | Automation name | Description |
| --- | ------------- | ------------- |
| Import Source | nx-is-vmd-datastore | Gets all available Datastores from VMD |
| Import Source | nx-is-vmd-host-system | Gets all available Host Systems from VMD |
| Import Source | nx-is-vmd-vcsa | Gets all available VCSA from VMD |
| Import Source | nx-is-vmd-virtual-machines | Gets all available Virtual Machines from VMD |
| Sync Rule | nx-sr-vmd-datastore | Creates SO to monitor all avilable Datastores |
| Sync Rule | nx-sr-vmd-host-system | Creates HO to monitor all available Host Systems |
| Sync Rule | nx-sr-vmd-vcsa | Creates HO to monitor availability of all available VCSA |
| Sync Rule | nx-sr-vmd-virtual-machines | Creates HO to monitor all available Virtual Machines |
