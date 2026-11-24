# Overview
This dashboard allows you to monitor existing problems on NetEye (both for hosts and for services).

# Dashboard Output
The dashboard will show you two different tables showing Hosts DOWN and Services WARNING/CRITICAL with those filters:
- problem handled (Handled/Not handled/All)
- service state (WARNING, CRITICAL, All)

# Dashboard Example
You can find an example [here](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FXfwT78pMz1%2Fneteye-problems%3ForgId%3D3%26refresh%3D30s).

# Requirements
This dashboard requires NetEye 4.48 or newer: monitoring data are read from IcingaDB, since the Icinga IDO database is no longer available.
Before importing this dashboard, ensure the following requirements are met. If not, please make the required changes accordingly.

# Warning
This dashboard does not take into account the user’s role and related permissions and it is intended for use by an administrator on an on-premise non multi-tenant installation of NetEye.

## Grafana Datasources

The dashboard reads monitoring data from the MySQL datasource `icingadb-mysql` (database `icingadb`). The datasource is created automatically in the Main Org by the `nep-common` setup (`setup_scripts/pre/09_create_grafana_datasources.sh`), so no manual MySQL user or datasource creation is needed.

Datasources are referenced by name, so the dashboard works without changes on any NetEye installation where they exist.

# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
