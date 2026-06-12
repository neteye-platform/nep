# nep-database-oracle
The NEP is based on the check_oracle_health script (for more information have look to this [Page](https://labs.consol.de/nagios/check_oracle_health/)).
This NEP provides an HT **nx-ht-status-oracle-conn-time** that can be added to the Host. This template is linked to a SS: **nx-ss-database-oracle-basic** that monitors these elements on Oracle Database:

* Connected Users Count
* Connection time
* Process usage
* Session usage
* Tablespace usage

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.36 |
| nep-common | 0.1.6 |
| nep-dbms-base | >=0.0.3 |

##### Required NetEye Modules

| NetEye Module |
| --- |
| Monitoring |


### External dependencies

This NEP doesn't require external references, if you want to manually download a new version via WGET see:

* https://labs.consol.de/nagios/check_oracle_health/index.html#download

## Installation

The installation process provides a PERL script **check_oracle_health** that is automatically installed at /neteye/shared/monitoring/plugins/


### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-database-oracle
```

## Packet Contents

Perl script: check_oracle_health

### Director/Icinga Objects

#### Host Templates

Host Templates:

* nx-ht-oracle-object
* nx-ht-status-oracle-conn-time

#### Service Templates

Service Templates:

* nx-st-agentless-oracle-health
    * nx-st-agentless-oracle-health-connected-users
    * nx-st-agentless-oracle-health-connection-time
    * nx-st-agentless-oracle-health-sql
    * nx-st-agentless-oracle-health-tnsping
    * nx-st-agentless-oracle-health-process-usage
    * nx-st-agentless-oracle-health-session-usage
    * nx-st-agentless-oracle-health-tablespace-free
    * nx-st-agentless-oracle-health-tablespace-usage


#### Sercices Sets

Service Set:

* nx-ss-database-oracle-basic

#### Command Templates

Command templatess:

* nx-ct-check-oracle-health

#### Command

Commands:

* nx-c-oracle-health-connected-users
* nx-c-oracle-health-connection-time
* nx-c-oracle-health-sql
* nx-c-oracle-health-tnsping
* nx-c-oracle-health-process-usage
* nx-c-oracle-health-session-usage
* nx-c-oracle-health-tablespace-free
* nx-c-oracle-health-tablespace-usage

Command objects uses plugins from Consol Labas library. To see more details about the included plugin, see the following links:

* [Oracle Health Plugin](https://github.com/lausser/check_oracle_health)


### Dashboard ITOA

The NEP doesn't provide a dedicated dashboard, but user can build it

## Usage

In order to use this NEP, add the HT **nx-ht-status-oracle-conn-time** to the Host.
Configure these fileds:

* Client Connection String
* Client User name
* Client User password
* Client Connection method
* Environment variables

Services are then attached to this device and monitored.
