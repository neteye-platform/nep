# Notification Telegram

The `nep-notification-telegram` adds to the Notification Facility provided with `nep-notification-base` the ability to send Notifications using Telegram.

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

To setup Package `nep-notification-telegram`, just use the Setup Utility:

```
nep-setup install nep-notification-telegram
```


## Packet Contents

This `nep-notification-telegram` does not provide any Object for the End User. All Objects will be automatically created after the current Director Configuration is deployed.

### Director/Icinga Objects

The Package contains the following Director Objects.

| Object Type | Object Name | Editable | Containing File |
| ----------------------- | ----------- | -------- | --------------- |
| Director Command | nx-c-telegram-host-notification | No | baskets/import/nep-notification-telegram-02-command.json |
| Director Command | nx-c-telegram-service-notification | No | baskets/import/nep-notification-telegram-02-command.json |
| Icinga2 Notification Template | nx-ut-telegram | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-telegram.conf |

#### Commands

| Icinga Command | File Path |
| ---------------- | ----------- |
| nx-c-telegram-host-notification | /neteye/shared/monitoring/plugins/host-by-telegram.sh |
| nx-c-telegram-service-notification | /neteye/shared/monitoring/plugins/service-by-telegram.sh |

#### Notification Template Template

| Template Name | Description |
| ---------------- | ----------- |
| nx-ut-telegram | Notification Template managed by apply rules for Hosts and Service |

