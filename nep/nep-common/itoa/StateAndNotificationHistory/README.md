# Overview
This dashboard helps you to have a summary of how many notifications are produced, by whom and to whom they are delivered.

# Dashboard Output
The dashboard will show you a table with those filters:

- state type (Hard,Soft)
- state transitions (Host to UP, Host to DOWN, Host to N/A, Service to OK, Service to WARNING, Service to CRITICAL, Service to UNKNOWN, Service to N/A)
- notification reasons (Normal notification, Problem acknowledgement, Flapping started, Flapping stopped, Downtime started , Downtime ended, Downtime removed, Custom)

The Time Range selected (i.e. 6 hours) is used to filter the output.

# Dashboard Example
You can find an example [here](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FOcWYNyWnk%2Fstate-and-notification-history%3ForgId%3D3).

This dashboard requires NetEye 4.48 or newer: monitoring data are read from IcingaDB, since the Icinga IDO database is no longer available.
Before importing this dashboard, ensure the following requirements are met. If not, please make the required changes accordingly.

## Grafana Datasources

The dashboard reads monitoring data from the MySQL datasource `icingadb-mysql` (database `icingadb`). The datasource is created automatically in the Main Org by the `nep-common` setup (`setup_scripts/pre/09_create_grafana_datasources.sh`), so no manual MySQL user or datasource creation is needed.

Datasources are referenced by name, so the dashboard works without changes on any NetEye installation where they exist.

## How to import dashboard

# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
