# nep-notification-servicenow (ALPHA)

# !WARNING: this NEP is provied by a PoC and it is not fully supported!

_As described before this template has been used during a PoC and in order to be reused some custimizations are needed. Use this as starting point of your ServiceNow Integration._

If you install this NEP have a look to the script  `nx-notification-servicenow.py` and the conf file `nx-notification-servicenow.json` in order to adapt to you ServiceNow installation.

_These sections will be populated_

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.32 |
| nep-common | 0.1 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| SIEM |


### External dependencies

This NEP doesn't need any external dependecies other that the ones used by the NEPs reported in [Prerequisites](#prerequisites)

* Prerequisite 1
* Prerequisite 2


## Installation

_Lorem ipsum dolor sit amet, consectetur adipiscing_


#### Before Installation

There is no need to perform any action before installing this NEP


### NEP Installation

To install the NEP, run this command using SSH on NetEye Master Node:
```
nep-setup install foobar
```


#### Finalizing Installation

There is no need to perform any action to complete the installation of this NEP


## Packet Contents

_Lorem ipsum dolor sit amet, consectetur adipiscing_


### Director/Icinga Objects

This NEP doesn't provide any Director/Icinga object


#### Host Templates

This NEP doesn't provide any Host Template definition

* Host Template 1
* Host Template 2


#### Service Templates

This NEP doesn't provide any Service Template definition

* Service Template 1
* Service Template 2


#### Services Sets

This NEP doesn't provide any Service Set definition

* Service Template 1
    * Service 1
    * Service 2
    * Service 3
* Service Template 2
    * Service 1
    * Service 2
    * Service 3


#### Command


This NEP doesn't provide any Command-related object

Command Templates:

* Command Template 1
* Command Template 2

Command Objects:

* Command Object 1
* Command Object 2


#### Notification

This NEP doesn't provide any Notification definition

* Notification 1
* Notification 2


### Automation

This NEP doesn't provide any Automation

Import Sources:

| Name | Type | Linked item |
| ---- | ---- | ----------- |
| Import Source 1 | Sql | DB Resource Name |
| Import Source 2 | Fileshipper | File name |

Sync Rules:

| Name | Object's type | Update policy | Linked Import source |
| ---- | ------------- | ------------- | -------------------- |
| Sync Rule 1 | Host  | Merge | Import Source A |
| Sync Rule 2 | Data List Entry | Replace | Import Source B |

Jobs:

| Name | Type | Linked item |
| ---- | -----| ----------- |
| Job 1 | Import | Import Source A |
| Job 2 | Sync | Sync Rule B |
| Job 3 | Config |  |


### Tornado Rules

This NEP doesn't provide any Tornado rules


### Dashboard ITOA

This NEP doesn't provide any ITOA Dashboards


### Metrics

This NEP doesn't generate any Performance Data from its commands


## Usage

_Advanced description of the Package with_


### Examples
_Provide examples_


#### Using a host template provided by the NEP
_Lorem ipsum dolor sit amet, consectetur adipiscing_


#### Using a service template provided by the NEP
_Lorem ipsum dolor sit amet, consectetur adipiscing_
