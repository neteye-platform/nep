# nep-notification-servicenow (ALPHA)

> [!WARNING]
> This NEP is provided as a Proof of Concept (PoC) and it is not fully supported!

_As described before this template has been used during a PoC and in order to be reused some customizations are needed. Use this as starting point of your ServiceNow Integration._

If you install this NEP have a look to the script  `nx-notification-servicenow.py` and the conf file `nx-notification-servicenow.json` in order to adapt to your ServiceNow installation.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)

## Prerequisites

| Software Version | Version |
| --- | ----------- |
| NetEye | 4.32 |
| nep-common | 0.1 |

### Required NetEye Modules

| NetEye Module |
| --- |
| SIEM |

### External dependencies

This NEP doesn't need any external dependecies other that the ones used by the NEPs reported in [Prerequisites](#prerequisites)

## Installation

### Before Installation

There is no need to perform any action before installing this NEP

### NEP Installation

To install the NEP, run this command using SSH on NetEye Master Node:

``` bash
nep-setup install nep-notification-servicenow
```

#### Finalizing Installation

There is no need to perform any action to complete the installation of this NEP

## Packet Contents

### Director/Icinga Objects

This NEP doesn't provide any Director/Icinga object

#### Host Templates

This NEP doesn't provide any Host Template definition

#### Service Templates

This NEP doesn't provide any Service Template definition

#### Services Sets

This NEP doesn't provide any Service Set definition

#### Command

This NEP doesn't provide any Command-related object

#### Notification

This NEP doesn't provide any Notification definition

### Automation

This NEP doesn't provide any Automation

### Tornado Rules

This NEP doesn't provide any Tornado rules

### Dashboard ITOA

This NEP doesn't provide any ITOA Dashboards

### Metrics

This NEP doesn't generate any Performance Data from its commands

## Usage
