# Network pfSense Firewall

The `nep-network-pfsense-firewall` adds SNMP-based monitoring for pfSense firewalls to NetEye, using Centreon plugins. It provides service checks for CPU, load, memory, swap, runtime, firewall interfaces, and state table connections.

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

This package can be installed on systems running the software described below. Systems with equivalent components are also suitable for installation.

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.47+ |
| nep-common | 0.8.8+ |
| nep-network-base | 0.4.0+ |
| nep-centreon-plugins-base | 0.2.3+ |

##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |

### External dependencies

- RPM package `centreon-plugin-Network-Firewalls-Pfsense-Snmp` (automatically installed by the pre-install setup script from the Centreon stable repository)

## Installation

### Before Installation

There is no need to perform any action before installing this NEP

### NEP Installation

To setup Package `nep-network-pfsense-firewall`, just use the Setup Utility:

```
nep-setup install nep-network-pfsense-firewall
```

After the installation is complete, you can use objects and configure the NEP.

The pre-install setup scripts will:

- Add the `pfsense` vendor entry to the vendor list (`add_vendor_to_list.sh`)
- Install the Centreon pfSense SNMP plugin (`install_plugin_centreon.sh`)

#### Finalizing Installation

There is no need to perform any action to complete the installation of this NEP

## Packet Contents

This package contains Director commands, service templates, and service sets for monitoring pfSense firewalls via SNMP using the Centreon pfSense plugin.

### Director/Icinga Objects

The Package contains the following Director Objects.

| Object Type | Object Name | Editable | Containing File |
| --- | --- | --- | --- |
| Director Command | `nx-c-centreon-pfsense-cpu` | No | `baskets/import/nep-network-pfsense-firewall-02-command.json` |
| Director Command | `nx-c-centreon-pfsense-load` | No | `baskets/import/nep-network-pfsense-firewall-02-command.json` |
| Director Command | `nx-c-centreon-pfsense-memory` | No | `baskets/import/nep-network-pfsense-firewall-02-command.json` |
| Director Command | `nx-c-centreon-pfsense-pfinterfaces` | No | `baskets/import/nep-network-pfsense-firewall-02-command.json` |
| Director Command | `nx-c-centreon-pfsense-runtime` | No | `baskets/import/nep-network-pfsense-firewall-02-command.json` |
| Director Command | `nx-c-centreon-pfsense-state-table` | No | `baskets/import/nep-network-pfsense-firewall-02-command.json` |
| Director Command | `nx-c-centreon-pfsense-swap` | No | `baskets/import/nep-network-pfsense-firewall-02-command.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-pfsense-cpu` | No | `baskets/import/nep-network-pfsense-firewall-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-pfsense-load` | No | `baskets/import/nep-network-pfsense-firewall-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-pfsense-memory` | No | `baskets/import/nep-network-pfsense-firewall-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-pfsense-pfinterfaces` | No | `baskets/import/nep-network-pfsense-firewall-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-pfsense-runtime` | No | `baskets/import/nep-network-pfsense-firewall-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-pfsense-state-table` | No | `baskets/import/nep-network-pfsense-firewall-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-pfsense-swap` | No | `baskets/import/nep-network-pfsense-firewall-04-service.json` |
| Director Service Set | `nx-ss-network-centreon-pfsense` | No | `baskets/import/nep-network-pfsense-firewall-05-serviceset.json` |
| Director Service Set | `nx-ss-network-centreon-pfsense-extras` | No | `baskets/import/nep-network-pfsense-firewall-05-serviceset.json` |

#### Host Templates

This NEP doesn't provide any Host Template definition

#### Service Templates

* `nx-st-agentless-snmp-centreon-pfsense-cpu`
* `nx-st-agentless-snmp-centreon-pfsense-load`
* `nx-st-agentless-snmp-centreon-pfsense-memory`
* `nx-st-agentless-snmp-centreon-pfsense-pfinterfaces`
* `nx-st-agentless-snmp-centreon-pfsense-runtime`
* `nx-st-agentless-snmp-centreon-pfsense-state-table`
* `nx-st-agentless-snmp-centreon-pfsense-swap`

#### Services Sets

* `nx-ss-network-centreon-pfsense`
    * `CPU Load`
    * `Load Status`
    * `Memory Usage`
    * `Runtime`
    * `Swap Usage`
* `nx-ss-network-centreon-pfsense-extras`
    * `Interfaces Status`
    * `State Table Connections Status`

#### Commands

| Icinga Command | File Path |
| --- | --- |
| `nx-c-centreon-pfsense-cpu` | `/usr/lib/centreon/plugins/centreon_pfsense.pl` |
| `nx-c-centreon-pfsense-load` | `/usr/lib/centreon/plugins/centreon_pfsense.pl` |
| `nx-c-centreon-pfsense-memory` | `/usr/lib/centreon/plugins/centreon_pfsense.pl` |
| `nx-c-centreon-pfsense-pfinterfaces` | `/usr/lib/centreon/plugins/centreon_pfsense.pl` |
| `nx-c-centreon-pfsense-runtime` | `/usr/lib/centreon/plugins/centreon_pfsense.pl` |
| `nx-c-centreon-pfsense-state-table` | `/usr/lib/centreon/plugins/centreon_pfsense.pl` |
| `nx-c-centreon-pfsense-swap` | `/usr/lib/centreon/plugins/centreon_pfsense.pl` |

#### Notification

This NEP doesn't provide any Notification definition

### Automation

This NEP doesn't provide any Automation

### Tornado Rules

This NEP doesn't provide any Tornado rules

### Dashboard ITOA

This NEP doesn't provide any ITOA Dashboards

### Metrics

The following performance data metrics are generated by the pfSense check commands.

#### `nx-c-centreon-pfsense-cpu` (mode: `cpu`)

| Metric | Unit | Description |
| --- | --- | --- |
| `cpu.utilization.percentage` | % | Average CPU utilization |
| `*cpu_core*#core.cpu.utilization.percentage` | % | Per-core CPU utilization |

#### `nx-c-centreon-pfsense-load` (mode: `load`)

| Metric | Unit | Description |
| --- | --- | --- |
| `load.1m.average.count` | count | Load average over 1 minute |
| `load.5m.average.count` | count | Load average over 5 minutes |
| `load.15m.average.count` | count | Load average over 15 minutes |
| `load.1m.count` | count | Load over 1 minute |
| `load.5m.count` | count | Load over 5 minutes |
| `load.15m.count` | count | Load over 15 minutes |

#### `nx-c-centreon-pfsense-memory` (mode: `memory`)

| Metric | Unit | Description |
| --- | --- | --- |
| `memory.cached.bytes` | B | Cached memory |
| `memory.usage.bytes` | B | Memory usage |
| `swap.usage.bytes` | B | Swap usage |

#### `nx-c-centreon-pfsense-swap` (mode: `swap`)

| Metric | Unit | Description |
| --- | --- | --- |
| `swap.usage.bytes` | B | Swap usage in bytes |
| `swap.free.bytes` | B | Free swap in bytes |
| `swap.usage.percentage` | % | Swap usage percentage |

#### `nx-c-centreon-pfsense-runtime` (mode: `runtime`)

| Metric | Unit | Description |
| --- | --- | --- |
| `runtime` | s | System runtime in seconds |

#### `nx-c-centreon-pfsense-state-table` (mode: `state-table`)

| Metric | Unit | Description |
| --- | --- | --- |
| `entries` | count | Number of state table entries |
| `entries-inserted` | count | Rate of entries inserted |
| `entries-removed` | count | Rate of entries removed |
| `searches` | count | Rate of state table searches |

#### `nx-c-centreon-pfsense-pfinterfaces` (mode: `pfinterfaces`)

| Metric | Unit | Description |
| --- | --- | --- |
| `*pfint*#pfinterface.pass.traffic.in.bitspersecond` | b/s | Inbound passed traffic per interface |
| `*pfint*#pfinterface.pass.traffic.out.bitspersecond` | b/s | Outbound passed traffic per interface |
| `*pfint*#pfinterface.block.traffic.in.bitspersecond` | b/s | Inbound blocked traffic per interface |
| `*pfint*#pfinterface.block.traffic.out.bitspersecond` | b/s | Outbound blocked traffic per interface |

## Usage

The service sets provided by this NEP can be used in two ways.
The service sets include built-in apply rules that automatically assign services to matching hosts. The base service set `nx-ss-network-centreon-pfsense` is applied when a host meets all of the following conditions:

- The host uses the `nx-ht-network-firewall-snmp` host template
- The host variable `nx_hardware_vendor` is set to `pfsense`
- The host variable `nx_enable_nep_ss` is set to `true`
- The service set `nx-ss-network-centreon-pfsense` is not listed in the host variable `nx_nep_ss_to_exclude`

The extras service set `nx-ss-network-centreon-pfsense-extras` requires the same conditions as above, plus:

- The host variable `nx_enable_nep_extras` is set to `true`

The extras service set adds monitoring for pfSense-specific firewall interfaces and state table connections.

Alternatively, you can manually assign the service sets to individual hosts in Director by adding the desired service set directly to the host configuration.