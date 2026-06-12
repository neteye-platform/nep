# Overview
This dashboard helps you (IT operation user) to see the status of the testcases that you want to control.

# Dashboard Output
The dashboard will show you a table with the filter on the server alyvix and testcases

The Time Range selected (i.e. 24 hours) is used to limit the events in the history.

# Dashboard Example
You can find an example <a href="https://neteyedemo.wuerth-phoenix.com/neteye/analytics/show?src=%2Fneteye%2Fanalytics%2Fgrafana%2Fd%2FCT3qf5oZz%2Falyvix-testcases%3ForgId%3D3" target="_blank">here</a>.


# Requirements
NetEye 4.18 or higher.

## Datasource creation
This dashboard used the standard Icinga2 datasource of NetEye

## Variable definition
From Dashboard - Settings - Variables (Host and Testcase) verify that are correcly populated.

# How to import dashboard
To create the ITOA Dashboard, import the JSON file provided.
For more info about importing Dashboards into Grafara, please refer to the [official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard.).
