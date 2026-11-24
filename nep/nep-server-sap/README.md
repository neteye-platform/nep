# NEP SAP System

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)
5. [Troubleshooting](#troubleshooting)
6. [Known limitations](#known-limitations)

## Prerequisites

| Software Version | Version |
| --- | ----------- |
| NetEye | 4.44 |
| nep-common | 0.0.3 |

### Required NetEye Modules

| NetEye Module |
| --- |
| Monitoring |

### External dependencies

* `check_sap_health` (ConSol, patched, see
  [Patch for check_sap_health](#patch-for-check_sap_health))
  * path: `/neteye/shared/monitoring/plugins/check_sap_health`
  * used by: all `nx-c-sap-check-saphealth-*` commands
* SAP NW RFC SDK 7.50
  * path: `/neteye/shared/monitoring/plugins/sap/nwrfcsdk/lib`
  * used by: `check_sap_health`
    (via `--environment LD_LIBRARY_PATH=...`)
* Perl module `sapnwrfc` (SAPNW::Connection) 0.37
  * path: `/usr/local/lib64/perl5`
  * used by: `check_sap_health`
* Extension `CheckSapHealthNetEye.pm`
  * path: `/neteye/shared/monitoring/plugins/sap/mymodules/`
  * used by: commands `nx-c-sap-check-saphealth-my-*`
* `check_sapcontrol.sh`
  * path: `/neteye/shared/monitoring/plugins/check_sapcontrol.sh`
  * used by: all `nx-c-sap-check-sapcontrol-*` commands
* `sapcontrol` binary
  * path: `/neteye/shared/monitoring/software/sapcontrol`
  * used by: `check_sapcontrol.sh`

## Installation

## Before Installation

### SAP profile changes for the sapcontrol webservice checks

Changes to `DEFAULT.PFL`:

``` text
##### add new lines:

-----------------------------------------------------------------------

// # (start of change)

// # service/protectedwebmethods = SDEFAULT
```

<!-- markdownlint-disable MD013 -->
``` text
service/protectedwebmethods = SDEFAULT -GetVersionInfo -GetAlertTree -GetAlerts -EnqGetStatistic -GetQueueStatistic -GetInstanceProperties -GetSystemInstanceList -ReadLogFile -ListLogFiles -AnalyseLogFiles -ABAPReadSyslog -ABAPGetComponentList -ABAPGetWPTable
```
<!-- markdownlint-enable MD013 -->

``` text
// # limit access to webservices of sapstartsrv to neteye-server only

service/http/acl_file = $(DIR_PROFILE)$(DIR_SEP)service_http.acl

service/https/acl_file = $(DIR_PROFILE)$(DIR_SEP)service_https.acl

// # (end of change)

-----------------------------------------------------------------------

##### Create files "service_http.acl" and "service_https.acl"
##### in the SAP profile directory:

-----------------------------------------------------------------------

Content of file service_http.acl (access control list for http):

permit  127.0.0.1/32                         # permit localhost

permit  <IP address of 1st SAP-Server>/32    # permit local server 1

permit  <IP address of 2nd SAP-Server>/32    # permit local server 2

// # (similar add all SAP-Applicationservers of the system)

permit  <IP-address of Neteye Satellite>/32  # permit NetEye server

deny    0.0.0.0/0                            # deny the rest

-----------------------------------------------------------------------

##### Content of file service_https.acl (access control list for https):

-----------------------------------------------------------------------

permit  127.0.0.1/32                         # permit localhost

permit  <IP address of 1st SAP-Server>/32    # permit local server 1

permit  <IP address of 2nd SAP-Server>/32    # permit local server 2

// # (similar add all SAP-Applicationservers of the system)

permit  <IP-address of Neteye Satellite>/32  # permit NetEye server

deny    0.0.0.0/0                            # deny the rest

-------------

##### Restart instance:

sapcontrol -nr <instance-nr> -function RestartService

-----------------------------
```

`GetSystemInstanceList` (service *SAP System Application Servers*) and
`ABAPGetWPTable` (services *Dialog free*, *Dialog privmode*,
*Batch/Update/Spool free*) are already in the list above.
The ACL files must also be present on the **ASCS** instance, because
*SAP System Application Servers* calls `GetSystemInstanceList` on the
message server instance.

### Create a SAP Role for the monitoring user in transaction PFCG

The RFC user (system or communication user) must exist in the client used
for the RFC logon (host variable `nx_sap_system_client`, default `000`).
`ENQUEUE_READ`, `TRFCQIN` and `TRFCQOUT` are needed only by the KPI
extension services.

#### S_RFC - General Access

* ACTVT: `16` (Execute)
* RFC_TYPE: `FUGR`, `FUNC`
* RFC_NAME:
  * `FRFC`
  * `RFC1`
  * `RFC_READ_TABLE`
  * `SALX`
  * `SDIFRUNTIME`
  * `SDTX`
  * `SXMI*`
  * `SYST`

#### S_RFC - Function groups

* ACTVT: `16` (Execute)
* RFC_TYPE: `FUGR`
* RFC_NAME: `SCSM_GLOB_SYSTEM`, `THFB`

#### S_RFC - BAPI / function modules

* ACTVT: `16` (Execute)
* RFC_TYPE: `FUNC`
* RFC_NAME:
  * `BAPI_SYSTEM_MON_GETTREE`
  * `BAPI_SYSTEM_MTE_GETGENPROP`
  * `BAPI_SYSTEM_MTE_GETPERFCURVAL`
  * `BAPI_SYSTEM_MTE_GETPERFPROP`
  * `BAPI_SYSTEM_MTE_GETSMVALUE`
  * `BAPI_SYSTEM_MTE_GETMLCURVAL`
  * `BAPI_SYSTEM_MTE_GETTXTPROP`
  * `BAPI_SYSTEM_MON_GETLIST`
  * `BAPI_SYSTEM_MS_GETLIST`
  * `ENQUEUE_READ` (service *SAP System Lock Entries older 1d*)

#### S_TABU_DIS - Table access by authorization group

* ACTVT: `03` (Display)
* DICBERCLS: `SA`, `SC`, `SS`

#### S_TABU_NAM - Table access by table name

* ACTVT: `03` (Display)
* TABLE:
  * `EDIDS`
  * `SNAP`
  * `TBTCO`
  * `VBHDR`
  * `T002`
  * `TEDS2`
  * `TRFCQIN` (service *SAP System qRFC Queues in Error*)
  * `TRFCQOUT` (service *SAP System qRFC Queues in Error*)

#### S_TOOLS_EX - Tools Performance Monitor

* AUTH: `S_TOOLS_EX_A`

#### S_XMI_LOG - XMI Log Access

* XMILOGACC: `*`

#### S_XMI_PROD - External Management Interfaces (XMI)

* EXTCOMPANY: `LAUSSER`, `SAP_MONI_LIB`
* EXTPRODUCT: `CHECK_SAP_HEALTH`, `LL_MONITORING`
* INTERFACE: `XAL`, `XMB`

Notes:

* `--mode ccms-mte-check` calls a different BAPI depending on the MTE
  class: `GETPERFCURVAL`/`GETPERFPROP` (numeric MTEs), `GETSMVALUE`
  (single message), `GETMLCURVAL` (message container), `GETTXTPROP`
  (text). A missing one shows up as UNKNOWN with an RFC authorization
  error (check with ST01 / SU53).
* `T002` and `TEDS2` are table names (used by `--mode failed-idocs`),
  so they belong to `S_TABU_NAM`, not to `S_TABU_DIS`.
* If *SAP System Lock Entries older 1d* reports fewer lock entries than
  SM12, check the authorization trace (ST01) of the RFC user while the
  check runs.

### Install / update the plugins on NetEye

#### Patch for check_sap_health

With SAP NW RFC SDK 7.50 and the Perl binding `sapnwrfc` 0.37,
`check_sap_health` crashes with `Segmentation fault` as soon as it reads
more than one MTE in the same session: the binding destroys function
descriptions that belong to the SDK cache. Two changes are needed in
`/neteye/shared/monitoring/plugins/check_sap_health`:

#### check_sapcontrol.sh

Replace `/neteye/shared/monitoring/plugins/check_sapcontrol.sh` with the
version of this NEP. Existing functions are unchanged. New functions:

* `ABAPGetWPTableBTC`, `ABAPGetWPTableUPD`, `ABAPGetWPTableUP2`,
  `ABAPGetWPTableSPO`
  * number of free work processes of one type
  * `-warn` / `-crit`: alarm if free WPs <= value (default `0`)
* `GetSystemInstanceList`
  * status of all instances of the system
  * `-pattern`: regexp on instance features (e.g. `ABAP`)
  * RED/GRAY = CRITICAL, YELLOW = WARNING
  * `-warn` / `-crit`: optional minimum number of GREEN instances

#### Extension CheckSapHealthNetEye.pm

Modes:

* `my-updates`: update requests in VBHDR (SM13, all clients) older than
  `--lookback` seconds
  * `--name`: regexp on client
* `my-locks`: lock entries (ENQUEUE_READ, SM12) older than `--lookback`
  seconds
  * `--name`: client (default `*`)
  * `--name2`: user (default `*`)
  * `--name3`: regexp on table
* `my-queues`: qRFC queues in error state
  (TRFCQIN = SMQ2, TRFCQOUT = SMQ1)
  * `--name`: `in`, `out` or `both`
  * `--name2`: states
    (default `SYSFAIL,CPICERR,STOP,WAITSTOP,ANORETRY`)
  * `--name3`: regexp on `<client>/<queue>`

Default thresholds `--warning 0 --critical 0`
(CRITICAL as soon as one object is found).

### NEP Installation

In order to install the NEP run:

``` bash
nep-setup install nep-server-sap
```

#### Finalizing Installation

Set the following host variables (Director, host object):

* `nx_sap_system_sid`, `nx_sap_system_client`,
  `nx_sap_system_username`, `nx_sap_system_password`
  * hosts: all SAP hosts
  * example: `FTP`, `000`
  * needed by: all `check_sap_health` services
* `nx_sap_instance_type`, `nx_sap_instance_number`
  * hosts: all SAP instance hosts
  * example: `D`, `20`
  * needed by: service set assignment
* `nx_sap_instance_is_msserver`
  * hosts: ASCS / DVEBMGS with message server
  * example: `true`
  * needed by: sets `nx-ss-sap-instance-has-messageserver` and
    `nx-ss-sap-instance-has-messageserver-extras`
* `nx_sap_instance_ccms_name`
  * hosts: dialog instances (D, DVEBMGS)
  * example: `sapftp1_FTP_20`
  * needed by: sets `nx-ss-sap-instance-dialog-extras`, `nx-ss-sap-os-ccms`
* `nx_sap_system_logongroup`
  * hosts: host with message server
  * example: `<LOGON GROUP>`
  * needed by: set `nx-ss-sap-system-logongroup`
* `nx_sap_instance_responsetime_warning`,
  `nx_sap_instance_responsetime_critical`
  * hosts: dialog instances
  * example: `1000`, `2000` (ms)
  * needed by: service *SAP Instance Response Time*

`nx_sap_instance_ccms_name` is the instance name used by CCMS:
`<sap hostname>_<SID>_<instance number>` (transaction SM51 or RZ20).
The logon group in `nx_sap_system_logongroup` must be enabled for RFC in
SMLG.
Service set `nx-ss-sap-os-ccms` has no assign filter: assign it manually
to the SAP instance hosts.

## Packet Contents

### Director/Icinga Objects

Existing objects are not modified by the EXTRAS extension, except the two
data fields added to the host templates.

#### Host Templates

* `nx-ht-sap-instance` (field `nx_sap_instance_ccms_name`)
* `nx-ht-sap-system` (field `nx_sap_system_logongroup`)

#### Service Templates

* `nx-st-agentless-sap-sapcontrol`
* `nx-st-agentless-sap-saphealth`
* `nx-st-sap-instance-connection-time`
* `nx-st-sap-instance-queue-stats`
* `nx-st-sap-instance-status`
* `nx-st-sap-instance-version-info`
* `nx-st-sap-instance-wp-table`
* `nx-st-sap-system-ccms-mte-check`
* `nx-st-sap-system-enqueue-stats`
* `nx-st-sap-system-failed-jobs`
* `nx-st-sap-system-failed-updates`
* `nx-st-sap-system-shortdumps-count`
* `nx-st-sap-system-shortdumps-recurrence`
* `nx-st-sap-instance-ccms-mte-check`
* `nx-st-sap-instance-wp-table-batch`
* `nx-st-sap-instance-wp-table-update`
* `nx-st-sap-instance-wp-table-spool`
* `nx-st-sap-system-instance-list`
* `nx-st-sap-system-old-updates`
* `nx-st-sap-system-old-locks`
* `nx-st-sap-system-qrfc-errors`

#### Services Sets

* `nx-ss-sap-instance-ascs-scs`
* `nx-ss-sap-instance-all`
* `nx-ss-sap-instance-dialog`
* `nx-ss-sap-instance-has-messageserver`
* `nx-ss-sap-instance-has-messageserver-extras`
  (assign filter as `nx_enable_nep_extras`)
* `nx-ss-sap-instance-dialog-extras`
  (assign filter as `nx_enable_nep_extras`)
* `nx-ss-sap-system-logongroup`
  (only if `nx_sap_system_logongroup` is set)
* `nx-ss-sap-os-ccms`

#### Commands

Command Template:

* `nx-ct-sap-check-sapcontrol`
* `nx-ct-sap-check-saphealth`

Command:

* `nx-c-sap-check-sapcontrol-enqueue-stats`
* `nx-c-sap-check-sapcontrol-instance-status`
* `nx-c-sap-check-sapcontrol-queue-stats`
* `nx-c-sap-check-sapcontrol-syslog`
* `nx-c-sap-check-sapcontrol-version-info`
* `nx-c-sap-check-sapcontrol-wp-table`
* `nx-c-sap-check-sapcontrol-wp-table-batch`
* `nx-c-sap-check-sapcontrol-wp-table-spool`
* `nx-c-sap-check-sapcontrol-wp-table-update`
* `nx-c-sap-check-sapcontrol-system-instance-list`
* `nx-c-sap-check-saphealth-ccms-mte-check`
* `nx-c-sap-check-saphealth-connection-time`
* `nx-c-sap-check-saphealth-failed-jobs`
* `nx-c-sap-check-saphealth-failed-updates`
* `nx-c-sap-check-saphealth-shortdumps-count`
* `nx-c-sap-check-saphealth-shortdumps-recurrence`
* `nx-c-sap-check-saphealth-workload-overview`
* `nx-c-sap-check-saphealth-my-updates`
* `nx-c-sap-check-saphealth-my-locks`
* `nx-c-sap-check-saphealth-my-queues`

The commands `wp-table-batch`, `wp-table-spool` and `wp-table-update`
work only with the `check_sapcontrol.sh` of this NEP.

#### Notification

This NEP doesn't provide any Notification

### Automation

This NEP doesn't provide any Automation Objects

### Tornado Rules

This NEP doesn't provide any Tornado Rules

### Dashboard ITOA

### Metrics

All services produce performance data. Labels of `ccms-mte-check`
services are `<CCMS object>_<MTE name>` (e.g. `Dialog_Utilisation`,
`R3MemMgmtResources_EsAct`); these labels are also the keys for
`nx_sap_saphealth_warningx` / `nx_sap_saphealth_criticalx`.

## Usage

### Examples

#### Using a host template provided by the NEP

Associate the host template based on the type of monitoring you want to
perform

#### Using a service template provided by the NEP

Service set hooks automatically based on the value of the SAP Instance
type variable

### Services and KPI coverage

Thresholds left empty use the CCMS thresholds defined in RZ20.
Format: service - check - KPI - default threshold.

#### Host with message server

Sets `nx-ss-sap-instance-has-messageserver` and
`nx-ss-sap-instance-has-messageserver-extras`:

* SAP Instance Connection Time
  * RFC logon via message server, logon group SPACE
  * KPI: LogOn Group - threshold: 1 s / 5 s
* SAP System Logon Group (set `nx-ss-sap-system-logongroup`)
  * RFC logon via the end-user logon group
  * KPI: LogOn Group - threshold: 1 s / 5 s
* SAP System Application Servers
  * sapcontrol GetSystemInstanceList, ABAP instances
  * KPI: All application servers - threshold: RED/GRAY = CRITICAL
* SAP System Failed Jobs last 12h
  * TBTCO, aborted jobs
  * KPI: Standard jobs - threshold: any aborted job = CRITICAL
* SAP System Background
  * CCMS free batch WPs and batch queue, system wide
  * KPI: Work processes - threshold: RZ20
* SAP System Failed Updates last 24h
  * VBHDR, new records
  * KPI: Update - threshold: 10 / 20
* SAP System Update Service Status
  * CCMS update service active
  * KPI: Update - threshold: RZ20
* SAP System Update Requests older 1d
  * VBHDR records older than 24 h (my-updates)
  * KPI: Update > 1 day - threshold: > 0
* SAP System Enqueue Errors
  * CCMS enqueue errors, enqueue update queue
  * KPI: Lock entries - threshold: RZ20
* SAP System Lock Entries older 1d
  * ENQUEUE_READ, locks older than 24 h (my-locks)
  * KPI: Lock > 1 day - threshold: > 0
* SAP System qRFC Inbound / Outbound
  * CCMS blocked queues (all clients), QIN/QOUT scheduler errors,
    unregistered inbound queues
  * KPI: Queues - threshold: RZ20
* SAP System qRFC Queues in Error
  * TRFCQIN/TRFCQOUT queues in error state (my-queues)
  * KPI: Queues - threshold: > 0
* SAP System tRFC SM58 (3 services)
  * CCMS ARFCSSTATE / ARFCRSTATE
  * KPI: tRFC - threshold: see service
* SAP System Shortdumps (2 services)
  * SNAP
  * KPI: Dump - threshold: see service
* SAP System License expiration
  * CCMS - threshold: RZ20

#### Dialog instances

Sets `nx-ss-sap-instance-dialog` and `nx-ss-sap-instance-dialog-extras`:

* SAP Instance Dialog free / privmode
  * sapcontrol ABAPGetWPTable
  * KPI: Work processes - threshold: 3/1 free, 2/4 PRIV
* SAP Instance Batch / Update / Spool free
  * sapcontrol ABAPGetWPTable per WP type
  * KPI: Work processes - threshold: 0 free = CRITICAL
* SAP Instance Queue Stats
  * sapcontrol dispatcher queue
  * KPI: Work processes - threshold: 70 % / 90 %
* SAP Instance Dialog
  * CCMS dialog utilisation, errors per minute
  * KPI: Work processes - threshold: RZ20
* SAP Instance WP Status
  * CCMS WPs in hold, WP restarts
  * KPI: Work processes - threshold: RZ20
* SAP Instance Update WP
  * CCMS V1/V2 utilisation, queue time, errors
  * KPI: Update - threshold: RZ20
* SAP Instance Logon Load
  * CCMS logon load quality, users logged in
  * KPI: LogOn Group - threshold: quality without alarm
* SAP Instance Response Time
  * CCMS dialog response time
  * KPI: Response time - threshold: host variables
    `nx_sap_instance_responsetime_*`
* SAP Instance Memory
  * CCMS extended memory, heap, EM slots, paging,
    extended global memory, shared objects
  * KPI: Tune summary shared memory - threshold: 80 % / 85 % used,
    20 % / 15 % free
* SAP Instance Buffers
  * CCMS buffer swaps, hit ratio of Program and TableBuffer
  * KPI: Tune summary swaps - threshold: RZ20
* SAP Instance OS Swap
  * CCMS OS swap space
  * KPI: Tune summary swaps - threshold: per host (see limitations)
* SAP Instance Parameter Changes
  * CCMS profile parameter changes
  * KPI: Tune summary parameters - threshold: RZ20

#### OS metrics from CCMS

Set `nx-ss-sap-os-ccms`, assign manually:

* SAP OS CPU: CPU utilisation, 5 min load average
  * threshold: 90 % / 95 %
* SAP OS Memory: free memory
  * threshold: RZ20
* SAP OS Filesystems: `Percentage_Used` of all filesystems except
  `/dev`, `/run`, `/sys`
  * threshold: RZ20

### Writing ccms-mte-check services

* List the MTEs of a monitor (the names to be used in `--name3`):

  ``` bash
  check_sap_health <connection> --mode list-ccms-mtes \
    --name "<monitor set>" --name2 "<monitor>"
  ```

* All services of this NEP use `separator=#` and `regexp=1`, e.g.
  `$host.vars.nx_sap_instance_ccms_name$#Dialog#(Utilisation|ErrorFreqInWpDIA)`.
* A literal `$` (end of regexp) must be written `$$` in Director,
  otherwise Icinga treats it as a macro.
* Override CCMS thresholds with `nx_sap_saphealth_warningx` /
  `nx_sap_saphealth_criticalx`, one entry per metric:
  `<label>=<threshold>`, no spaces around `=`
  (Nagios range syntax: `80` = alarm above 80, `15:` = alarm below 15).

## Troubleshooting

* `Segmentation fault` with more than one MTE
  * `check_sap_health` not patched, see
    [Patch for check_sap_health](#patch-for-check_sap_health)
* `UNKNOWN - cannot write status file ...`
  * long `--name3` without patch 2, or state directory not writable by
    the icinga user (`nx_sap_saphealth_statefilesdir`)
* `UNKNOWN - no mtes`
  * `--name3` does not match: check with `list-ccms-mtes`, check
    `nx_sap_instance_ccms_name`, check `$$` at the end of the regexp
* warningx / criticalx ignored
  * spaces around `=` or wrong label (compare with the performance data
    of the service)
* UNKNOWN with RFC authorization error
  * missing BAPI or table authorization, see
    [SAP Role](#create-a-sap-role-for-the-monitoring-user-in-transaction-pfcg)
* `my-*` modes: `Class MyXxx needs an init() method` or module not found
  * `CheckSapHealthNetEye.pm` missing in
    `/neteye/shared/monitoring/plugins/sap/mymodules`
* sapcontrol services: `Unable to read WP-Table` / `instance list`
  * sapstartsrv not reachable, ACL files or
    `service/protectedwebmethods` missing on the instance

## Known limitations

* *SAP Instance OS Swap*: CCMS provides free swap space and percentage,
  not used swap in GB. For "swap used > 1 GB" set per host
  `nx_sap_saphealth_criticalx` = `Swap_Space_Freespace=<size - 1024>:`.
* "Abnormal parameter values" of ST02 are not available in CCMS;
  *SAP Instance Parameter Changes* reports changes of profile parameters
  only.
* Roll area (ST02) is not reported by CCMS (monitor *Roll Paging* has no
  MTEs).
* Single and multiple message MTEs (e.g. *Update Status*,
  *Blocked queues*) report the CCMS alert status and can stay red until
  the alert is completed in RZ20.
* *SAP System Lock Entries older 1d* passes `*` as client and user to
  ENQUEUE_READ; if the result does not match SM12, set the production
  client in `nx_sap_saphealth_name`.
