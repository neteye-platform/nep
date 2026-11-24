# Overview

This dashboard helps you (IT operation user) to see and filter the NetEye Event
Overview from a Grafana Dashboard using quick filters and Time Range selection.

## Dashboard Output

The dashboard will show you a table with those filters:

- state (Host UP,DOWN,N/A Service OK,WARNING,CRITICAL,UNKNOWN,N/A)
- state type (Hard,Soft)
The Time Range selected (i.e. 6 hours) is used to limit the events in the history.

## Dashboard Example

You can find an example on the [NetEye Demo](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FSbohawWnkO%2Flast-state-history-with-filters%3ForgId%3D3%26refresh%3D1m)

## Requirements

This dashboard requires NetEye 4.48 or newer: monitoring data are read from
IcingaDB, since the Icinga IDO database is no longer available.
Before importing this dashboard, ensure the following requirements are met. If
not, please make the required changes accordingly.

## Grafana Datasources

The dashboard reads monitoring data from the MySQL datasource `icingadb-mysql`
(database `icingadb`). The datasource is created automatically in the Main Org
by the `nep-common` setup
(`setup_scripts/pre/09_create_grafana_datasources.sh`), so no manual MySQL user
or datasource creation is needed.

Datasources are referenced by name, so the dashboard works without changes on
any NetEye installation where they exist.

## Variable definition

From Dashboard - Settings - Variables (neteye_hostname) define the correct FQDN
of your NetEye System (removing neteyedemo.wuerth-phoenix.com)

## How to import dashboard

To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the
[official
documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
