# NEP Network H3C

The `nep-network-h3c` module provides SNMP monitoring for H3C network
switches and routers through the Centreon H3C plugin. It adds Director
commands, service templates, data lists, and a service set for CPU,
hardware health, memory, and interface monitoring.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

| Software | Version |
| --- | --- |
| NetEye | >=4.48 |
| nep-common | >=0.6.8 |
| nep-network-base | >=0.0.4 |
| nep-centreon-plugins-base | >=0.2.2 |

### Required NetEye Modules

| NetEye Module |
| --- |
| neteye |

### External dependencies

The NEP installs the following package during the pre-installation phase:

- `centreon-plugin-Network-H3c-Snmp` from the Centreon stable or EPEL
  repositories.

## Installation

Install the NEP on the NetEye master node using SSH:

```bash
nep-setup install nep-network-h3c
```

### Before Installation

Ensure that the required NEPs are installed and that the Centreon package
repositories are available to the NetEye node.

### Finalizing Installation

No manual finalization is required. The pre-installation scripts install the
Centreon plugin and add the H3C vendor and `Other` model to the NetEye asset
lists. In a cluster, vendor and model entries are updated only when the
`icingaweb2` DRBD mount is active.

## Packet Contents

### Director/Icinga Objects

The module imports the following Director objects. Objects are imported from
the regular `baskets/import/` directory and are not marked as one-time
editable objects.

#### Data Lists

- `[NX] Centreon H3C Interfaces Oid Display`: `IpAddr`, `ifAlias`, `ifDesc`,
  and `ifName`.
- `[NX] Centreon H3C Interfaces Oid Filter`: `IpAddr`, `ifAlias`, `ifDesc`,
  and `ifName`.
- `[NX] Centreon H3C Switch Component List`: `backplane`, `chassis`,
  `container`, `cpu`, `fan`, `module`, `other`, `port`, `psu`, `sensor`,
  `stack`, and `unknown`.
- `[NX] Centreon H3C Switch Mode List`: `cpu`, `hardware`, `interfaces`,
  `list-interfaces`, and `memory`.

#### Host Templates

This NEP does not provide host templates. It uses host templates from
`nep-network-base`, including `nx-ht-network-switch-snmp` and
`nx-ht-network-router-snmp` in the service-set assignment filter.

#### Service Templates

- `nx-st-agentless-snmp-centreon-h3c-base`: base H3C service template.
- `nx-st-agentless-snmp-centreon-h3c-cpu`: monitors CPU usage with
  `nx-c-centreon-h3c-cpu`.
- `nx-st-agentless-snmp-centreon-h3c-hardware`: monitors hardware health with
  `nx-c-centreon-h3c-hardware`; defaults the component filter to `psu`.
- `nx-st-agentless-snmp-centreon-h3c-interfaces`: monitors interfaces with
  `nx-c-centreon-h3c-interfaces`.
- `nx-st-agentless-snmp-centreon-h3c-memory`: monitors memory usage with
  `nx-c-centreon-h3c-memory`.

#### Service Sets

`nx-ss-network-centreon-h3c` is assigned to hosts that use either the
`nx-ht-network-switch-snmp` or `nx-ht-network-router-snmp` host template and
have `host.vars.nx_hardware_vendor` set to `h3c`. It contains:

- `CPU Load`, using `nx-st-agentless-snmp-centreon-h3c-cpu`.
- `HW Health`, using `nx-st-agentless-snmp-centreon-h3c-hardware`.
- `Memory Usage`, using `nx-st-agentless-snmp-centreon-h3c-memory`.

#### Commands

Command templates:

| Object | Plugin command |
| --- | --- |
| `nx-ct-centreon-h3c` | `/usr/lib/centreon/plugins/centreon_h3c.pl` |
| `nx-ct-centreon-h3c-hw` | `/usr/lib/centreon/plugins/centreon_h3c.pl --mode hardware` |

Command objects:

| Object | Mode or purpose |
| --- | --- |
| `nx-c-centreon-h3c` | Selectable H3C plugin mode with verbose output |
| `nx-c-centreon-h3c-cpu` | CPU usage (`--mode cpu`) |
| `nx-c-centreon-h3c-hardware` | Hardware component and temperature health |
| `nx-c-centreon-h3c-interfaces` | Interface status, errors, and traffic |
| `nx-c-centreon-h3c-memory` | Memory usage (`--mode memory`) |

The commands use threshold and SNMP variables supplied by the imported
Centreon plugin base templates. Hardware checks additionally support
component and item filters. Interface checks support interface selection by
index or name, error and traffic checks, speed, traffic units, and perfdata
filtering.

#### Notifications

This NEP does not provide notification definitions.

### Setup Scripts

The following pre-installation scripts are included:

- `install_plugin_centreon.sh`: installs the Centreon H3C SNMP plugin on
  single-node, active cluster, and satellite deployments.
- `add_vendor_to_list.sh`: adds `h3c,H3C` to the NetEye vendor list when
  applicable.
- `add_model_to_list.sh`: adds `other,Other` to the NetEye model list when
  applicable.

### Automation

This NEP does not provide import sources, sync rules, or jobs.

### Tornado Rules

This NEP does not provide Tornado rules.

### Dashboard ITOA

This NEP does not provide ITOA dashboards.

### Metrics

The Centreon H3C plugin emits performance data for the selected monitoring
mode. Interface checks can emit traffic metrics and optionally interface
error metrics. The exact metric names depend on the plugin mode and the
selected device components.

## Usage

Create or select an SNMP-monitored H3C host using a host template from
`nep-network-base`, set the vendor variable to `h3c`, and apply the service
set `nx-ss-network-centreon-h3c`.

### Examples

#### Applying the H3C service set

Set the host hardware vendor to `h3c` and ensure the host inherits either
`nx-ht-network-switch-snmp` or `nx-ht-network-router-snmp`. The service set
then provides CPU Load, HW Health, and Memory Usage services automatically.

#### Checking H3C interfaces

Use `nx-c-centreon-h3c-interfaces` for interface monitoring. Leave the
interface variable empty to check all interfaces, or provide an interface
index. Enable traffic and error checks as needed and set the SNMP traffic
threshold variables supplied by `nep-centreon-plugins-base`.

#### Checking hardware components

Use `nx-c-centreon-h3c-hardware` with a component such as `fan`, `psu`,
`sensor`, or `temperature`-related thresholds. Hardware thresholds use the
plugin syntax `type,regexp,threshold`, for example:

```text
--warning='temperature,.*,40'
--critical='temperature,.*,45'
```
