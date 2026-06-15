# Overview
This dashboard helps you (IT operation user) to see and filter the NetEye Event Overview from a Grafana Dashboard using quick filters and Time Range selection.

# Dashboard Output
The dashboard will show you a table with those filters:

- state (Host UP,DOWN,N/A Service OK,WARNING,CRITICAL,UNKNOWN,N/A)
- state type (Hard,Soft)
The Time Range selected (i.e. 6 hours) is used to limit the events in the history.

# Dashboard Example
You can find an example <a href="https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FSbohawWnkO%2Flast-state-history-with-filters%3ForgId%3D3%26refresh%3D1m" target="_blank">here</a>.


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

## Datasource creation
From ITOA - Data Sources menu create a new MySQL datasource named **icinga-mysql** (if not exists)

```
Host: mariadb.neteyelocal
Database: icinga
User: grafanareadonly
Password: XXXXXXXX
```

**Save&Test**

## Variable definition
From Dashboard - Settings - Variables (neteye_hostname) define the correct FQDN of your NetEye System (removing neteyedemo.wuerth-phoenix.com)

# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
