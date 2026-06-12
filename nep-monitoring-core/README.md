# NEP Monitoring Core
Package `nep-monitoring-core` adds self-monitoring capabilities to a NetEye. It enables NetEye to:

* Find the main components of the current Infrastructure
* Monitor them using a predefined set of checks

This Package is the first of a series: it covers only NetEye Core module functionalities. To monitor other NetEye modules, other NEPs are required. This Package will also act as a common base for other NetEye Monitoring-related Packages, therefore it is required to successfully monitor other NetEye modules.

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Software Version    | Version |
| ------------------  | ------- |
| NetEye              | 4.25    |
| nep-common          | 0.0.4   |


##### Required NetEye Modules

| NetEye Module |
| ------------  |
| Core          |


### External dependencies

This NEP doesn't need any external dependencies other that the ones used by the NEPs reported in [Prerequisites](#prerequisites)


## Installation

#### Before Installation

There is no need to perform any action before installing this NEP


### NEP Installation

If all requirements are met, you can now install this package. To manually set up the `nep-monitoring-core` package, just use `nep-setup` utility to install it:
```bash
nep-setup install nep-monitoring-core
```


#### Finalizing Installation

Package `nep-monitoring-core` has self-populating capabilities. To create the required monitoring objects, just run the automations provided by this Package.

1. __Run the following Import Sources__

   * NetEye infrastructure endpoints Source
   * NetEye infrastructure child zones Source

2. __Run the following Sync Rules in the reported order__:

   * NetEye infrastructure endpoints Rule
   * NetEye infrastructure child zones Rule

This will create the required objects for NetEye Monitoring. Then, the generated Host Objects' properties must be updated to reflect the current configuration of the NetEye infrastructure:

1. Open Director
2. Locate Host Object NetEye Master zone Endpoint
3. Edit Custom Property Installed modules, selecting all the installed NetEye modules
4. __If it is a Clustered NetEye deployment__:

   1. Search _NetEye Cluster node_ inside the Host Objects: all cluster nodes will be found
   2. Edit Custom Property _Local Services_ and select all the eventually installed NetEye Local services

After this, all the required services will be automatically assigned to the right Host Objects.

Then, the new configuration can be safely deployed.


## Packet Contents

### Automatic Object's Update
Automations provided by this Package can be freely used to generate and refresh all the required monitoring objects. NetEye deployments are not updated often, but the automations can be eventually scheduled by the End User in the `Jobs` section of Director Automations.

### Director/Icinga Objects

This NEP provide the following Director objects.


#### Host Templates

The following Host Templates can be used to freely create Host Objects. Remember to not edit these Host Templates because they will be restored/updated at the next NEP package update.

| Host Template name                     | Description                                                                                                      |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `nx-ht-neteye-mainsystem-master`       | Defines the NetEye Master Endpoint (`icinga2-master instance`) in a Main deployment both single or cluster.      |
| `nx-ht-neteye-mainsystem-cluster-node` | On a Clustered NetEye Main deployment, represents a Cluster Node                                                 |
| `nx-ht-neteye-satellite`               | Represents a NetEye Satellite in both single deployment or HA deployment                                         |
| `nx-ht-neteye-voting-node`             | On a Clustered NetEye deployment, represents a Voting Node                                                       |
| `nx-ht-neteye-subsystem-master`        | Defines the NetEye Master Endpoint (`icinga2-master instance`) in a Subsystem deployment both single or cluster. |
| `nx-ht-neteye-subsystem-cluster-node`  | On a Clustered NetEye Subsystem deployment, represents a Cluster Node                                            |



#### Service Templates

The following Service Templates can be used to freely create Service Objects, Service Apply Rules or Service Sets.

_Remember to not edit these Service Templates as they will be restored/updated at the next NEP Package update_:

| Template Name                                  | Run on Agent | Description                                                                                 |
|------------------------------------------------| ------------ |---------------------------------------------------------------------------------------------|
| `nx-st-agent-icinga-cluster-performance`       | Yes          | Check returns performance data for the current Icinga instance and connected endpoints      |
| `nx-st-agent-icinga-cluster-zone-performance`  | Yes          | Measures the performance of an Icinga Cluster                                               |
| `nx-st-agent-icinga-instance-performance`      | Yes          | Measures the performances of an Icinga Instance                                             |
| `nx-st-agent-icinga-modem-sms`                 | Yes          | Measures the performances of an SmsD Instance                                               |
| `nx-st-agent-icinga-sms-queue`                 | Yes          | Measures the queue of an SmsD Instance                                                      |
| `nx-st-agent-linux-cluster-crm-state`          | Yes          | Checks the status of a Pacemaker based cluster using crm_mon                                |
| `nx-st-agent-linux-drbd9-replica-health-state` | Yes          | Checks the replication status of a DRBD Cluster node                                        |
| `nx-st-agent-linux-byssh-disk-free-space`      | Yes (By SSH) | Checks Disk space usage on a Linux computer through a SSH channel                           |
| `nx-st-agent-linux-byssh-unit-state`           | Yes (By SSH) | Checks SystemD-based unit status on a Linux computer through a SSH channel                  |
| `nx-st-agent-linux-byssh-unit-state-no-enable` | Yes (By SSH) | Checks SystemD-based unit status on a Linux computer through a SSH channel                  |
| `nx-st-agent-linux-database-mysql-health`      | Yes          | Checks various performances of a local MySQL/MariaDB DBMS or Database                       |
| `nx-st-agentless-database-mysql-health`        | No           | Checks various performances of a remote MySQL/MariaDB DBMS or Database                      |
| `nx-st-agentless-byssh-disk-free-space`        | No (By SSH)  | Checks Disk space usage on a Linux computer through a SSH channel                           |
| `nx-st-agentless-byssh-unit-state`             | No (By SSH)  | Checks SystemD-based unit status on a Linux computer through a SSH channel                  |
| `nx-st-agentless-byssh-unit-state-no-enable`   | No (By SSH)  | Checks SystemD-based unit status on a Linux computer through a SSH channel                  |
| `nx-st-agentless-director-health-check`        | No           | Check Director health status (configuration, deployments, import sources, sync rules, jobs) |
| `nx-st-agentless-mirror-repo-sync`             | No           | Check that RPM mirror is in sync with official NetEye repository                            |



#### Services Sets

The following Service Sets can be used to freely monitor Host Objects.

_Remember to not edit these Service Sets because they will be restored/updated at the next NEP Package update_:

| Service Set Name                                  | Description                                                           |
| ------------------------------------------------- | --------------------------------------------------------------------- |
| `nx-ss-mysql-database-basic-performance`          | Perform basic monitoring of a MySQL/MariaDB Database                  |
| `nx-ss-mysql-dbms-basic-performance`              | Perform basic monitoring of a MySQL/MariaDB DBMS                      |
| `nx-ss-neteye-cluster-node-state`                 | Monitor a PCS Cluster based node                                      |
| `nx-ss-neteye-core-cluster-state`                 | Monitor NetEye Core Module on a Clustered NetEye Deployment           |
| `nx-ss-neteye-core-units-state`                   | Monitor NetEye Core Units on a Single and Clustered NetEye Deployment |
| `nx-ss-neteye-endpoint-basic-performance`         | Monitor basic performances of a NetEye Endpoint                       |
| `nx-ss-neteye-endpoint-satellite-state`           | Monitor basic performance and services on a NetEye Satellite          |
| `nx-ss-neteye-icinga-instance-state`              | Monitor Icinga2 performances on a NetEye                              |
| `nx-ss-neteye-mysql-dbms-basic-performance`       | Perform basic monitoring of a MySQL/MariaDB DBMS on NetEye            |
| `nx-ss-neteye-lampo-state`                        | Monitor NetEye Lampo service on a Single-node NetEye Deployment       |
| `nx-ss-neteye-sms-state`                          | Monitoring Services for SMS notification                              |
| `nx-ss-neteye-core-cluster-state-director-health` | Monitor Director health on a Clustered NetEye Deployment              |
| `nx-ss-neteye-core-state-director-health`         | Monitor Director health on a NetEye Endpoint                          |


#### Automations

The following Automations can be used to populate and maintain the monitored Host Objects.

Import Sources:

| Name                                    | Type        | Linked Item                  |
| --------------------------------------- | ----------- | ---------------------------- |
| `nx-is-neteye-infrastructure-zones`     | SQL         | Director                     |
| `nx-is-neteye-infrastructure-endpoints` | SQL         | Director                     |
| `nx-is-datalist-neteye-modules`         | Fileshipper | `nx-neteye-modules-list.csv` |


Sync Rules:

| Name                                    | Object's Type   | Update Policy | Linked Import Source                    |
| --------------------------------------- | --------------- | ------------- | --------------------------------------- |
| `nx-sr-neteye-infrastructure-zones`     | Service         | Merge         | `nx-is-neteye-infrastructure-zones`     |
| `nx-sr-neteye-infrastructure-endpoints` | Host            | Merge         | `nx-is-neteye-infrastructure-endpoints` |
| `nx-sr-neteye-ip-duplicated-zones`      | Service         | Override      | `nx-is-neteye-infrastructure-zones`     |
| `nx-sr-datalist-neteye-modules`         | Data List Entry | Merge         | `nx-is-datalist-neteye-modules`         |


Jobs:

| Name                                  | Type   | Linked Item                     |
| ------------------------------------- | ---    | ------------------------------- |
| `nx-j-import-datalist-neteye-modules` | Import | `nx-is-datalist-neteye-modules` |
| `nx-j-sync-datalist-neteye-modules`   | Sync   | `nx-sr-datalist-neteye-modules` |


#### Command

The following Commands can be used to freely create Command Objects, Command Template and Service Template.

_Remember to not edit these Service Templates as they will be restored/updated at the next NEP Package update_:

* `nx-c-director-health-check`
* `nx-c-check-crm`
* `nx-c-check-drbd9`
* `nx-c-check-mysql-health`
* `nx-c-check-systemd-unit`
* `nx-c-check-modem-smst`
* `nx-c-check-sms-queue`
* `nx-c-check-icinga-duplicated-ips`
* `nx-c-check-mirror-repo-sync`


#### Notification

This NEP doesn't provide any Notification definition


### Tornado Rules

This NEP doesn't provide any Tornado Rule


### Dashboard ITOA

This NEP doesn't provide any ITOA Dashboards


### Metrics

This NEP doesn't generate any Performance Data from its commands


## Usage


### Examples

#### Using a host template provided by the NEP

Example of Host Template `nx-ht-neteye-mainsystem-master`.

Assignment:

![Host Template Assignment](/doc-images/ht-example-assignment.png)

Result:

![Host Template Result](/doc-images/ht-result.png)


#### Using a service template provided by the NEP

Example of Service Template `nx-ss-neteye-core-state-director-health`.

Assignment:

![Service Set Assignment](/doc-images/ss-example-assignment.png)

Result:

![Service Set Result Services](/doc-images/ss-result.png)