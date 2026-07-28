# Network Audiocodes

The `nep-network-audiocodes` adds SNMP-based monitoring for Audiocodes devices to NetEye, using Centreon plugins. It provides service checks for CPU, hardware health, memory, interfaces, SBC calls, and trunk status.

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

This package can be installed on systems running the software described below. Systems with equivalent components are also suitable for installation.

| Software Version | Version |
| --- | --- |
| NetEye | 4.49+ |
| nep-common | 0.13.9+ |
| nep-network-base | 0.5.0+ |
| nep-centreon-plugins-base | 0.2.4+ |

##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |

### External dependencies

- RPM package `centreon-plugin-Network-Audiocodes-Snmp` (automatically installed by the pre-install setup script from the Centreon stable repository)

## Installation

### Before Installation

There is no need to perform any action before installing this NEP.

### NEP Installation

To setup package `nep-network-audiocodes`, use the Setup Utility:

```bash
nep-setup install nep-network-audiocodes
```

After the installation is complete, you can use objects and configure the NEP.

The pre-install setup scripts will:

- Add the `audiocodes` vendor entry to the vendor list (`00_add_vendor_to_list.sh`)
- Install the Centreon Audiocodes SNMP plugin (`01_install_plugin_centreon.sh`)

#### Finalizing Installation

There is no need to perform any action to complete the installation of this NEP.

## Packet Contents

This package contains Director commands, service templates, and service sets for monitoring Audiocodes devices via SNMP using the Centreon Audiocodes plugin.

### Director/Icinga Objects

The package contains the following Director objects.

| Object Type | Object Name | Editable | Containing File |
| --- | --- | --- | --- |
| Director Command | `nx-c-centreon-audiocodes-cpu` | No | `baskets/import/nep-network-audiocodes-02-command.json` |
| Director Command | `nx-c-centreon-audiocodes-hardware` | No | `baskets/import/nep-network-audiocodes-02-command.json` |
| Director Command | `nx-c-centreon-audiocodes-interfaces` | No | `baskets/import/nep-network-audiocodes-02-command.json` |
| Director Command | `nx-c-centreon-audiocodes-memory` | No | `baskets/import/nep-network-audiocodes-02-command.json` |
| Director Command | `nx-c-centreon-audiocodes-sbc-calls` | No | `baskets/import/nep-network-audiocodes-02-command.json` |
| Director Command | `nx-c-centreon-audiocodes-trunk-status` | No | `baskets/import/nep-network-audiocodes-02-command.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-audiocodes-cpu` | No | `baskets/import/nep-network-audiocodes-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-audiocodes-hardware` | No | `baskets/import/nep-network-audiocodes-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-audiocodes-interfaces` | No | `baskets/import/nep-network-audiocodes-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-audiocodes-memory` | No | `baskets/import/nep-network-audiocodes-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-audiocodes-sbc-calls` | No | `baskets/import/nep-network-audiocodes-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-audiocodes-trunk-status` | No | `baskets/import/nep-network-audiocodes-04-service.json` |
| Director Service Set | `nx-ss-network-centreon-audiocodes` | No | `baskets/import/nep-network-audiocodes-05-serviceset.json` |
| Director Service Set | `nx-ss-network-centreon-audiocodes-extras` | No | `baskets/import/nep-network-audiocodes-05-serviceset.json` |

#### Host Templates

This NEP does not provide any Host Template definition.

#### Service Templates

- `nx-st-agentless-snmp-centreon-audiocodes-cpu`
- `nx-st-agentless-snmp-centreon-audiocodes-hardware`
- `nx-st-agentless-snmp-centreon-audiocodes-memory`
- `nx-st-agentless-snmp-centreon-audiocodes-interfaces`
- `nx-st-agentless-snmp-centreon-audiocodes-sbc-calls`
- `nx-st-agentless-snmp-centreon-audiocodes-trunk-status`

#### Services Sets

- `nx-ss-network-centreon-audiocodes`
  - `CPU Load`
  - `Hardware Health`
  - `Memory Usage`
- `nx-ss-network-centreon-audiocodes-extras`
  - `Interfaces Status`
  - `SBC Calls`
  - `Trunk Status`

#### Commands

| Icinga Command | Plugin Path |
| --- | --- |
| `nx-c-centreon-audiocodes-cpu` | `/usr/lib/centreon/plugins/centreon_audiocodes.pl` |
| `nx-c-centreon-audiocodes-hardware` | `/usr/lib/centreon/plugins/centreon_audiocodes.pl` |
| `nx-c-centreon-audiocodes-interfaces` | `/usr/lib/centreon/plugins/centreon_audiocodes.pl` |
| `nx-c-centreon-audiocodes-memory` | `/usr/lib/centreon/plugins/centreon_audiocodes.pl` |
| `nx-c-centreon-audiocodes-sbc-calls` | `/usr/lib/centreon/plugins/centreon_audiocodes.pl` |
| `nx-c-centreon-audiocodes-trunk-status` | `/usr/lib/centreon/plugins/centreon_audiocodes.pl` |

#### Notification

This NEP does not provide any Notification definition.

### Automation

This NEP does not provide any Automation.

### Tornado Rules

This NEP does not provide any Tornado rules.

### Dashboard ITOA

This NEP does not provide any ITOA dashboards.

### Metrics

The check commands provide performance data according to the selected Centreon plugin mode and enabled counters.

## Usage

The service sets provided by this NEP can be used in two ways.
The service sets include built-in apply rules that automatically assign services to matching hosts.

The base service set `nx-ss-network-centreon-audiocodes` is applied when a host meets all of the following conditions:

- The host uses the `nx-ht-network-voip-snmp` host template
- The host variable `nx_hardware_vendor` is set to `audiocodes`
- The host variable `nx_enable_nep_ss` is set to `true`
- The service set `nx-ss-network-centreon-audiocodes` is not listed in the host variable `nx_nep_ss_to_exclude`

The extras service set `nx-ss-network-centreon-audiocodes-extras` requires the same conditions as above, plus:

- The host variable `nx_enable_nep_extras` is set to `true`

Alternatively, you can manually assign the service sets to individual hosts in Director by adding the desired service set directly to the host configuration.