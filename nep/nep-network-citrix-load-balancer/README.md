# Network Citrix Load Balancer

The `nep-network-citrix-load-balancer` package adds SNMP-based monitoring
for Citrix NetScaler load balancers to NetEye using Centreon plugins.
It provides service checks for CPU, hardware health, interfaces, memory,
connections, certificates, virtual servers, and high availability state.

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

This package can be installed on systems running the software described
below. Systems with equivalent components are also suitable for
installation.

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.46+ |
| nep-common | 0.6.8+ |
| nep-centreon-plugins-base | 0.2.2+ |

##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |

### External dependencies

- RPM package
  `centreon-plugin-network-loadbalancers-netscaler-snmp`
  (automatically installed by the pre-install setup script from the
  Centreon stable repository)

## Installation

### Before Installation

There is no need to perform any action before installing this NEP.

### NEP Installation

To setup Package `nep-network-citrix-load-balancer`, use the Setup
Utility:

```bash
nep-setup install nep-network-citrix-load-balancer
```

After the installation is complete, you can use the provided objects and
configure the NEP.

The pre-install setup scripts will:

- Add the `citrix` vendor entry to the vendor list
- Install the Centreon NetScaler SNMP plugin

#### Finalizing Installation

There is no need to perform any action to complete the installation of
this NEP.

## Packet Contents

This package contains Director commands, service templates, and service
sets for monitoring Citrix NetScaler load balancers via SNMP using the
Centreon NetScaler plugin.

### Director/Icinga Objects

The Package contains the following Director Objects.

| Object Type | Object Name | Editable | Containing File |
| --- | --- | --- | --- |
| Director Command | `nx-c-centreon-citrix-netscaler-cpu` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Command | `nx-c-centreon-citrix-netscaler-hardware` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Command | `nx-c-centreon-citrix-netscaler-interfaces` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Command | `nx-c-centreon-citrix-netscaler-memory` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Command | `nx-c-centreon-citrix-netscaler-connections` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Command | `nx-c-centreon-citrix-netscaler-vservers` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Command | `nx-c-centreon-citrix-netscaler-certificates` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Command | `nx-c-centreon-citrix-netscaler-ha-state` | No | `baskets/import/nep-network-citrix-netscaler-02-command.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-cpu` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-hardware` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-interfaces` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-memory` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-connections` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-vserver` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-certificates` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Template | `nx-st-agentless-snmp-centreon-citrix-netscaler-ha-state` | No | `baskets/import/nep-network-citrix-netscaler-04-service.json` |
| Director Service Set | `nx-ss-network-centreon-citrix-netscaler` | No | `baskets/import/nep-network-citrix-netscaler-05-serviceset.json` |
| Director Service Set | `nx-ss-network-centreon-citrix-netscaler-extras` | No | `baskets/import/nep-network-citrix-netscaler-05-serviceset.json` |

#### Host Templates

This NEP doesn't provide any Host Template definition.

#### Service Templates

- `nx-st-agentless-snmp-centreon-citrix-netscaler-cpu`
- `nx-st-agentless-snmp-centreon-citrix-netscaler-hardware`
- `nx-st-agentless-snmp-centreon-citrix-netscaler-interfaces`
- `nx-st-agentless-snmp-centreon-citrix-netscaler-memory`
- `nx-st-agentless-snmp-centreon-citrix-netscaler-connections`
- `nx-st-agentless-snmp-centreon-citrix-netscaler-vserver`
- `nx-st-agentless-snmp-centreon-citrix-netscaler-certificates`
- `nx-st-agentless-snmp-centreon-citrix-netscaler-ha-state`

#### Service Sets

- `nx-ss-network-centreon-citrix-netscaler`
  - `CPU Load`
  - `HW Health`
  - `Memory Usage`
- `nx-ss-network-centreon-citrix-netscaler-extras`
  - `Certificates Status`
  - `Connections Status`
  - `High Availability Status`

#### Commands

| Icinga Command | File Path |
| --- | --- |
| `nx-c-centreon-citrix-netscaler-cpu` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |
| `nx-c-centreon-citrix-netscaler-hardware` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |
| `nx-c-centreon-citrix-netscaler-interfaces` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |
| `nx-c-centreon-citrix-netscaler-memory` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |
| `nx-c-centreon-citrix-netscaler-connections` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |
| `nx-c-centreon-citrix-netscaler-vservers` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |
| `nx-c-centreon-citrix-netscaler-certificates` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |
| `nx-c-centreon-citrix-netscaler-ha-state` | `/usr/lib/centreon/plugins/centreon_netscaler.pl` |

#### Notification

This NEP doesn't provide any Notification definition.

### Automation

This NEP doesn't provide any Automation.

### Tornado Rules

This NEP doesn't provide any Tornado rules.

### Dashboard ITOA

This NEP doesn't provide any ITOA Dashboards.

## Usage

The service sets provided by this NEP can be used in two ways.
The base service set `nx-ss-network-centreon-citrix-netscaler` is
applied when a host meets all of the following conditions:

- The host uses the `nx-ht-network-switch-snmp` host template
- The host variable `nx_hardware_vendor` is set to `netscalers`

The extras service set
`nx-ss-network-centreon-citrix-netscaler-extras` requires all of the
following conditions:

- The host uses the `nx-ht-network-switch-snmp` host template
- The host variable `nx_hardware_vendor` is set to `netscalers`
- The host variable `nx_enable_nep_ss` is set to `true`
- The host variable `nx_enable_nep_extras` is set to `true`
- The service set `nx-ss-network-centreon-citrix-netscaler` is not
  listed in the host variable `nx_nep_ss_to_exclude`

The extras service set adds monitoring for certificates, connections,
and high availability status.

The service templates for interfaces and virtual servers are provided by
the NEP but are not automatically assigned by the included service sets.
They can be manually attached to individual hosts in Director when those
checks are required.