# Overview
This dashboard allows you to monitor existing problems on NetEye (both for hosts and for services).

# Dashboard Output
The dashboard will show you two different tables showing Hosts DOWN and Services WARNING/CRITICAL with those filters:
- problem handled (Handled/Not handled/All)
- service state (WARNING, CRITICAL, All)

# Dashboard Example
You can find an example [here](https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FXfwT78pMz1%2Fneteye-problems%3ForgId%3D3%26refresh%3D30s).

# Requirements
This Dashboard is compatible with Grafana 7.5.5 (released with NetEye 4.19) and newer.
Before importing this dashboard, ensure the following requirements are met. If not, please make the required changes accordingly.

# Warning
This dashboard does not take into account the user’s role and related permissions and it is intended for use by an administrator on an on-premise non multi-tenant installation of NetEye.

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
From Dashboard - Settings - Variables (neteye_hostname) define the correct FQDN of your NetEye System (removing neteyedemo.wuerth-phoenix.com)

## Time zone setup
If the column "Last state change" report only "null" value, it is needed to convert time to local timezone on mysql. You can find mysql documentation reference [here](https://dev.mysql.com/doc/refman/8.0/en/time-zone-support.html)
```
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql mysql
```

# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
