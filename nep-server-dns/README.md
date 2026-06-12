# NEP Server DNS
The `nep-server-dns` provides the minimum requirements to implement a monitoring of DNS Server .

Using the provided objects, is possible to:

* Service DNS Server Status
* DNS A record Status
* DNS PTR record Status
* Domain A record Status
* Domain _msdcs A record Status


# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.20 |
| nep-common | 0..0.4 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| CORE |


### External dependencies

This NEP doesn't need any external dependecies other that the ones used by the NEPs reported in [Prerequisites](#prerequisites)


## Installation

#### Before Installation

There is no need to perform any action before installing this NEP


### NEP Installation

To install the `nep-server-dns`, use `nep-setup` via SSH on NetEye Master Node:
```
nep-setup install nep-server-dns
```


#### Finalizing Installation

There is no need to perform any action to complete the installation of this NEP


## Packet Contents

### Director/Icinga Objects

This NEP doesn't provide any Director/Icinga object


#### Host Templates

The following Host Templates can be used to freely create Host Objects.

_Remember to not edit these Host Templates because they will be restored/updated at the next NEP package update_:

* `nx-ht-windows-dns-server`: Describe a generic Windows DNS Server.


#### Service Templates

The following Service Templates can be used to freely create Service Objects, Service Apply Rules or Service Sets.

_Remember to not edit these Service Templates as they will be restored/updated at the next NEP Package update_:

* `nx-st-agentless-dns-record-status`: Checks all aspects of monitoring of a DNS Server


#### Services Sets

The following Service Sets can be used to freely monitor Host Objects.

_Remember to not edit these Service Sets because they will be restored/updated at the next NEP Package update_:

* `nx-ss-windows-ad-dns-server`: Service Set providing common monitoring for DNS Server:
    * Service DNS Server Status
    * DNS A record Status
    * DNS PTR record Status
    * Domain A record Status
    * Domain _msdcs A record Status


#### Command

This NEP doesn't provide any command


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


### Examples

#### Using a host template provided by the NEP

![Host Template Example](doc-images/host-template-windows-dns-server.png)

#### Using a service template provided by the NEP

Example of Service Set `nx-ss-windows-ad-dns-server`:

![Service Set Example](doc-images/service-set-windows-ad-dns-server.png)