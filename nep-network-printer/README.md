# nep-network-printer
The NEP is based on the check_printer_health script (for more information have look to this [Page](https://labs.consol.de/nagios/check_printer_health/)). In order to use it, SNMP must be enabled on the target devices. This NEP provides an HT **nx-ht-network-printer-snmp** that can be added to the Host. This template is linked to a SS: **nx-ss-network-printer** that monitors these elements on the printer:

* Printer Hardware Status
* Printer Supplies Status
* Printer Uptime

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.29 |
| nep-common | 0.0.3 |
| nep-network-base | >=0.0.3 |
| nep-centreon-plugins-base | >=0.0.2 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| Monitoring |


### External dependencies

This NEP doesn't require external references, if you want to manually download a new version via WGET see:

* https://labs.consol.de/nagios/check_printer_health/index.html#download

## Installation

The installation process provides a PERL script **check_printer_health** that is automatically installed at /neteye/shared/monitoring/plugins/


### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-network-printer
```

## Packet Contents

Perl script: check_printer_health

### Director/Icinga Objects

#### Host Templates

Host Template:

* nx-ht-network-printer-snmp based on nx-ht-snmp

#### Service Templates

Service Templates:

* nx-st-network-printer-health using the 3 available modes
    * uptime: printer uptime
    * hardware-health: checks printer hardware
    * supplies-status: checks consumables, toner, ink cartridges, etc..

#### Sercices Sets

Service Set:

* nx-ss-network-printer

#### Command

Commands:

* nx-c-check-printer-health

### Dashboard ITOA

The NEP doesn't provide a dedicated dashboard, but user can build it

## Usage

In order to use this NEP, add the HT **nx-ht-network-printer-snmp** to the Host.
Configure these fileds:

* SNMP Community
* SNMP Version (if needed)

Services are then attached to this device and monitored.

