# NRPE
The **nep-nrpe-base** package provides support for implementing agentless basic monitoring.

With `nep-nrpe-base` it is possible to perform standard monitoring of:

* Linux servers

* Winodws servers

Using the objects provided, it is possible:

Perform basic check based on NRPE (CPU load, memory usage, disk space usage, swap usage, server uptime)

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)

## Prerequisites

| Sofware Version | Version |
| --- | ----------- |
| NetEye | 4.44 |
| nep-common | 2.0.0 |


##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |


### External dependencies

On NetEye environment this operation is automatically done by Setup Routine. Check and add the port 5666 in the firewall configuration on the public interface:

```
firewall-cmd --get-active-zones
firewall-cmd --zone=public --add-port=5666/tcp --permanent
firewall-cmd --reload
```

## Installation

If all requirements are met, you can now install this package.

### NEP Installation

In order to install the NEP run:
```
nep-setup install nep-nrpe-base
```
### Setup On the Linux Client
```
yum install epel-release
yum --enablerepo=epel -y install nrpe nagios-plugins
systemctl enable nrpe.service
systemctl start nrpe.service
```

Check that the NRPE service is in a running state and listening on port 5666:
```
netstat -anop | grep nrpe
tcp        0      0 0.0.0.0:5666            0.0.0.0:*               LISTEN      13542/nrpe           off (0.00/0/0)
tcp6       0      0 :::5666                 :::*                    LISTEN      13542/nrpe           off (0.00/0/0)
```
Edit configuration file:
```
vim /etc/nagios/nrpe.cfg
```
Add the subnet to the configuration file:
```
allowed_hosts=127.0.0.1,::1,[YOUR SUBNET, ie: 192.168.1.0]
```
Ensure that the ‘dont_blame_nrpe’ is set to 1 to accept the NRPE parameters:
```
dont_blame_nrpe=1
```
The default commands do not accept parameters, so the following NEP-compatible commands must be added:
```
command[nx_check_load]=/usr/lib64/nagios/plugins/check_load $ARG1$
command[nx_check_disk]=/usr/lib64/nagios/plugins/check_disk $ARG1$
command[nx_check_swap]=/usr/lib64/nagios/plugins/check_swap $ARG1$
command[nx_check_mem]=/usr/lib64/nagios/plugins/check_mem $ARG1$
command[nx_check_users]=/usr/lib64/nagios/plugins/check_users $ARG1$ $ARG2$
command[nx_check_cpu_stats]=/usr/lib64/nagios/plugins/check_cpu_stats.sh $ARG1$
command[nx_check_mem]=/usr/lib64/nagios/plugins/custom_check_mem -n $ARG1$
command[nx_check_init_service]=sudo /usr/lib64/nagios/plugins/check_init_service $ARG1$
command[nx_check_services]=/usr/lib64/nagios/plugins/check_services -p $ARG1$
command[nx_check_yum]=/usr/lib64/nagios/plugins/check_yum
command[nx_check_apt]=/usr/lib64/nagios/plugins/check_apt
command[nx_check_all_procs]=/usr/lib64/nagios/plugins/custom_check_procs
command[nx_check_procs]=/usr/lib64/nagios/plugins/check_procs $ARG1$
command[nx_check_open_files]=/usr/lib64/nagios/plugins/check_open_files.pl $ARG1$
command[nx_check_netstat]=/usr/lib64/nagios/plugins/check_netstat.pl -p $ARG1$ $ARG2$
```
Save, Exit and then restart the service:
```
systemctl restart nrpe.service
systemctl status nrpe.service

● nrpe.service - Nagios Remote Program Executor
    Loaded: loaded (/usr/lib/systemd/system/nrpe.service; enabled; vendor preset: disabled)
    Active: active (running) since Fri 2022-08-05 17:12:10 CEST; 8s ago
    Docs: http://www.nagios.org/documentation
    Process: 13607 ExecStopPost=/bin/rm -f /run/nrpe/nrpe.pid (code=exited, status=0/SUCCESS)
    Main PID: 13609 (nrpe)
    CGroup: /system.slice/nrpe.service
       └─13609 /usr/sbin/nrpe -c /etc/nagios/nrpe.cfg -f

    Aug 05 17:12:10 centos7-test systemd[1]: Started Nagios Remote Program Executor.
    Aug 05 17:12:10 centos7-test nrpe[13609]: Starting up daemon
    Aug 05 17:12:10 centos7-test nrpe[13609]: Server listening on 0.0.0.0 port 5666.
    Aug 05 17:12:10 centos7-test nrpe[13609]: Server listening on :: port 5666.
    Aug 05 17:12:10 centos7-test nrpe[13609]: Listening for connections on port 5666
    Aug 05 17:12:10 centos7-test nrpe[13609]: Allowing connections from: 127.0.0.1,::1,192.168.1.0/24
```
### Setup On the Windows Client
Download and Install the NSCP++ Agent NSCP-0.5.2.35-x64.msi (https://github.com/mickem/nscp/releases/tag/0.5.2.35)

Edit the config file for NSCP++ (C:Program FilesNSClient++nsclient.ini)
```
# If you want to fill this file with all available options run the following command:
#   nscp settings --generate --add-defaults --load-all
# If you want to activate a module and bring in all its options use:
#   nscp settings --activate-module <MODULE NAME> --add-defaults
# For details run: nscp settings --help

; in flight - TODO
[/settings/default]

; Undocumented key
#Password for access to local web server used for configuration of NSCP++
password = xxxxxxx

; Undocumented key
allowed hosts = 127.0.0.1,[YOUR SUBNET OR NETEYE SERVER, ie: 192.168.1.0]/24

; in flight - TODO
[/settings/NRPE/server]
allowed hosts=127.0.0.1,[YOUR SUBNET OR NETEYE SERVER, ie: 192.168.1.0]/24
allow arguments=true
allow nasty characters=true
insecure=true

; Undocumented key
verify mode = none

; Undocumented key
insecure = true

; in flight - TODO
[/modules]

; Undocumented key
CheckExternalScripts = enabled

; Undocumented key
CheckHelpers = enabled

; Undocumented key
CheckNSCP = enabled

; Undocumented key
CheckDisk = enabled

; Undocumented key
WEBServer = enabled

; Undocumented key
CheckSystem = enabled

; Undocumented key
NSClientServer = enabled

; Undocumented key
CheckEventLog = enabled

; Undocumented key
NSCAClient = enabled

; Undocumented key
NRPEServer = enabled
CheckWMI = enabled
CheckLogFile = enabled
SimpleFileWriter = enabled
SimpleCache = enabled

; SyslogClient - Forward information as syslog messages to a syslog server
SyslogClient = enabled

; NRPEClient - NRPE client can be used both from command line and from queries to check remote systes via NRPE as well as configure the NRPE server
NRPEClient = enabled

; NRDPClient - NRDP client can be used both from command line and from queries to check remote systes via NRDP
NRDPClient = enabled

; DotnetPlugin - Plugin to load and manage plugins written in dot net.
DotnetPlugins = enabled

; CommandClient - A command line client, generally not used except with "nscp test".
CommandClient = enabled

; CheckNet - Network related check such as check_ping.
CheckNet = enabled

; Scheduler - Use this to schedule check commands and jobs in conjunction with for instance passive monitoring through NSCA
Scheduler = enabled

; Op5Client - Client for connecting nativly to the Op5 Nortbound API
Op5Client = enabled

; SMTPClient - SMTP client can be used both from command line and from queries to check remote systes via SMTP
SMTPClient = enabled

; LUAScript - Loads and processes internal Lua scripts
LUAScript = enabled

; PythonScript - Loads and processes internal Python scripts
PythonScript = enabled

; GraphiteClient - Graphite client can be used to submit graph data to a graphite graphing system
GraphiteClient = enabled

; CheckTaskSched - Check status of your scheduled jobs.
CheckTaskSched = enabled

; NSCAServer - A server that listens for incoming NSCA connection and processes incoming requests.
NSCAServer = enabled

# Section for WEB (WEBServer.dll) (check_WEB) protocol options.
[/settings/WEB/server]
allowed hosts = 127.0.0.1,[YOUR SUBNET, ie: 192.168.1.0]/24
cache allowed hosts = true
certificate = ${certificate-path}/certificate.pem
port = 8443
threads = 10

; Script wrappings - A list of templates for defining script commands. Enter any command line here and they will be expanded by scripts placed under the wrapped scripts section. %SCRIPT% will be replaced by the actual script an %ARGS% will be replaced by any given arguments.
[/settings/external scripts/wrappings]

; Batch file - Command used for executing wrapped batch files
bat = scripts\\%SCRIPT% %ARGS%

; Visual basic script - Command line used for wrapped vbs scripts
vbs = cscript.exe //T:30 //NoLogo scripts\\lib\\wrapper.vbs %SCRIPT% %ARGS%

; POWERSHELL WRAPPING - Command line used for executing wrapped ps1 (powershell) scripts
ps1 = cmd /c echo If (-Not (Test-Path "scripts\%SCRIPT%") ) { Write-Host "UNKNOWN: Script `"%SCRIPT%`" not found."; exit(3) }; scripts\%SCRIPT% $ARGS$; exit($lastexitcode) | powershell.exe /noprofile -command -
```
In this example of the configuration file, all modules including the web server have been activated! Ensure that port 5666 is open.


## Packet Contents

This section contains a description of all the Objects from this package that can be used to build your own monitoring environment.

### Director/Icinga Objects

#### Data List

| Datalist name | Description |
| --- | ----------- |
| [NX] NRPE Target Type | Used to list the types of operating systems and discriminate the type of agent to be used |

#### Host Templates

| Host Template name | Description |
| --- | ----------- |
| nx-ht-server-agentless-nrpe | Generic NRPE object |
| nx-ht-server-agentless-nrpe-linux | Generic NRPE Linux Host Template |
| nx-ht-server-agentless-nrpe-windows | Generic NRPE Windows Host Template |
| nx-ht-server-agentless-nrpe-windows-legacy | Generic NRPE Windows Legacy Host Template |

#### Service Templates

| Service Template name | Run on Agent | Description |
| --- | --- | -------------|
| nx-st-agentless-nrpe | YES | Generic Service Template for NRPE |
| nx-st-agentless-nrpe-linux | YES | Generic Service Template for NRPE Linux |
| nx-st-agentless-nrpe-linux-check-nrpe | YES | Used for NRPE Version |
| nx-st-agentless-nrpe-linux-cpu-load | YES | Measures the performances of CPU |
| nx-st-agentless-nrpe-linux-disk-space-usage | YES | Measuring the Disk space utilisation |
| nx-st-agentless-nrpe-linux-memory-usage | YES | Measuring the Memory utilisation |
| nx-st-agentless-nrpe-linux-swap-usage | YES | Measuring swap utilisation |
| nx-st-agentless-nrpe-linux-uptime | YES | Measures the time of System Uptime |
| nx-st-agentless-nrpe-windows | YES | Generic Service Template for NRPE Windows |
| nx-st-agentless-nrpe-windows-counters | YES | Check the specific performance counter |
| nx-st-agentless-nrpe-windows-cpu-load | YES | Measures the performances of CPU |
| nx-st-agentless-nrpe-windows-cpu-load-legacy | YES | Measures the performances of CPU |
| nx-st-agentless-nrpe-windows-disk-space-usage | YES | Measuring the Disk space utilisation |
| nx-st-agentless-nrpe-windows-disk-space-usage-legacy | YES | Measuring the Disk space utilisation |
| nx-st-agentless-nrpe-windows-memory-usage | YES | Measuring the Memory utilisation |
| nx-st-agentless-nrpe-windows-memory-usage-legacy | YES | Measuring the Memory utilisation |
| nx-st-agentless-nrpe-windows-network | YES | Measuring the Network utilisation |
| nx-st-agentless-nrpe-windows-os-version | YES | Check the Operating system version |
| nx-st-agentless-nrpe-windows-pagefile-usage | YES | Measuring swap utilisation |
| nx-st-agentless-nrpe-windows-process | YES | Check system process |
| nx-st-agentless-nrpe-windows-service | YES | Check Service state |
| nx-st-agentless-nrpe-windows-uptime | YES | Measures the time of System Uptime |
| nx-st-agentless-nrpe-windows-uptime-legacy | YES | Measures the time of System Uptime |
| nx-st-agentless-nrpe-windows-wmi | YES | Check the specific WMI Query |

#### Sercices Sets

| Service Set name | Description |
| --- | -------------|
| nx-ss-server-agentless-nrpe-linux-basic | Service Set providing common monitoring for Linux-based servers |
| nx-ss-server-agentless-nrpe-windows-basic | Service Set providing common monitoring for Windows-based servers |
| nx-ss-server-agentless-nrpe-windows-basic-legacy | Service Set providing common monitoring for Windows-based servers Legacy |

#### Command

* nx-c-check-nrpe
