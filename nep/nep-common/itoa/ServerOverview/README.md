# Overview
This dashboard helps you to show better basic perfomance and probles of agent-based monitored objects.

# Dashboard Output
The dashabord will show you a status, actual problems, used disk space, cpu load, memory used for a filtered group of hosts

# Dashboard Example
You can find an example [here](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FgwlEnKgWk%2Fserver-overview%3ForgId%3D3).

<<<<<<< HEAD
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

## Grafana Datasource creation
From ITOA – Data Sources menu create a new MySQL datasource named **icinga-mysql** (if not exists)
```
Host: mariadb.neteyelocal
Database: icinga
User: grafanareadonly
Password: XXXXXXXX
```

**Save&Test**

## Grafana Variable definition
From Dashboard - Settings - Variables (hostname) correct the needed filter in the WHERE clause.
```
...
WHERE icinga_hostgroups.alias like 'windows%';
=======
This dashboard requires NetEye 4.48 or newer: monitoring data are read from IcingaDB, since the Icinga IDO database is no longer available.
Before importing this dashboard, ensure the following requirements are met. If not, please make the required changes accordingly.

## Grafana Datasources

The dashboard reads monitoring data from the MySQL datasource `icingadb-mysql` (database `icingadb`). The datasource is created automatically in the Main Org by the `nep-common` setup (`setup_scripts/pre/09_create_grafana_datasources.sh`), so no manual MySQL user or datasource creation is needed.

The InfluxDB datasource `icinga2-influxdb` is also required for the performance panels.

Datasources are referenced by name, so the dashboard works without changes on any NetEye installation where they exist.

## Grafana Variable definition

The `hostgroup` variable lists the host groups whose display name contains `Windows` and that have at least one member; the `hostname` (Node) variable lists the hosts of the selected group. To use different host groups, adjust the `WHERE` clause of the `hostgroup` variable from Dashboard - Settings - Variables.

``` sql
SELECT g.display_name AS __text, g.name AS __value FROM hostgroup g
WHERE g.display_name LIKE '%Windows%'
  AND EXISTS (SELECT 1 FROM hostgroup_member m WHERE m.hostgroup_id = g.id)
ORDER BY g.display_name
>>>>>>> 3441837 (fix(NEP-962): migrate ITOA dashboards from Icinga IDO to IcingaDB (#114))
```


# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
