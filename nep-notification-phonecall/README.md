# Notification Phone Call

The `nep-notification-phonecall` adds to the Notification Facility provided with `nep-notification-base` the ability to send Notifications using Phone Call.

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

This package can be installed on systems running the software described below. Systems with equivalent components are also suitable for installation.

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.22+ |
| nep-common | 0.1.0+ |
| nep-notification-base | 0.0.3+ |

##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |

## Installation

### NEP Installation

To setup Package `nep-notification-phonecall`, just use the Setup Utility:

```
nep-setup install nep-notification-phonecall
```
After the installation is complete, you can use objects and configure the NEP.

## Packet Contents

This `nep-notification-phonecall` does not provide any Object for the End User. All Objects will be automatically created after the current Director Configuration is deployed.

### Director/Icinga Objects

The Package contains the following Director Objects.

| Object Type | Object Name | Editable | Containing File |
| ----------------------- | ----------- | -------- | --------------- |
| Director Command | nx-c-phonecall-notification | No | baskets/import/nep-notification-phonecall-02-command.json |
| Icinga2 Notification Template | nx-nt-channel-phonecall | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |
| Icinga2 Notification Template | nx-nt-channel-phonecall-for-host | No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conff |
| Icinga2 Notification Template | nx-nt-channel-phonecall-for-service | No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |
| Icinga2 Notification Host Apply Rule | nx-n-basic-phonecall-to-users-from-host | No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |
| Icinga2 Notification Host Apply Rule | nx-n-basic-phonecall-to-groups-from-host | No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-phonecall-to-users-from-host | No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-phonecall-to-groups-from-hosts| No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-phonecall-to-users-from-service | No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-phonecall-to-groups-from-service | No | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-phonecall.conf |

#### Notification Template

| Notification Template name | Description |
| -------------------------- | ----------- |
| nx-nt-channel-phonecall-for-host | Notification Template for Hosts used by Apply rules |
| nx-nt-channel-phonecall-for-service | Notification Template for Services used by Apply rules |