# Overview
This dashboard helps you to show better basic perfomance and probles of agent-based monitored objects.

# Dashboard Output
The dashabord will show you a status, actual problems, used disk space, cpu load, memory used for a filtered group of hosts

# Dashboard Example
You can find an example [here](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FgwlEnKgWk%2Fserver-overview%3ForgId%3D3).

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
```


# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
