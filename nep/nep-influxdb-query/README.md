# NEP InfluxDB Query
The `nep-influxdb-query` package is the NEP designed to perform (custom) queries to InfluxDB and return data that you can use to create custom checks on NetEye.


# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Software Version          | Version |
| ------------------------- | --------|
| NetEye                    | 4.31    |
| nep-common                | 0.0.7   |
| nep-centreon-plugins-base | 0.1.0   |


##### Required NetEye Modules

| NetEye Module |
| ------------- |
| None          |


### External dependencies

* InfluxDB Connectivity


## Installation


#### Before Installation

There is no need to perform any action before installing this NEP


### NEP Installation

To install the NEP, run this command via SSH on NetEye Master Node:
```bash
nep-setup install nep-influxdb-query
```


#### Finalizing Installation

There is no need to perform any action to complete the installation of this NEP


## Packet Contents

### Director/Icinga Objects

#### Host Templates

* `nx-ht-influxdb`
* `nx-ht-influxdb-neteye`


#### Service Templates

* `nx-st-agentless-influxdb`
* `nx-st-agentless-influxdb-centreon`
* `nx-st-agentless-influxdb-centreon-query`
* `nx-st-agentless-influxdb-centreon-query-base`


#### Services Sets

This NEP doesn't provide any Service Set definition

#### Command

Command Templates:

* `nx-ct-centreon-influxdb`
* `nx-ct-centreon-influxdb-query`

Command Objects:

* `nx-c-centreon-influxdb-query`

#### Data List

* [NX] Centreon InfluxDB Connection protocols List
* [NX] Centreon InfluxDB HTTP Backend types List
* [NX] Centreon InfluxDB SSL Protocols List
* [NX] Centreon InfluxDB Metric aggregations List

#### Notification

This NEP doesn't provide any Notification definition


### Automation

This NEP doesn't provide any Automation

### Tornado Rules

This NEP doesn't provide any Tornado rules


### Dashboard ITOA

This NEP doesn't provide any ITOA Dashboards


### Metrics

This NEP doesn't generate any Performance Data from its commands


## Usage

### Basic configurations
These steps must be repeated for each InfluxDB Database that must be queried:

1. Create username and password on the InfluxDB server to query. If the Database is on NetEye Cluster, connect to `influxdb.neteyelocal`.
    1. Connect to Local InfluxDB; here how you can connect to NetEye InfluxDB Database (for other databases, please adapt this command):
        ```bash
        influx -ssl -unsafeSsl -host influxdb.neteyelocal -username root -password $(cat /root/.pwd_influxdb_root) -precision rfc3339
        ```
    2. Create username and password with the right privileges (as an example, `read` privileges on `telegraf_master` DB):
        ```bash
        create user realtime_monitoring with password 'ChangeMe!'
        grant read on "telegraf_master" to "realtime_monitoring"
        exit
        ```
2. On Director, create a new Host Template that can provide connection parameters for InfluxDB.
    1. Give the new Template a proper name
    2. It must inherits from `nx-ht-influxdb`
    3. Under **Centreon InfluxDB Connection** settings:
        1. Set the Hostname of the InfluxDB that needs to be queried and the TCP Port where it is exposed
        2. Set Backend Type to `LWP`
        3. Set Protocol to the one InfluxDB is configured to use (on NetEye, HTTPS)
        4. Fill Username and Password with the credential created before
    4. Under Centreon InfluxDB Connection SSL settings:
       1. Set the requires SSL Options in case your InfluxDB requests HTTPS connection (on NetEye, enable TLSv1)
       ![Create the Host Template that inherits from nx-ht-influxdb](/doc-images/create-ht.png)

> If you want to query NetEye’s InfluxDB, your Template should inherit from `nx-ht-influxdb-neteye`.
> Then, you should only provide Username and Password: other options are already set in accordance with NetEye current settings.
