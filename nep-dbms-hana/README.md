# nep-hana-db

The HANA DB NEP is based on plugin hana_check.sh. This NEP provides an HT **nx-ht-hana-system** that can be added to the Host.
Command check

* DB connection-time
* Failed Log Backup
* Failed Data Backup
* Hana Instance Status
* Last data Backup
* DB memory usage
* Replication status
* Missing index
* DB Used Space

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Sofware | Version |
| ------- | ------- |
| NetEye | 4.38 |
| nep-common | 0.0.3 |
| nep-dbms-base | 0.0.2 |


##### Required NetEye Modules

| NetEye Module |
| ------------- |
| Monitoring |


### External dependencies

This NEP needs access to this additional SAP Library
It is mandatory to install 'hdbclient' software [SAP HANA CLIENT](https://help.sap.com/docs/SAP_HANA_CLIENT?locale=en-US)
Client should be installed on folder /neteye/shared/monitoring/plugins/sap/hana/hdbclient

## Installation

The installation process provides a Shell script check_hana.sh that is automatically installed at /neteye/shared/monitoring/plugins/


## Before Installation

There is nothing to do before installing this NEP


### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-dbms-hana
```

#### Finalizing Installation

There is nothing to do to finalize the installation of this NEP


## Packet Contents


### Director/Icinga Objects


#### Host Templates
Host Template:

* nx-ht-hana-system
  * nx-ht-hana-instance
  * nx-ht-hana-tenant

#### Service Templates
Service Templates:

* nx-st-agentless-sap-hana
  * nx-st-hana-connection-time
  * nx-st-hana-failed-data-backups
  * nx-st-hana-failed-log-backups
  * nx-st-hana-instance-status
  * nx-st-hana-last-backup
  * nx-st-hana-memory-usage
  * nx-st-hana-missing-index
  * nx-st-hana-replication-status
  * nx-st-hana-used-space

#### Services Sets
Service Set:

* nx-ss-hana-instance-all
* nx-ss-hana-replica
* nx-ss-hana-tenant-all

#### Command
CommandTemplate:

* nx-ct-sap-check-hana

Command:

* nx-ct-sap-check-hana
  * nx-c-sap-check-hana-connection-time
  * nx-c-sap-check-hana-failed-data-backups
  * nx-c-sap-check-hana-failed-log-backups
  * nx-c-sap-check-hana-last-backup
  * nx-c-sap-check-hana-memory-usage
  * nx-c-sap-check-hana-missing-index
  * nx-c-sap-check-hana-replication-status
  * nx-c-sap-check-hana-used-space


#### Notification

This NEP doesn't provvide any Notification


### Automation

This NEP doesn't provide any Automation Objects


### Tornado Rules

This NEP doesn't provide any Tornado Rules


### Dashboard ITOA
The NEP doesn't provide a dedicated dashboard, but user can build it


### Metrics

This NEP produce this performance data:

 * HANA Connection Time in ms
 * HANA Memory Usage in Gb
 * HANA Used Space in percent


## Usage

In order to use this NEP, add the HT nx-ht-hana-tenant to the Host. Configure these fileds:

* HANA Database Tenant ID
* HANA Database Tenant Password
* HANA Database Tenant SQL-Port
* HANA Database Tenant User
* HANA Instance ID (SID)
* HANA Instance Number
* SAP sapcontrol Protocol

Services are then attached to this device and monitored.
