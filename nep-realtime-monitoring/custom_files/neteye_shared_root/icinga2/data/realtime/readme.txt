This is ax example configuration of a Telegraf getting data from a Linux server.
When configuring a Telegraf to send data for NetEye Real time Monitoring, ensure:
 - you use at least ALL the input plugins in this template
 - you send data to ad InfluxDB querable by NetEye
 - metrics are stored in measurements with the default name