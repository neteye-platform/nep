# Notification Base

The `nep-notification-base` provides common basic behavior to manage Icinga2 Notifications right out-of-the-box. Because Icinga2 Notification Objects are quite complex, facilities provided by this NEP and its companions will implement a basic notification behavior.

**Remember**: this package provide common facilities. To actually allow notifications to be sent over a specific communication channel, please install the related NEP.

Here are explained some terms using in this guide:

| Term | Definition |
| --- | ----------- |
| Notification Channel | The communication system used by NetEye to relay notifications to end Users |
| Recipients | The end users that might receive notifications from NetEye; in Icinga terminology, they are known as Users; also, Users can be grouped into User Groups |

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

##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |

## Installation

The installation process provides several basic components used by the other specific nep-notification channels.


### NEP Installation

To setup Package nep-notification-base, just use the Setup Utility:

```
nep-setup install nep-notification-base
```

After the installation is complete, add the support for the required Notification Channel by installing the related NEP.

## Packet Contents

This section contains a description of all the Objects from this package that can be used to build your own monitoring environment.

### Director/Icinga Objects

The Package contains the following Director Objects.

| Object Type | Object Name | Editable | Containing File |
| ----------------------- | ----------- | -------- | --------------- |
| Director Time Period | nx-t-24x7 | Yes | baskets/import/nep-notification-base-07-timeperiod.json |
| Director Time Period | nx-t-holidays | Yes | baskets/import/nep-notification-base-07-timeperiod.json |
| Director Time Period | nx-t-non-workhours | Yes | baskets/import/nep-notification-base-07-timeperiod.json |
| Director Time Period | nx-t-8x5 | Yes | baskets/import/nep-notification-base-07-timeperiod.json |
| Director Notification Template | nx-nt-base | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-base.conf |
| Director Notification Template | nx-nt-basic | Yes | custom_files/neteye_shared_root/icinga2/conf.d/nx-notification-basic.conf |

#### Timeperiods

The following Time Periods are available to select to all Objects.

| Time Period name | Description |
| --- | ----------- |
| nx-t-24x7 | Identify all times of all days |
| nx-t-8x5 | Selects only working days (from monday to Friday), from 8.30 to 17.30 |
| nx-t-non-workhours | Implemented as the negation of Time Period `8x5` |
| nx-t-holidays | List of Holidays |

#### Notification Template

| Notification Template | Description |
| ---------------- | ----------- |
| nx-nt-base | Empty notification template used in order to build logic |
| nx-nt-basic | Child template used in order to provide useful functions for Notification's Channel |

## Usage

### Notification Facility description

Icinga2 Notifications have a variety of options to decide how, when and where notifications are sent, so a simplified model had to be implemented. Here follows a brief description of this model.

The bottom idea is that Notifications Behavior is driven by a configuration at Host Object level, meaning all the configuration options are managed insode the Host Object, then and all its Service Objects will inherit those settings. However, it is possible to override a limited set of settings at Service Object level. Here a brief summary of the whole logic:

* Notifications are disabled by default. It is possible, for each Host Object, to decide if activate them onlky for the Host Object itseld or also for all its Service Objects.

* At Host Object Level, is possible to define:
    *  One or more channel to use
    * One or more Recipients (be them Users or User Groups)
    * Initial Delay and Notification Repetition Interval
* At Service Level is possible to:
    * Completely disable Notifications for the Service Object
    * Override Recipients (Users, User Groups or both of them) for the Service Object

Note that one Host Object supports only one set of Communication Channels, and this set is shared with all its Service Objects. Also, all the Communication Channels share the same settings; therefore, is not possible to implement notification processes like the ones describe in ITIL.

### How the Notification Facility works

All configuration options are provided through Custom Variables. These variables are implemented directly into `nx-ht-type-custom` and `nx-st-type-custom` Templates. This means it is possible to set notification options to all Host and Service Objects using a Template derived from the right Template Type Custom as well as set them directly at Host/Service Object Level.

As a last notice, these options are just tags, meaning nep-notification-base is not able to understand them. The actual notification logic must be completed by installing other NEPs: there is one NEP for each Notification Channel available, so to send notifications through this channel *it is required to install the NEP referring to that very Notification Channel*.

### Troubleshoot Notification instances

After Notifications have been deployed, there is no way to easily undertand what State Changes will be notified and who are the recipients. To have a better grasp of the situation, please apply what described at [Troubleshoot Icinga Notifications](https://www.neteye-blog.com/2023/12/troubleshooting-icinga-notifications/).