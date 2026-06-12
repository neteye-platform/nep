# Notification Microsoft Teams

The `nep-notification-msteams` adds to the Notification Facility provided with `nep-notification-base` the ability to send Notifications using MS Teams.

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

To setup Package `nep-notification-msteams`, just use the Setup Utility:

```
nep-setup install nep-notification-msteams
```


## Packet Contents

This `nep-notification-msteams` does not provide any Object for the End User. All Objects will be automatically created after the current Director Configuration is deployed.

### Director/Icinga Objects

The Package contains the following Director Objects.

| Object Type | Object Name | Editable | Containing File |
| ----------------------- | ----------- | -------- | --------------- |
| Director Command | nx-c-teams-host-notification | No | baskets/import/nep-notification-msteams-02-command.json |
| Director Command | nx-c-teams-service-notification | No | baskets/import/nep-notification-msteams-02-command.json |
| Icinga2 Notification Template | nx-nt-channel-msteams | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-teams.conf |
| Icinga2 Notification Template | nx-nt-teams-host-notification | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-teams.conf |
| Icinga2 Notification Template | nx-nt-teams-service-notification | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic-teams.conf |

#### Commands

| Icinga Command | File Path |
| ---------------- | ----------- |
| nx-c-teams-host-notification | /neteye/shared/monitoring/plugins/teams-notifications/teams-host-notification.sh |
| nx-c-teams-service-notification | /neteye/shared/monitoring/plugins/teams-notifications/teams-service-notification.sh |

#### Notification Template Template

| Template Name | Description |
| ---------------- | ----------- |
| nx-nt-teams-host-notification | Notification Template managed by apply rules for Hosts |
| nx-nt-teams-service-notification | Notification Template managed by apply rules for Services |

