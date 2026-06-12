# Overview
This dashboard helps you to quickly understand how is the health status of  NetEye system (from the point of view of performance monitoring and host performance).
Some panels reads data from a Telegraf datasource ([telegraf configuration](https://neteye.guide/current/core-modules/itoa/telegraf-config.html#telegraf-configuration)).
**It works only for only for NetEye single node installations.**

# Dashboard Output

The dashboard will show you the health status of  NetEye system (single node)

# Dashboard Example

You can find an example [here](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FTpobGWFMk%2Fneteye-home%3ForgId%3D3).


# Requirements

This Dashboard is compatible with Grafana 7.5.5 (released with NetEye 4.19) and newer.
Before importing this dashboard, ensure the following requirements are met. If not, please make the required changes accordingly.

## Mysql user creation

Create a ReadOnly user in MySQL to access icinga2 database
```
create user 'grafanareadonly'@'localhost' identified by 'XXXXXXXX';
grant select on icinga2.* to 'grafanareadonly'@'localhost';
flush privileges;
```

## Grafana Datasources creation

From ITOA – Data Sources menu create a new MySQL datasource named **icinga-mysql** (if not exists)
```
Host: mariadb.neteyelocal
Database: icinga
User: grafanareadonly
Password: XXXXXXXX
```

**Save&Test**

From ITOA – Data Sources menu create a new InfluxDB datasource named **Telegraf** (if not exists)

```
URL: https://influxdb.neteyelocal:8086
Basic auth enabled

Basic auth Details

User: influxdbreader
Password: (look at cat /root/.pwd_analytics_grafana_viewer_user)

Database: telegraf
User: influxdbreader
Password: (look at cat /root/.pwd_analytics_grafana_viewer_user)
```

**Save&Test**
## Grafana Variable definition

From Dashboard - Settings - Variables (neteye_master) correct the default Regex related to neteye_master variable from dashboard settings. The simple Regex /neteye/ used in our demo environment must be corrected selecting the correct hostname related to your NetEye monitored.

## Grafana pie-chart and clock-panel plugins installation

```
# chmod +x /usr/share/grafana/bin/grafana-cli
# grafana-cli plugins install grafana-piechart-panel
# grafana-cli plugins install grafana-clock-panel
```

# How to import dashboard

To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
