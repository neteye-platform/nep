# NEP Network Dell iDRAC
_The nep-network-dell-idrac provides the minimum requirements to implement a basic monitoring of a iDRAC using SNMP protocol._


# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.34 |
| nep-common | 0.1.3 |
| nep-centreon-plugins-base | 0.1.0 |

##### Required NetEye Modules

| NetEye Module |
| --- |
| - |


### External dependencies

_Insert basic packages of file will be intalled_

- foobar1
- foobar2

### NEP Installation
__
```
nep-setup install nep-network-dell-idrac
```

#### Finalizing Installation
__

## Packet Contents
_N.D._

### Director/Icinga Objects
_N.D._

#### Host Templates
_N.D._

#### Service Templates
_N.D._

#### Sercices Sets
_N.D._

#### Command
_N.D._

#### Notification
__

### Automation
__

### Tornado Rules
__

### Dashboard ITOA
__

### Metrics
__

## Usage
__

### Examples
_Usage examples_
```
'/usr/lib/centreon/plugins/centreon_dell_idrac.pl' '--hostname' '192.168.1.1' '--mode' 'hardware' '--snmp-community' 'my_community' '--snmp-timeout' '30' '--snmp-version' '2c'
CRITICAL: Enclosure 'BP12G+ 0:1' status is 'critical' - physical disk 'Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1' state is 'failed' | 'hardware.enclosure.count'=1;;;; 'hardware.fru.count'=6;;;; 'hardware.health.count'=1;;;; 'hardware.memory.count'=2;;;; 'hardware.network.count'=4;;;; 'hardware.pci.count'=23;;;; 'hardware.pdisk.count'=4;;;; 'hardware.processor.count'=2;;;; 'hardware.slot.count'=1;;;; 'hardware.storagebattery.count'=1;;;; 'hardware.storagectrl.count'=1;;;; 'hardware.vdisk.count'=1;;;;
```

### Using a host template provided by the connector
__

### Using a service template provided by the connector
__
