# Overview

This dashboard shows, for one printer at a time, the data collected by the services of the Service Set
`nx-ss-network-printer`.

## Dashboard Output

Choose the printer with the `Printer` variable at the top of the dashboard.

* Header: printer name and address (NetEye Host), model and serial number (service `Printer Info`), and a link that
  opens the Host in NetEye
* Overview: total pages (exact number), pages printed in the selected period, uptime, active problems
* Page counters: pages per day, all page counters of the printer (HP and Lexmark add color, mono, duplex, copy,
  fax, ... counters), page counters over time
* Supplies: current level of toner, drum, waste containers, ... and their history
* Problems history: problems reported by the printer (service `Printer Status`) over time

## Requirements

* Grafana datasource `icinga2-influxdb` (it can be changed with the `Datasource` variable)
* Grafana datasource `icingadb-mysql` for the header (it can be changed with the `IcingaDB` variable), created by
  nep-common on NetEye 4.50 and newer
* Pages per day are computed on UTC days
* Supplies which report no percentage (e.g. toner of some Brother printers) are not shown: their problems are
  reported by the service `Printer Status`

## How to import dashboard

The dashboard is imported automatically during the installation or update of the NEP.
To import it manually, import the JSON file provided.
For more info about importing Dashboards into Grafana, please refer to the
[official documentation](https://grafana.com/docs/grafana/latest/dashboards/export-import/#import-dashboard).
