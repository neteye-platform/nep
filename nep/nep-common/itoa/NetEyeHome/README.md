# Overview
This dashboard helps you to quickly understand how is the health status of  NetEye system (from the point of view of performance monitoring and host performance).
Some panels read data from the Telegraf datasource `telegraf_master` ([telegraf configuration](https://neteye.guide/current/core-modules/itoa/telegraf-config.html#telegraf-configuration)).
**It works only for only for NetEye single node installations.**

# Dashboard Output

The dashboard will show you the health status of  NetEye system (single node)

# Dashboard Example

You can find an example [here](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FTpobGWFMk%2Fneteye-home%3ForgId%3D3).


# Requirements

This dashboard requires NetEye 4.48 or newer: monitoring data are read from IcingaDB, since the Icinga IDO database is no longer available.
Before importing this dashboard, ensure the following requirements are met. If not, please make the required changes accordingly.

## Grafana Datasources

The dashboard reads monitoring data from the MySQL datasource `icingadb-mysql` (database `icingadb`). The datasource is created automatically in the Main Org by the `nep-common` setup (`setup_scripts/pre/09_create_grafana_datasources.sh`), so no manual MySQL user or datasource creation is needed.

The InfluxDB datasources `icinga2-influxdb` (Icinga metrics, `neteye_master` variable and Monitoring Performance panels) and `telegraf_master` (Host Performance panels, Telegraf metrics of the NetEye nodes) are also required.

Datasources are referenced by name, so the dashboard works without changes on any NetEye installation where they exist.

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
