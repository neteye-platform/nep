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

# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
