# VMWare Api
The nep-vmware-api provides the minimum requirements to implement VMWare Environment monitoring through VCSA and Directly

Using the provided objects, is possible to: - Cluster monitoring - ESXi monitoring - ESXi monitoring (used also with VMD Module) - ESXi monitoring Directly - vCenter Basic Service monitored - vCenter Basic Service monitored directly - vCenter Snapshots monitoring (age and count)

Using the provided objects, is possible to:

* CPU Usage
* Memory Usage
* Host Connected
* CPU Usage
* Runtime Status
* Runtime Issues
* Uptime
* NET Usage
* Disk IO Stats Read
* Disk IO Stats Write
* Swap Usage
* VMFS
* Snapshot age
* Snapshot count

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.20 |
| nep-common | 0.0.3 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |


### External dependencies

To use the command you need to add the auth file under the Icinga2 dir, with NetEye this will be done by Setup like code below:

```
mkdir -p /neteye/shared/icinga2/conf/vmware-auth-files/
touch /neteye/shared/icinga2/conf/vmware-auth-files/generic-vcsa
chown -R root:icinga /neteye/shared/icinga2/conf/vmware-auth-files

cat /neteye/shared/icinga2/conf/vmware-auth-files/generic-vcsa
username=XXXX@
password=
chmod 640 /neteye/shared/icinga2/conf/vmware-auth-files/generic-vcsa
```
NB. The user should have permission read-only to all the VCSA Objects

## Installation

If all requirements are met, you can now install this package.

### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-vmware-api
```

## Packet Contents

This section contains a description of all the Objects from this package that can be used to build your own monitoring environment.

### Director/Icinga Objects

#### Host Templates

| Host Template name | Description |
| --- | ----------- |
| nx-ht-vmware-api-host-system | Describe a generic VMware Host |
| nx-ht-vmware-api-virtual-machine | Describe a generic VMware VM |
| nx-ht-vmware-api-vcsa | Describe a generic VMware vCenter |
| nx-ht-virtual-vmware-cluster | Describe a generic VMware Cluster |

#### Service Templates

| Service Template name | Run on Agent | Description |
| --- | --- | -------------|
| nx-st-agentless-vmware | NO | Checks all aspects of monitoring a VMWare environment directly |
| nx-st-agentless-vmware-datacenter | NO | Checks all aspects of monitoring a VMWare ESXi montioring |
| nx-st-agentless-vmware-snapshot | NO | Checks all aspects of monitoring VMWare Snapshots |
| nx-st-agentless-vmware-direct | NO | Checks all aspects of monitoring VMWare directly |
| nx-st-agentless-vmware-cluster | NO | Checks all aspects of monitoring VMWare cluster |

#### Sercices Sets

| Service Set name | Description |
| --- | -------------|
| nx-ss-vmware-cluster-datacenter | Cluster monitoring through VCSA: CPU Usage, Memory Usage,Host Connected |
| nx-ss-vmware-esx-datacenter | ESXi monitoring through VCSA: CPU Usage, Memory Usage,Runtime Status,Runtime Issues,Uptime |
| nx-ss-vmware-esx-datacenter-extended | ESXi monitoring through VCSA (used also with VMD Module):NET Usage,Disk IO Stats Read,Disk IO Stats Write,Swap Usage |
| nx-ss-vmware-esx-direct | ESXi monitoring Directly: CPU Usage, Memory Usage,Runtime Status,Runtime Issues,NET Usage,Disk IO Stats Read,Disk IO Stats Write,VMFS,Swap Usage,Uptime |
| nx-ss-vmware-vcenter-datacenter | vCenter Basic Service monitored through VCSA: VMFS,Host Connected,CPU Load,Memory Usage |
| nx-ss-vmware-vcenter-direct | vCenter Basic Service monitored directly: VMFS,Host Connected,CPU Load,Memory Usage |
| nx-ss-vmware-vcenter-snapshosts | vCenter Snapshots monitoring (age and count): Snapshot count,Snapshot age |

#### Command

* nx-c-check-vmware-api-datacenter
* nx-c-check-vmware-api
* nx-c-check-vmware-snapshot
* nx-c-vclusteralive
