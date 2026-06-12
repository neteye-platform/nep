# nep-sap-system


# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.44 |
| nep-common | 0.0.3 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| Monitoring |


### External dependencies

This NEP needs access to this additional repository


## Installation



## Before Installation

##### Changes to be done at SAP-Profiles necessary for some webservice-checks (sapcontrol)
##### Changes to DEFAULT.PFL:

##### add new line:

------------------------------------------------------------------------

// # (start of change)

// # service/protectedwebmethods = SDEFAULT

service/protectedwebmethods = SDEFAULT -GetVersionInfo -GetAlertTree -GetAlerts -EnqGetStatistic -GetQueueStatistic -GetInstanceProperties -GetSystemInstanceList -ReadLogFile -ListLogFiles -AnalyseLogFiles -ABAPReadSyslog -ABAPGetComponentList -ABAPGetWPTable

// # limit access to webservices of sapstartsrv to neteye-server only

service/http/acl_file = $(DIR_PROFILE)$(DIR_SEP)service_http.acl

service/https/acl_file = $(DIR_PROFILE)$(DIR_SEP)service_https.acl

// # (end of change)

-------------------------------------------------------------------------

##### Create files "service_http.acl" and "service_https.acl" in SAP Profile-directory:

-------------------------------------------------------------------------

Content of file service_http.acl (access control list for http):

permit  127.0.0.1/32                                        # permit localhost

permit  <IP address of 1st SAP-Server>/32     # permit local server 1

permit  <IP address of 2nd SAP-Server>/32    # permit local server 2

// # (similar add all SAP-Applicationservers of the system)

permit <IP-address of Neteye Satellite>/32     # permit NetEye server

deny    0.0.0.0/0                                               # deny the rest

--------------------------------------------------------------------------

##### Content of file service_https.acl (access control list for https):

--------------------------------------------------------------------------

permit  127.0.0.1/32                                        # permit localhost

permit  <IP address of 1st SAP-Server>/32     # permit local server 1

permit  <IP address of 2nd SAP-Server>/32    # permit local server 2

//# (similar add all SAP-Applicationservers of the system)

permit <IP-address of Neteye Satellite>/32     # permit NetEye server

deny    0.0.0.0/0                                               # deny the rest

-------------

##### Restart instance:

sapcontrol -nr <instance-nr> -function RestartService

-----------------------------

### Create a SAP Role for monitoring user i transaction PFCG with permission:

--------------------------
##### RFC - General Access (T-M269013500)

Object: S_RFC

Activity: 16 (Execute)

RFC_NAME whitelist:

ERFC

RFC1

RFC_READ_TABLE

SALX

SDIFRUNTIME

SDTX

SXMI*

SYSP

RFC_TYPE: FUGR (Function Group)

-----------------------

##### RFC - Access to Function Groups SCSM_GLOB_SYSTEM, THFB (T-M269013501)

Activity: 16 (Execute)

RFC_NAME: SCSM_GLOB_SYSTEM, THFB

Type: FUGR

-----------------------

##### RFC - BAPI Access (T-M269013502)

Activity: 16 (Execute)

RFC_NAME:

BAPI_SYSTEM_MON_GETTREE

BAPI_SYSTEM_MTE_GETGENPROP

Type: FUNC (Function Module)

----------------------

##### S_TABU_DIS - Table Maintenance (via SM30)

Activity: 02 (Change)

Authorization Groups:
03, SC, 38, T002, TED32

----------------------

##### S_TABU_NAM - Direct Table Access

Activity: 02 (Change)

Tables:

EDIDS

SNAP

TBTCO

VBDR

--------------------

###### S_TOOLS_EX - Tools Performance Monitor

Value maintained: S_TOOLS_EX

---------------------

###### S_XMI_LOG - XMI Log Access

XMI access method maintained

------------------------

##### S_XMI_PROD - External Management Interfaces (XMI)

Parameters maintained:

Company: LUISBEB, SAP_MONI_LIB

Programs:

CHECK_SAP_HEALTH

IL_MONITORING

Interfaces: XAL, XMB

------------------------



### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-server-sap
```


#### Finalizing Installation

There is nothing to do to finalize the installation of this NEP


## Packet Contents


### Director/Icinga Objects


#### Host Templates
Host Template:

* nx-ht-sap-instance
* nx-ht-sap-system


#### Service Templates
Service Templates:

* nx-st-agentless-sap-sapcontrol
* nx-st-agentless-sap-saphealth
* nx-st-sap-instance-connection-time
* nx-st-sap-instance-queue-stats
* nx-st-sap-instance-status
* nx-st-sap-instance-version-info
* nx-st-sap-instance-wp-table
* nx-st-sap-system-ccms-mte-check
* nx-st-sap-system-enqueue-stats
* nx-st-sap-system-failed-jobs
* nx-st-sap-system-failed-updates
* nx-st-sap-system-shortdumps-count
* nx-st-sap-system-shortdumps-recurrence


#### Services Sets
Service Set:

* nx-ss-sap-instance-ascs-scs
* nx-ss-sap-instance-all
* nx-ss-sap-instance-dialog
* nx-ss-sap-instance-has-messageserver

#### Command
CommandTemplate:

* nx-ct-sap-check-sapcontrol
* nx-ct-sap-check-saphealth
*

Command:

* nx-c-sap-check-sapcontrol-enqueue-stats
* nx-c-sap-check-sapcontrol-instance-status
* nx-c-sap-check-sapcontrol-queue-stats
* nx-c-sap-check-sapcontrol-syslog
* nx-c-sap-check-sapcontrol-version-info
* nx-c-sap-check-sapcontrol-wp-table
* nx-c-sap-check-sapcontrol-wp-table-batch
* nx-c-sap-check-sapcontrol-wp-table-spool
* nx-c-sap-check-sapcontrol-wp-table-update
* nx-c-sap-check-saphealth-connection-time
* nx-c-sap-check-saphealth-failed-jobs
* nx-c-sap-check-saphealth-failed-updates
* nx-c-sap-check-saphealth-shortdumps-count
* nx-c-sap-check-saphealth-shortdumps-recurrence
* nx-c-sap-check-saphealth-workload-overview



#### Notification

This NEP doesn't provvide any Notification


### Automation

This NEP doesn't provide any Automation Objects


### Tornado Rules

This NEP doesn't provide any Tornado Rules


### Dashboard ITOA



### Metrics

This NEP doesn't produce any performance data


## Usage



### Examples

#### Using a host template provided by the NEP

Associate the host template based on the type of monitoring you want to perform


#### Using a service template provided by the NEP

Service set hooks automatically based on the value of the SAP Instance type variable
