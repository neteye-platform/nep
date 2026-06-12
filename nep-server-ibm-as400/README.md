# Server IBM AS400
The `nep-server-ibm-as400` is used to deliver IBM AS400 monitoring without agent installed on remote machine. With this package, it is possible to monitor:

* CPU Usage
* DISK Hardware Status
* Disk Usage
* Active Jobs
* and much more...

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.35 |
| nep-common | |

##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |


### External dependencies

To perform monitoring, this package take the AS400 credential directly on this file:
```
/neteye/shared/monitoring/plugins/as400/.as400
```
or is possible pass the credential in the host Template.

## Installation

Before associating a new host with the Host Template you need to modify the credentials file.

If all requirements are met, you can now install this package.

### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-server-ibm-as400
```

## Packet Contents

This section contains a description of all the Objects from this package that can be used to build your own monitoring environment.

### Director/Icinga Objects

#### Host Templates

| Host Template name | Description |
| --- | ----------- |
| nx-ht-as400 | Contains the basic information of the AS400 host |

#### Service Templates

| Service Template name | Run on Agent | Description |
| --- | --- | -------------|
| nx-st-agentless-as400-base | NO | Checks base for AS400 Host |
| nx-st-agentless-as400-advanced | NO | Advanced check for system and Job |

#### Sercices Sets

| Service Set name | Description |
| --- | -------------|
| nx-ss-as400 | Monitor all basic aspects of a Host System |

#### Command

* nx-c-check-as400-base
* nx-c-check-as400-advanced