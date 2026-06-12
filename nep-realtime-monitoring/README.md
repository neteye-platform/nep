# NEP Realtime Monitoring

The `nep-realtime-monitoring` provide basic Host Templates and Service Templates pre-configured with minimal Service Checks for Linux and Windows Operating Systems based on InfluxDB data sent by Telegraf agents installed on the Operating System.


# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Usage](#usage)


## Prerequisites

| Software Version          | Version |
| ------------------------- | ------- |
| NetEye                    | 4.32    |
| nep-common                | 0.2.0  |
| nep-centreon-plugins-base | 0.1.0   |
| nep-influxdb-query        | 0.1.1   |


##### Required NetEye Modules

| NetEye Module |
| ------------- |
| None          |


### External dependencies

* InfluxDB Connectivity
* Data on InfluxDB sent by Telegraf Agent

## Installation

#### Before Installation

There is no need to perform any action before installing this NEP


### NEP Installation

To install the NEP, run this command using SSH on NetEye Master Node:
```bash
nep-setup install nep-realtime-monitoring
```


#### Finalizing Installation

There is no need to perform any action to complete the installation of this NEP


## Packet Contents

### Director/Icinga Objects

#### Host Templates

* `nx-ht-computer-realtime`
* `nx-ht-server-realtime-linux`
* `nx-ht-server-realtime-windows`
* `nx-ht-status-influxdb-uptime`


#### Service Templates

* `nx-st-agentless-influxdb-centreon-query-precompiled`
* `nx-st-centreon-influxdb-query-cpu-usage`
* `nx-st-centreon-influxdb-query-disk-free-linux`
* `nx-st-centreon-influxdb-query-disk-free-windows`
* `nx-st-centreon-influxdb-query-load`
* `nx-st-centreon-influxdb-query-mem-available`
* `nx-st-centreon-influxdb-query-mem-used`
* `nx-st-centreon-influxdb-query-systemd-unit-status`
* `nx-st-centreon-influxdb-query-uptime-count`
* `nx-st-centreon-influxdb-query-uptime-value`
* `nx-st-centreon-influxdb-query-windows-service-status`


#### Services Sets

* `nx-ss-server-realtime-linux-basic`
    * CPU Usage
    * Disk Free Space
    * Memory Free
    * Memory Usage
    * System Uptime
* `nx-ss-server-realtime-windows-basic`
    * CPU Usage
    * Disk Free Space
    * Memory Free
    * Memory Usage
    * System Uptime
* `nx-ss-server-realtime-windows-basic-blending`
    * Realtime CPU Usage
    * Realtime Disk Free Space
    * Realtime Memory Free
    * Realtime Memory Usage
    * Realtime System Uptime
* `nx-ss-server-realtime-linux-basic-blending`
    * Realtime CPU Usage
    * Realtime Disk Free Space
    * Realtime Memory Free
    * Realtime Memory Usage
    * Realtime System Uptime

#### Command

Command Objects:

* `nx-c-centreon-influxdb-query-cpu-usage`
* `nx-c-centreon-influxdb-query-disk-free-linux`
* `nx-c-centreon-influxdb-query-disk-free-windows`
* `nx-c-centreon-influxdb-query-load`
* `nx-c-centreon-influxdb-query-mem-available`
* `nx-c-centreon-influxdb-query-mem-used`
* `nx-c-centreon-influxdb-query-systemd-unit`
* `nx-c-centreon-influxdb-query-uptime`
* `nx-c-centreon-influxdb-query-uptime-value`
* `nx-c-centreon-influxdb-query-windows-service`

#### Data List

* [NX] Centreon InfluxDB Query aggregations List
* [NX] Centreon InfluxDB SystemD Active Code List
* [NX] Centreon InfluxDB Windows Service State Code List

#### Notification

This NEP doesn't provide any Notification definition

### Automation

This NEP doesn't provide any Automation


### Tornado Rules

This NEP doesn't provide any Tornado rules


### Dashboard ITOA

This NEP doesn't provide any ITOA Dashboards


### Metrics

This NEP doesn't generate any Performance Data from its commands.

## Usage

### Create Host Objects for Realtime Monitoring

1. Ensure all the proper configurations for `nep-influxdb-query` have been done.
2. Ensure the Host (Windows or Linux) has a running Telegraf instance with the minimum configuration reported at [Setup Realtime Monitoring clients](#setup-realtime-monitoring-clients-telegraf-agents) .
3. Create a Host Objects using the minimum templates reported in this screenshot; make sure to use (in place of `test-ht-influxdb-neteye-telegraf_master`) the right Host Template created during the setup of `nep-influxdb-query`.
![Configure Host](/doc-images/configure-host.png)
4. Deploy the configuration and see the result
![Deploy Configuration](/doc-images/deploy-conf.png)
![Deploy Configuration Services](/doc-images/deploy-conf-services.png)

### Examples

#### Basic Usage

1. Ensure the requested telemetry is sent to the right InfluxDB (if NetEye NATS Infrastructure is used, metrics are automatically routed to the InfluxDB Server managing the Tenant Database).
2. Identify the Hostname tagging the incoming telemetry (see source Telegraf Agent configuration, if Telegraf is used)
3. Create a new Host Object inheriting from the right Host Template created during Basic Setup
![Create Host Object](/doc-images/create-ho.png)
4. Build your own custom InfluxDB query that will monitor the Telemetry (follow [InfluxDB | Centreon Documentation](https://docs.centreon.com/pp/integrations/plugin-packs/procedures/applications-databases-influxdb/))
   1. Make sure to group by some field (usually is `host`): this will used as Instance by the Plugin
   2. Remember to prefix the measurement name with the InfluxDB Database and Retention policy names
   3. Always define an alias for the sole field the query will return
   4. The alias should be used as prefix for the query text, as requested by the Plugin
   5. Example of query for the status of unit `ssh.service`:
        ``` sql
        active_code,select last(active_code) as active_code from telegraf_master.autogen.systemd_units where time > now() - 1m and host='nexus' and "name"='ssh.service' group by host;
        ```
5. Add a new Service Object to the Host Object
   1. Use template `nx-st-agentless-influxdb-centreon-query`
    ![Use the template nx-st-agentless-influxdb-centreon-query](/doc-images/use-st.png)
   2. Add the query, then provide values for thresholds, Output Text and Global Text *at least*:
    ![Create and compile the new service](/doc-images/create-and-compile-new-service.png)
   3.Deploy and see the result:
    ![Deploy and see the result](/doc-images/deploy-result.png)


#### Setup Realtime Monitoring Clients (Telegraf Agents)

This section describes how to get telemetry metrics with Telegraf Agents into InfluxDB.

1. Get authentication certificates from the NetEye that will receive telemetry:
   1. SSL Client Certificate Root CA Public key: `/neteye/local/telegraf/conf/certs/root-ca.crt`
   2. SSL Client Certificate Public key: `/neteye/local/telegraf/conf/certs/telegraf_wo.crt.pem`
   3. SSL Client Certificate Private Key: `/neteye/local/telegraf/conf/certs/private/telegraf_wo.key.pem`
2. Install Telegraf on the monitored system (follow [Install Telegraf | Telegraf Documentation](https://docs.influxdata.com/telegraf/v1/install/))
3. Place the Certificate files you got from NetEye in the Configuration Folder of your Telegraf
4. Test the configuration files (follow [Telegraf Configuration | Telegraf Documentation](https://docs.influxdata.com/telegraf/v1/install/#generate-a-custom-configuration-file))
5. Run Telegraf as a Service (follow [Running Telegraf as a Windows Service
 | InfluxData](https://archive.docs.influxdata.com/telegraf/v1.4/administration/windows_service/), or follow the procedures for your specific OS)

#### Minimal Telegraf Configuration Files for Realtime Monitoring

##### Minimal Configuration for Linux Systems

``` toml
# Telegraf Configuration

[global_tags]

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = "0s"
  hostname = ""
  omit_hostname = false

###############################################################################
#                            OUTPUT PLUGINS                                   #
###############################################################################

# # Send telegraf measurements to NATS
[[outputs.nats]]
   ## URLs of NATS servers
   servers = ["nats://<NetEye FQDN>:4222"]

   ## Optional credentials
   # username = ""
   # password = ""

   ## Optional NATS 2.0 and NATS NGS compatible user credentials
   # credentials = "/etc/telegraf/nats.creds"

   ## NATS subject for producer messages
   subject = "telegraf.metrics"

   ## Use Transport Layer Security
   secure = true
   ## Optional TLS Config
   tls_ca = "<Path to NetEye Root CA Public Key>"
   tls_cert = "<Path to NetEye Telegraf WO Public Key>"
   tls_key = "<Path to NetEye Telegraf WO Private Key>"
   ## Use TLS but skip chain & host verification
   # insecure_skip_verify = false

   ## Data format to output.
   ## Each data format has its own unique set of configuration options, read
   ## more about them here:
   ## https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_OUTPUT.md
   data_format = "influx"

###############################################################################
#                            INPUT PLUGINS                                    #
###############################################################################

[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.kernel]]

[[inputs.mem]]

[[inputs.processes]]

[[inputs.swap]]

[[inputs.system]]

[[inputs.systemd_units]]

```

##### Minimal Configuration for Windows Systems

``` toml
# Telegraf Configuration

[global_tags]

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = "0s"
  hostname = "<Server FQDN>"
  omit_hostname = false

###############################################################################
#                            OUTPUT PLUGINS                                   #
###############################################################################

# # Send telegraf measurements to NATS
[[outputs.nats]]
   ## URLs of NATS servers
   servers = ["nats://<NetEye FQDN>:4222"]

   ## Optional credentials
   # username = ""
   # password = ""

   ## Optional NATS 2.0 and NATS NGS compatible user credentials
   # credentials = "/etc/telegraf/nats.creds"

   ## NATS subject for producer messages
   subject = "telegraf.metrics"

   ## Use Transport Layer Security
   secure = true

   ## Optional TLS Config
   tls_ca = "<Path to NetEye Root CA Public Key>"
   tls_cert = "<Path to NetEye Telegraf WO Public Key>"
   tls_key = "<Path to NetEye Telegraf WO Private Key>"
   ## Use TLS but skip chain & host verification
   # insecure_skip_verify = false

   ## Data format to output.
   ## Each data format has its own unique set of configuration options, read
   ## more about them here:
   ## https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_OUTPUT.md
   data_format = "influx"

###############################################################################
#                            INPUT PLUGINS                                    #
###############################################################################

[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.kernel]]

[[inputs.mem]]

[[inputs.processes]]

[[inputs.swap]]

[[inputs.system]]

[[inputs.win_services]]

```