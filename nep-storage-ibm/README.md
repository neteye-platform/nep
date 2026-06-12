# NEP Storage IBM
The `nep-storage-ibm` provides common basic template to manage Storage IBM systems listed below:

* IBM DS3000 smcli by Centreon

* IBM Storwize by Centeron

This package can be installed on systems running the software described below. Systems with equivalent components are also suitable for installation.

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.23 |
| nep-common | >=0.0.4 |
| nep-centreon-plugins-base | >=0.0.5 |
| nep-storage-base | >=0.0.2 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| CORE |


## Installation

#### Before Installation
There is no need to perform any action before installing this NEP

### NEP Installation

To install the `nep-storage-ibm`, use `nep-setup` via SSH on NetEye Master Node:
```
nep-setup install nep-storage-ibm
```

#### Finalizing Installation

After the installation is complete, add the support for the required Notification Channel by installing the related NEP.
Others custom steps is required for user management on IBM V* series storage:

* create a user named “icinga” with monitor privileges

* copy the file /neteye/local/icinga2/data/spool/icinga2/.ssh/id_rsa.pub in the icinga user properties

The plugin centreon-plugin-Hardware-Storage-Ibm-Ds3000-Smcli need the installation of SMcli command. See Centreon Documentation above.

## Packet Contents

### Director/Icinga Objects

This NEP doesn't provide any Director/Icinga object

#### Host Templates

This NEP doesn't provide any Host Templates


#### Service Templates

The following Service Templates can be used to freely create Service Objects, Service Apply Rules or Service Sets.

_Remember to not edit these Service Templates as they will be restored/updated at the next NEP Package update_:

* `nx-st-agentless-cli-centreon-storage-ibm-ds`: Checks all base monitoring DELL Switch N40XXX using Centreon Plugins
* `nx-st-agentless-ssh-centreon-storage-ibm-storwize`: Checks all base monitoring DELL Switch OS10 using Centreon Plugins


#### Services Sets

The following Service Sets can be used to freely monitor Host Objects.

_Remember to not edit these Service Sets because they will be restored/updated at the next NEP Package update_:

* `nx-ss-storage-centreon-ibm-ds`: Service Set providing all Base monitoring IBM Storage DS3000
* `nx-ss-storage-centreon-ibm-storwize`: Service Set providing all Base monitoring IBM Storage Storwize


#### Command

This NEP doesn't provide any command


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
