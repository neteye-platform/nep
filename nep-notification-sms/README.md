# Notification SMS

The `nep-notification-sms` adds to the Notification Facility provided with `nep-notification-base` the ability to send Notifications using SMS.

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

To setup Package `nep-notification-sms`, just use the Setup Utility:

```
nep-setup install nep-notification-sms
```


## Packet Contents

This `nep-notification-sms` does not provide any Object for the End User. All Objects will be automatically created after the current Director Configuration is deployed.

### Director/Icinga Objects

The Package contains the following Director Objects.

| Object Type | Object Name | Editable | Containing File |
| ----------------------- | ----------- | -------- | --------------- |
| Director Command | sms-host-notification | No | baskets/import/nep-notification-sms-02-command.json |
| Director Command | sms-service-notification | No | baskets/import/nep-notification-sms-02-command.json |
| Icinga2 Notification Template | nx-nt-channel-sms | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Template | nx-nt-channel-sms-for-host | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Template | nx-nt-channel-sms-for-service | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Host Apply Rule | nx-n-basic-sms-to-users-from-host | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Host Apply Rule | nx-n-basic-sms-to-groups-from-host | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-sms-to-users-from-host | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-sms-to-groups-from-hosts | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-sms-to-users-from-service | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |
| Icinga2 Notification Service Apply Rule | nx-n-basic-sms-to-groups-from-service | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-sms.conf |

#### Commands

| Icinga Command | File Path |
| ---------------- | ----------- |
| nx-c-sms-host-notification | /neteye/shared/monitoring/plugins/sms-host-notification.sh |
| nx-c-sms-service-notification | /neteye/shared/monitoring/plugins/sms-service-notification.sh |

#### Notification Template Template

| Template Name | Description |
| ---------------- | ----------- |
| nx-nt-channel-sms-for-host | Notification Template managed by apply rules for Hosts |
| nx-nt-channel-sms-for-service | Notification Template managed by apply rules for Services |

