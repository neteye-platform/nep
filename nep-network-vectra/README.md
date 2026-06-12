# nep-network-vectra

The Vectra NEP is based on the Vectra Rest API. In order to use it, REST API must be enabled on the target device. This NEP provides an HT **nx-ht-restapi-vectra based on nx-ht-restapi** that can be added to the Host. This template is linked to a SS: **nx-ss-vectra** that monitors these elements on the Vectra Device:

* CPU Usage
* Disk Usage
* Memory Usage
* Sensors Status

_The PERL plugin, used for this scope, provides also some additional features such as Interfaces and Uptime_


# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.30 |
| nep-common | 0.0.3 |
| nep-network-base | >=0.0.3 |
| nep-centreon-plugins-base | >=0.0.5 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| Monitoring |


### External dependencies

This NEP needs access to this additional repository

- [https://packages.centreon.com](https://packages.centreon.com)


## Installation

The installation process provides a PERL script that is automatically installed via dnf at `/usr/lib/centreon/plugins/`


## Before Installation

There is nothing to do before installing this NEP


### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-network-vectra
```


#### Finalizing Installation

There is nothing to do to finalize the installation of this NEP


## Packet Contents


### Director/Icinga Objects


#### Host Templates
Host Template:

* nx-ht-restapi-vectra based on nx-ht-restapi


#### Service Templates
Service Templates:

* nx-st-agentless-restapi-centreon-vectra
  * nx-st-agentless-restapi-centreon-vectra-cpu
  * nx-st-agentless-restapi-centreon-vectra-disk
  * nx-st-agentless-restapi-centreon-vectra-memory
  * nx-st-agentless-restapi-centreon-vectra-sensors


#### Services Sets
Service Set:

* nx-ss-vectra


#### Command
CommandTemplate:

* nx-ct-centreon-plugin-restapi-vectra

Command:

* nx-c-centreon_vectra_cpu
* nx-c-centreon_vectra_disk
* nx-c-centreon_vectra_memory
* nx-c-centreon_vectra_sensors

Command objects uses plugins from Centreon Plugin library.
To see more details about the included plugins, see the following links:

* [Centreon Vectra Rest API Plugin](https://docs.centreon.com/pp/integrations/plugin-packs/procedures/network-vectra-restapi/)


#### Notification

This NEP doesn't provvide any Notification


### Automation

This NEP doesn't provide any Automation Objects


### Tornado Rules

This NEP doesn't provide any Tornado Rules


### Dashboard ITOA
The NEP provides a dashboard vectra_dashboard.json with four panels that plot the variosu metrics collected by this plugin. Other metrics are available in INFLUXDB and graphs can be extended.


### Metrics

This NEP doesn't produce any performance data


## Usage

In order to use this NEP, add the HT **nx-ht-restapi-vectra based on nx-ht-restapi** to the Host.
Configure these fileds:

* [NX] API Token
* [NX] API Insecure (if needed)

Services are then attached to this device and monitored.


### Examples

#### Using a host template provided by the NEP
_Example of Host Object creation_


#### Using a service template provided by the NEP
_Example of Service Object creation_

