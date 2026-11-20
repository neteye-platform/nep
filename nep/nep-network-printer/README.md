# NEP Network Printer

The NEP is based on the check_printer_health script (for more information have look to this [Page](https://labs.consol.de/nagios/check_printer_health/)). In order to use it, SNMP must be enabled on the target devices. This NEP provides an Host Template `nx-ht-network-printer-snmp` that can be added to the Host. This template is linked to a Service Set: `nx-ss-network-printer` that monitors these elements on the printer: <!-- codespell:ignore consol -->

* Printer Hardware Status
* Printer Supplies Status
* Printer Uptime
* Printer Page Count
* Printer Info (model and serial number)
* Printer Status (paper jam, no paper, toner low, offline, active alerts, ...)

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

| Software Version | Version |
| --- | ----------- |
| NetEye | 4.29 |
| nep-common | 0.0.3 |
| nep-network-base | >=0.0.3 |
| nep-centreon-plugins-base | >=0.0.2 |

### Required NetEye Modules

| NetEye Module |
| --- |
| Monitoring |

### External dependencies

This NEP doesn't require external references, if you want to manually download a new version via WGET see:

* [https://labs.consol.de/nagios/check_printer_health/index.html#download](https://labs.consol.de/nagios/check_printer_health/index.html#download) <!-- codespell:ignore consol -->

## Installation

The installation process provides a PERL script `check_printer_health` that is automatically installed at `/neteye/shared/monitoring/plugins/`

### NEP Update

During the update the Service Set `nx-ss-network-printer` is removed and imported again, so that the new services are added
to all the printers. The names of the existing services do not change, so their history and performance data are kept.
If the Service Set was assigned manually to a Host (instead of using the Host Template `nx-ht-network-printer-snmp`), the
update prints a warning: in this case the Service Set must be assigned again to the Host before deploying the configuration.

### NEP Installation

In order to install the NEP run:

``` bash
nep-setup install nep-network-printer
```

## Packet Contents

Perl script: `check_printer_health`

### Director/Icinga Objects

#### Host Templates

Host Template:

* `nx-ht-network-printer-snmp` based on `nx-ht-snmp`

#### Service Templates

Service Templates:

* `nx-st-network-printer-health` using the 6 available modes
  * `uptime`: printer uptime
  * `hardware-health`: checks printer hardware
  * `supplies-status`: checks consumables, toner, ink cartridges, etc..
  * `page-count`: page counters as performance data (always OK)
    * all vendors: `pages_total` (PRINTER-MIB prtMarkerLifeCount) and `pages_since_poweron` (prtMarkerPowerOnCount)
    * HP: `print_color`, `print_mono`, `print_duplex` (HP JetDirect counters)
    * Lexmark: `print_total`, `print_mono`, `print_color`, `copy_*`, `fax_total`, `blank_*`, ... (LEXMARK-MPS-MIB)
  * `printer-info`: model and serial number of the printer (always OK)
  * `printer-status`: status reported by the printer itself
    * HOST-RESOURCES-MIB `hrPrinterDetectedErrorState`: CRITICAL for noPaper, noToner, doorOpen, jammed, offline,
      inputTrayMissing, outputTrayMissing, markerSupplyMissing, outputFull; WARNING for lowPaper, lowToner,
      serviceRequested, outputNearFull, inputTrayEmpty, overduePreventMaint
    * HOST-RESOURCES-MIB `hrDeviceStatus` (down is CRITICAL, warning is WARNING) when no error is reported
    * PRINTER-MIB `prtAlertTable`: active critical and warning alerts (informational events like "powered up" are ignored)
    * the text of the printer display is shown in the output
    * WARNING conditions can be changed with `--mitigation` (e.g. `--mitigation ok`)

Vendor specific notes:

* Brother print servers (e.g. NC-9300w) do not answer to SNMP get-bulk requests: the plugin detects Brother printers
  by their sysObjectID and uses get-next requests, so they can be monitored with SNMP v2c too.
* Lexmark printers are detected by the Lexmark private MIB, Brother, Kyocera and HP printers by their sysObjectID.
  Printers of other vendors use the standard PRINTER-MIB, even if they emulate the HP JetDirect MIB.

#### Services Sets

Service Set:

* `nx-ss-network-printer` with the services:
  * `Printer Hardware Status` (mode `hardware-health`)
  * `Printer Supplies Status` (mode `supplies-status`)
  * `Printer Uptime` (mode `uptime`)
  * `Printer Page Count` (mode `page-count`)
  * `Printer Info` (mode `printer-info`)
  * `Printer Status` (mode `printer-status`)

#### Commands

Commands:

* `nx-c-check-printer-health`

### Dashboard ITOA

The NEP doesn't provide a dedicated dashboard, but user can build it using the available data.

## Usage

In order to use this NEP, add the Host Template `nx-ht-network-printer-snmp` to the Host.
Configure these fields:

* SNMP Community
* SNMP Version (if needed)

Services are then attached to this device and monitored.
