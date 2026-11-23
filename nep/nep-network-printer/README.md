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
4. [Supported printers](#supported-printers)
5. [Usage](#usage)

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

#### Changes of the monitoring after the update to 0.1.0

* `Printer Hardware Status` and `Printer Supplies Status` also report the problems that the printer signals (see
  [How problems are notified](#how-problems-are-notified)). They can become WARNING or CRITICAL for problems that the
  previous versions did not notify, e.g. toner low on Brother printers, paper jam, no paper. An open door reported by
  the printer is CRITICAL. Without problems the output does not change.
* Brother printers can be monitored with SNMP v2c (the previous versions timed out).
* New services: `Printer Page Count`, `Printer Info`, `Printer Status`.

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
  * `hardware-health`: checks the printer hardware: covers, plus the hardware problems reported by the printer
    (door open, paper jam, missing trays, service requested, ...), see [How problems are notified](#how-problems-are-notified)
  * `supplies-status`: checks consumables, toner, ink cartridges, etc.: supplies levels, plus the supplies problems
    reported by the printer (toner low, no paper, output bin full, ...), see [How problems are notified](#how-problems-are-notified)
  * `page-count`: page counters as performance data (always OK)
    * all vendors: `pages_total` (PRINTER-MIB prtMarkerLifeCount) and `pages_since_poweron` (prtMarkerPowerOnCount)
    * vendor specific counters: see [Supported printers](#supported-printers)
  * `printer-info`: model and serial number of the printer (always OK)
  * `printer-status`: status of the printer itself (offline, device down, alerts which are neither hardware nor
    supplies). It lists all the problems reported by the printer and the text of the display, but only its own
    problems make it WARNING or CRITICAL, see [How problems are notified](#how-problems-are-notified).
    Performance data: number of all the active problems (`problems_critical`, `problems_warning`)

#### How problems are notified

The printer reports its problems in HOST-RESOURCES-MIB (`hrPrinterDetectedErrorState`, `hrDeviceStatus`) and in
PRINTER-MIB (`prtAlertTable`). Every problem is notified by **one service only**, so the same problem does not send two
notifications:

| Problem reported by the printer | Service WARNING / CRITICAL | Level |
| --- | --- | --- |
| no toner, toner cartridge or other supply missing, no paper, output bin full | `Printer Supplies Status` | CRITICAL |
| toner low, paper low, input tray empty, output bin almost full | `Printer Supplies Status` | WARNING |
| supplies alerts: toner/ink empty or almost empty, waste toner full, drum (OPC) or developer life over, input/output media low/empty/full, finisher supplies | `Printer Supplies Status` | severity of the alert |
| door open, paper jam, input tray missing, output tray missing | `Printer Hardware Status` | CRITICAL |
| service requested, preventive maintenance overdue | `Printer Hardware Status` | WARNING |
| hardware alerts: cover or interlock open, jam, missing subunit, motor/memory/storage failure, fuser or temperature problems, finisher device | `Printer Hardware Status` | severity of the alert |
| printer offline | `Printer Status` | CRITICAL |
| device status down or warning, when the printer reports no problem explaining it | `Printer Status` | CRITICAL (down), WARNING (warning) |
| any other alert (e.g. interpreter, channel, vendor specific alert codes) | `Printer Status` | severity of the alert |

Rules:

* Alerts with severity critical make the service CRITICAL, alerts with severity warning make it WARNING. Alerts which
  only inform about an event (powered up, door closed, configuration changed, media size changed, ...) are ignored.
* `Printer Hardware Status` keeps checking the covers table: an open cover is WARNING, an open door reported by the
  printer is CRITICAL (the printer cannot print).
* `Printer Supplies Status` keeps checking the supplies levels (`*_remaining` below 20% WARNING, below 5% CRITICAL,
  `*_used` above 90% WARNING, above 95% CRITICAL). The problems reported by the printer make toner low visible also on
  printers which report the toner level only as "some remaining" (e.g. Brother).
* `Printer Status` stays OK for hardware and supplies problems and lists them, for example:
  `OK - Brother HL-L2400DWE is idle, reported by Supplies Status: Brother HL-L2400DWE: lowToner, alert: Toner Low, display: Toner Low`
* The WARNING level of all the services can be changed with `--mitigation` (e.g. `--mitigation ok`).
* Zebra label printers follow the same rule with the ZEBRA-MIB: head open, head temperature, cutter jam in
  `Printer Hardware Status`; media out, ribbon out in `Printer Supplies Status`; printer paused in `Printer Status`.
* Printers which implement only HOST-RESOURCES-MIB (no PRINTER-MIB) report their problems the same way in the three
  services.

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

The NEP provides the Grafana dashboard `Network Printer Overview` (folder `itoa/NetworkPrinterOverview`): choose a
printer and see in the header its name, address, model, serial number and ping (colored by round trip time), then the
page counters (exact numbers and pages per day), the active problems (services of the printer which are CRITICAL,
WARNING or UNKNOWN now) and the supplies levels.

## Supported printers

The plugin detects the vendor of the printer, the vendor classes use the standard MIBs (PRINTER-MIB RFC 3805,
HOST-RESOURCES-MIB) like all the other printers and add the data of the vendor private MIB.

### Printers with vendor specific support

| Vendor | Detection | Additional data |
| --- | --- | --- |
| HP | sysObjectID `1.3.6.1.4.1.11`, sysDescr starting with `HP` | page counters `print_color`, `print_mono`, `print_duplex` (HP JetDirect) |
| Lexmark | Lexmark private MIB | hardware alerts and status, supplies, page counters `print_*`, `copy_*`, `fax_total`, `blank_*`, ... (LEXMARK-MPS-MIB) |
| Brother | sysObjectID `1.3.6.1.4.1.2435` | SNMP get-next requests: Brother print servers do not answer to get-bulk requests |
| Kyocera, Utax, TA Triumph-Adler | sysObjectID `1.3.6.1.4.1.1347` | standard data only |
| Canon | sysObjectID `1.3.6.1.4.1.1602` | page counters `machine_total`, `color_total`, `mono_total`, `color_a3`, `color_a4`, `mono_a3`, `mono_a4` |
| Ricoh, Lanier, Nashuatec, Gestetner, Rex-Rotary | sysObjectID `1.3.6.1.4.1.367` | page counters `machine_total`, `color_total`, `mono_total`, `print_total`, `copy_total`, `fax_total` |
| Konica Minolta, Develop | sysObjectID `1.3.6.1.4.1.18334` | page counters `machine_total`, `color_total`, `mono_total`, `print_color`, `print_mono`, `copy_color`, `copy_mono`, `duplex_total`, `originals_total` |
| Xerox | sysObjectID `1.3.6.1.4.1.253` | page counters `color_total`, `mono_total` (lifetime impressions) |
| Samsung (also HP models built by Samsung) | sysObjectID `1.3.6.1.4.1.236` | page counters per job and color (`print_color`, `print_mono`, `copy_color`, `copy_mono`, `scan_*`, `fax_in_*`, ...), `color_total`, `mono_total` |
| Zebra (label printers) | sysObjectID `1.3.6.1.4.1.10642` | ZEBRA-MIB: hardware (head open, head temperature, cutter jam), supplies (media out, ribbon out), status (also printer paused), labels printed as `pages_total`, `print_length_total`, model and serial number |

The counters of a vendor are reported only if the printer implements them, otherwise the standard counters are used.
Olivetti printers are built by Konica Minolta or Kyocera and are detected as these vendors.

Sources of the vendor OIDs: Canon and Ricoh counters as used by the Checkmk checks `canon_pages` and
`printer_pages_ricoh`, Zebra from the official Zebra Link-OS MIB, Xerox and Samsung from their MIBs (Observium MIB
browser), Konica Minolta from community sources. Konica Minolta, Samsung and the Xerox color counter are not verified on
real devices yet: please report differences with an `snmpwalk` of the printer.

### Printers using the standard check

All the other network printers are monitored with the standard MIBs. What each mode needs from the printer:

| Mode | Standard objects | Without them |
| --- | --- | --- |
| `hardware-health` | PRINTER-MIB covers (`prtCoverTable`), HOST-RESOURCES-MIB `hrPrinterDetectedErrorState`, PRINTER-MIB `prtAlertTable` | OK, nothing to check |
| `supplies-status` | PRINTER-MIB `prtMarkerSuppliesTable` (level and maximum capacity), `hrPrinterDetectedErrorState`, `prtAlertTable` | supplies reporting only "some remaining" (-3) are OK unless the printer reports a problem |
| `uptime` | SNMPv2-MIB `sysUpTime` / HOST-RESOURCES-MIB `hrSystemUptime` | UNKNOWN |
| `page-count` | PRINTER-MIB `prtMarkerLifeCount`, `prtMarkerPowerOnCount` | UNKNOWN |
| `printer-info` | HOST-RESOURCES-MIB `hrDeviceDescr` (printer device), PRINTER-MIB `prtGeneralSerialNumber` | model from `sysDescr`, serial `unknown` |
| `printer-status` | HOST-RESOURCES-MIB `hrPrinterDetectedErrorState`, `hrDeviceStatus`, PRINTER-MIB `prtAlertTable` | UNKNOWN |

Vendors known to implement these MIBs (standard check, no vendor specific data):

* Office printers and multifunction printers: Epson, Sharp, Toshiba, OKI, Fujifilm Business Innovation (Fuji Xerox),
  Dell (models built by Fuji Xerox; the models built by Lexmark are detected as Lexmark), Panasonic, Muratec, Sindoh,
  Pantum (partial support of PRINTER-MIB)
* Large format printers: Canon imagePROGRAF (Canon class, standard counters), HP DesignJet (HP class), Epson SureColor.
  Their counters are often a length or an area, not pages: `page-count` reports the unit of the printer counter
* Label printers other than Zebra (Honeywell / Intermec, SATO, TSC, Datamax-O'Neil, Brady, Toshiba TEC): the support of
  the standard MIBs is often minimal, check the result of the `printer-status` and `page-count` services

## Usage

In order to use this NEP, add the Host Template `nx-ht-network-printer-snmp` to the Host.
Configure these fields:

* SNMP Community
* SNMP Version (if needed)

Services are then attached to this device and monitored.
