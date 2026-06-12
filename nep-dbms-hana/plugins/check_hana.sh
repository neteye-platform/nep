#!/bin/bash
#################################################################
####                                                            #
####  check_hana.sh                                             #
####                                                            #
####  Monitoring of HANA Database                               #
####                                                            #
####  Author:    Andreas Foerster                               #
####             (some scripts based on SAP-note 1960700)       #
####                                                            #
####  Prereq.: HANA Client installed in ${HDBCLIENT}            #
####                                                            #
####  History:                                                  #
####    14.06.2021    1.00  initial version                     #
####    21.02.2023    1.10  function "last_backup" added        #
####    18.12.2023    1.20  function "failed_data_backup" added #
####    04/11/2024    1.30  function "used_space" added POAL    #
####	  11/11/2024    1.40  function "missing index" added POAL #
####    24/04/2026    1.50  fix remove temp file in crash case  #
####                                                            #
#################################################################
####
####  *** set variables here ****************************************************************************************
####
set -a                                          # Auto-export all variables
#
####
#### installation directory of SAP HANA Client:
HDBCLIENT=/neteye/shared/monitoring/plugins/sap/hana/hdbclient
####
#### path to standard monitoring plugins:
PLUGIN_DIR=/usr/lib64/neteye/monitoring/plugins
####
####  *** don't change anything beyond this line ***
####
######################################################################################################################
# set shell-option to make sure, that "read" from a pipe is working
shopt -s lastpipe
#
PATH=$PATH:/bin:/usr/bin
TMP_DIR="/tmp"
#
HDBSQL=${HDBCLIENT}/hdbsql
#
PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1.00 $' | sed -e 's/[^0-9.]//g'`
#
INFILE="${TMP_DIR}/infile_`basename $0`_${HANA_SID}.$$"
TMPFILE="${TMP_DIR}/tmpfile_`basename $0`_${HANA_SID}.$$"
#

cleanup() {
    rm -f "$INFILE" "$TMPFILE"
}
trap cleanup EXIT INT TERM

# source monitoring-plugins-utilities
. $PLUGIN_DIR/utils.sh


print_usage() {
  echo "Usage:"
  echo "  $PROGNAME --function connection_time  --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD> --crit <CRITICAL seconds> --warn <WARNING seconds>"
  echo "  $PROGNAME --function failed_log_backups --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD> --crit <failed backups CRITICAL> --warn <failed backups WARNING> --lookback <minutes>"
  echo "  $PROGNAME --function failed_data_backups --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD> --crit <failed backups CRITICAL> --warn <failed backups WARNING> --lookback <hours>"
  echo "  $PROGNAME --function last_backup --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD> --crit <duration in minutes CRITICAL> --warn <duration in minutes WARNING> --lookback <days>"
  echo "  $PROGNAME --function memory_usage --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD> --crit <memory free % CRITICAL> --warn <memory free % WARNING>"
  echo "  $PROGNAME --function replication_status --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD>"
  echo "  $PROGNAME --function used_space --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD>"
  echo "  $PROGNAME --function missing_index --sid <SID> --host <HOST> --port <PORT> --user <USER> --pass <PASSWORD>"
  echo "  $PROGNAME --help"
  echo "  $PROGNAME --version"
}

print_help() {
  echo ""
  print_usage
  echo ""
  echo "Check HANA status"
  echo ""
  echo "--function connection_time"
  echo "   Attempt a dummy login and alert if login is not possible"
  echo "--help"
  echo "   Print this help screen"
  echo "--version"
  echo "   Print version and license information"
  echo ""
  echo ""
}


##############################
#
# evaluate options
#
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --help)      HANA_FUNCTION="help";;
    --version)   HANA_FUNCTION="version";;
    --function)  HANA_FUNCTION="$2"; shift;;
    --lookback)  HANA_LOOKBACK="$2"; shift;;
    --sid)       HANA_SID="$2";      shift;;
    --host)      HANA_HOST="$2";     shift;;
    --port)      HANA_PORT="$2";     shift;;
    --user)      HANA_USER="$2";     shift;;
    --pass)      HANA_PASS="$2";     shift;;
    --warn)      HANA_WARN=$2;       shift;;
    --crit)      HANA_CRIT=$2;       shift;;
    *)          echo "UNKNOWN: Parameter not valid: $1"; exit 3;;
  esac
  shift
done


# Information options
case "$HANA_FUNCTION" in
help)
                print_help
    exit $STATE_OK
    ;;
version)
                echo $REVISION
    exit $STATE_OK
    ;;
esac

#
# function get_connection_time
#
get_connection_time ()
{
  cat >>$INFILE <<@EOF
select * from M_DATABASE;
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE
  RET=$?
  rm -f $INFILE $TMPFILE
  return $RET
}

#
# function check_log_backup
#
check_log_backup ()
{
  cat >>$INFILE <<@EOF
select backup_id, sys_start_time, state_name from m_backup_catalog where entry_type_name='log backup' and sys_end_time >= add_seconds (current_timestamp, -${HANA_LOOKBACK}*60) and not state_name in ('successful', 'running');
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE
  RET=$?
  rm -f $INFILE
  return $RET
}

#
# function check_failed_data_backup
#
check_failed_data_backup ()
{
  cat >>$INFILE <<@EOF
select backup_id, sys_start_time, state_name from m_backup_catalog where entry_type_name='data backup' and sys_end_time >= add_seconds (current_timestamp, -${HANA_LOOKBACK}*60*60) and not state_name in ('successful', 'running');
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE
  RET=$?
  rm -f $INFILE
  return $RET
}

#
# function check_backup
#
check_backup ()
{
  cat >>$INFILE <<@EOF
SELECT
  START_TIME,
  HOST,
  SERVICE_NAME,
  LPAD(BACKUP_ID, 13) BACKUP_ID,
  BACKUP_TYPE,
  DATA_TYPE,
  STATUS,
  LPAD(BACKUPS, 7) BACKUPS,
  LPAD(TO_DECIMAL(MAP(BACKUPS, 0, 0, NUM_LOG_FULL / BACKUPS * 100), 10, 2), 12) FULL_LOG_PCT,
  AGG,
  IFNULL(LPAD(TO_DECIMAL(RUNTIME_H * 60, 10, 2), 11), '') RUNTIME_MIN,
  LPAD(TO_DECIMAL(BACKUP_SIZE_MB, 10, 2), 14) BACKUP_SIZE_MB,
  IFNULL(LPAD(TO_DECIMAL(MAP(RUNTIME_H, 0, 0, BACKUP_SIZE_MB / RUNTIME_H / 3600), 10, 2), 8), '') MB_PER_S,
  LPAD(TO_DECIMAL(SECONDS_BETWEEN(MAX_START_TIME, CURRENT_TIMESTAMP) / 86400, 10, 2), 11) DAYS_PASSED,
  MESSAGE
FROM
( SELECT
    START_TIME,
    HOST,
    SERVICE_NAME,
    BACKUP_ID,
    BACKUP_TYPE,
    BACKUP_DATA_TYPE DATA_TYPE,
    STATUS,
    NUM_BACKUP_RUNS BACKUPS,
    NUM_LOG_FULL,
    AGGREGATION_TYPE AGG,
    CASE AGGREGATION_TYPE
      WHEN 'SUM' THEN SUM_RUNTIME_H
      WHEN 'AVG' THEN MAP(NUM_BACKUP_RUNS, 0, 0, SUM_RUNTIME_H / NUM_BACKUP_RUNS)
      WHEN 'MAX' THEN MAX_RUNTIME_H
    END RUNTIME_H,
    CASE AGGREGATION_TYPE
      WHEN 'SUM' THEN SUM_BACKUP_SIZE_MB
      WHEN 'AVG' THEN MAP(NUM_BACKUP_RUNS, 0, 0, SUM_BACKUP_SIZE_MB / NUM_BACKUP_RUNS)
      WHEN 'MAX' THEN MAX_BACKUP_SIZE_MB
    END BACKUP_SIZE_MB,
    MAX_START_TIME,
    MESSAGE,
    ORDER_BY
  FROM
  ( SELECT
      CASE
        WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'TIME') != 0 THEN
          CASE
            WHEN BI.TIME_AGGREGATE_BY LIKE 'TS%' THEN
              TO_VARCHAR(ADD_SECONDS(TO_TIMESTAMP('2014/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS'), FLOOR(SECONDS_BETWEEN(TO_TIMESTAMP('2014/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS'),
              CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(B.SYS_START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE B.SYS_START_TIME END) / SUBSTR(BI.TIME_AGGREGATE_BY, 3)) * SUBSTR(BI.TIME_AGGREGATE_BY, 3)), 'YYYY/MM/DD HH24:MI:SS')
            ELSE TO_VARCHAR(CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(B.SYS_START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE B.SYS_START_TIME END, BI.TIME_AGGREGATE_BY)
          END
        ELSE 'any'
      END START_TIME,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'HOST')             != 0 THEN BF.HOST                                         ELSE MAP(BI.HOST, '%', 'any', BI.HOST)                         END HOST,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'SERVICE')          != 0 THEN BF.SERVICE_TYPE_NAME                            ELSE MAP(BI.SERVICE_NAME, '%', 'any', BI.SERVICE_NAME)         END SERVICE_NAME,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BACKUP_ID')        != 0 THEN TO_VARCHAR(B.BACKUP_ID)                         ELSE 'any'                                                     END BACKUP_ID,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BACKUP_TYPE')      != 0 THEN B.ENTRY_TYPE_NAME                               ELSE MAP(BI.BACKUP_TYPE, '%', 'any', BI.BACKUP_TYPE)           END BACKUP_TYPE,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BACKUP_DATA_TYPE') != 0 THEN BF.SOURCE_TYPE_NAME                             ELSE MAP(BI.BACKUP_DATA_TYPE, '%', 'any', BI.BACKUP_DATA_TYPE) END BACKUP_DATA_TYPE,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'STATE')            != 0 THEN B.STATE_NAME                                    ELSE MAP(BI.BACKUP_STATUS, '%', 'any', BI.BACKUP_STATUS)       END STATUS,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'MESSAGE')          != 0 THEN CASE WHEN B.MESSAGE LIKE 'Not all data could be written%' THEN 'Not all data could be written'
        ELSE B.MESSAGE END ELSE MAP(BI.MESSAGE, '%', 'any', BI.MESSAGE) END MESSAGE,
      COUNT(DISTINCT(B.BACKUP_ID)) NUM_BACKUP_RUNS,
      SUM(SECONDS_BETWEEN(B.SYS_START_TIME, B.SYS_END_TIME) / 3600) * SUM(BF.BACKUP_SIZE) / SUM(BF.TOTAL_BACKUP_SIZE) SUM_RUNTIME_H,
      MAX(SECONDS_BETWEEN(B.SYS_START_TIME, B.SYS_END_TIME) / 3600) * MAX(BF.BACKUP_SIZE / BF.TOTAL_BACKUP_SIZE) MAX_RUNTIME_H,
      IFNULL(SUM(BF.BACKUP_SIZE / 1024 / 1024 ), 0) SUM_BACKUP_SIZE_MB,
      IFNULL(MAX(BF.BACKUP_SIZE / 1024 / 1024 ), 0) MAX_BACKUP_SIZE_MB,
      MAX(CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(B.SYS_START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE B.SYS_START_TIME END) MAX_START_TIME,
      SUM(IFNULL(CASE WHEN B.ENTRY_TYPE_NAME = 'log backup' AND BF.SOURCE_TYPE_NAME = 'volume' AND BF.BACKUP_SIZE / 1024 / 1024 >= L.SEGMENT_SIZE * 0.95 THEN 1 ELSE 0 END, 0)) NUM_LOG_FULL,
      BI.MIN_BACKUP_TIME_S,
      BI.AGGREGATION_TYPE,
      BI.AGGREGATE_BY,
      BI.ORDER_BY
    FROM
    ( SELECT
        CASE
          WHEN BEGIN_TIME =    'C'                             THEN CURRENT_TIMESTAMP
          WHEN BEGIN_TIME LIKE 'C-S%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-S'))
          WHEN BEGIN_TIME LIKE 'C-M%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-M') * 60)
          WHEN BEGIN_TIME LIKE 'C-H%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-H') * 3600)
          WHEN BEGIN_TIME LIKE 'C-D%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-D') * 86400)
          WHEN BEGIN_TIME LIKE 'C-W%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(BEGIN_TIME, 'C-W') * 86400 * 7)
          WHEN BEGIN_TIME LIKE 'E-S%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-S'))
          WHEN BEGIN_TIME LIKE 'E-M%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-M') * 60)
          WHEN BEGIN_TIME LIKE 'E-H%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-H') * 3600)
          WHEN BEGIN_TIME LIKE 'E-D%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-D') * 86400)
          WHEN BEGIN_TIME LIKE 'E-W%'                          THEN ADD_SECONDS(TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS'), -SUBSTR_AFTER(BEGIN_TIME, 'E-W') * 86400 * 7)
          WHEN BEGIN_TIME =    'MIN'                           THEN TO_TIMESTAMP('1000/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS')
          WHEN SUBSTR(BEGIN_TIME, 1, 1) NOT IN ('C', 'E', 'M') THEN TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS')
        END BEGIN_TIME,
        CASE
          WHEN END_TIME =    'C'                             THEN CURRENT_TIMESTAMP
          WHEN END_TIME LIKE 'C-S%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-S'))
          WHEN END_TIME LIKE 'C-M%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-M') * 60)
          WHEN END_TIME LIKE 'C-H%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-H') * 3600)
          WHEN END_TIME LIKE 'C-D%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-D') * 86400)
          WHEN END_TIME LIKE 'C-W%'                          THEN ADD_SECONDS(CURRENT_TIMESTAMP, -SUBSTR_AFTER(END_TIME, 'C-W') * 86400 * 7)
          WHEN END_TIME LIKE 'B+S%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+S'))
          WHEN END_TIME LIKE 'B+M%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+M') * 60)
          WHEN END_TIME LIKE 'B+H%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+H') * 3600)
          WHEN END_TIME LIKE 'B+D%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+D') * 86400)
          WHEN END_TIME LIKE 'B+W%'                          THEN ADD_SECONDS(TO_TIMESTAMP(BEGIN_TIME, 'YYYY/MM/DD HH24:MI:SS'), SUBSTR_AFTER(END_TIME, 'B+W') * 86400 * 7)
          WHEN END_TIME =    'MAX'                           THEN TO_TIMESTAMP('9999/12/31 00:00:00', 'YYYY/MM/DD HH24:MI:SS')
          WHEN SUBSTR(END_TIME, 1, 1) NOT IN ('C', 'B', 'M') THEN TO_TIMESTAMP(END_TIME, 'YYYY/MM/DD HH24:MI:SS')
        END END_TIME,
        TIMEZONE,
        HOST,
        SERVICE_NAME,
        BACKUP_TYPE,
        BACKUP_DATA_TYPE,
        BACKUP_STATUS,
        MESSAGE,
        MIN_BACKUP_TIME_S,
        AGGREGATION_TYPE,
        AGGREGATE_BY,
        ORDER_BY,
        MAP(TIME_AGGREGATE_BY,
          'NONE',        'YYYY/MM/DD HH24:MI:SS',
          'HOUR',        'YYYY/MM/DD HH24',
          'DAY',         'YYYY/MM/DD (DY)',
          'HOUR_OF_DAY', 'HH24',
          TIME_AGGREGATE_BY ) TIME_AGGREGATE_BY
      FROM
      ( SELECT                                                                  /* Modification section */
          'C-D${HANA_LOOKBACK}' BEGIN_TIME,                  /* YYYY/MM/DD HH24:MI:SS timestamp, C, C-S<seconds>, C-M<minutes>, C-H<hours>, C-D<days>, C-W<weeks>, E-S<seconds>, E-M<minutes>, E-H<hours>, E-D<days>, E-W<weeks>, MIN */
          '9999/10/18 08:05:00' END_TIME,                    /* YYYY/MM/DD HH24:MI:SS timestamp, C, C-S<seconds>, C-M<minutes>, C-H<hours>, C-D<days>, C-W<weeks>, B+S<seconds>, B+M<minutes>, B+H<hours>, B+D<days>, B+W<weeks>, MAX */
          'SERVER' TIMEZONE,                              /* SERVER, UTC */
          '%' HOST,
          '%' SERVICE_NAME,
          'complete data backup' BACKUP_TYPE,                             /* e.g. 'log backup', 'complete data backup', 'incremental data backup', 'differential data backup', 'data snapshot',
                                                                  'DATA_BACKUP' for all data backup and snapshot types */
          '%' BACKUP_DATA_TYPE,                            /* VOLUME -> log or data, CATALOG -> catalog, TOPOLOGY -> topology */
          'successful' BACKUP_STATUS,                                    /* e.g. 'successful', 'failed' */
          '%' MESSAGE,
          -1 MIN_BACKUP_TIME_S,
          'AVG' AGGREGATION_TYPE,     /* SUM, MAX, AVG */
          'TIME' AGGREGATE_BY,        /* HOST, SERVICE, TIME, BACKUP_ID, BACKUP_TYPE, BACKUP_DATA_TYPE, STATE, MESSAGE or comma separated list, NONE for no aggregation */
          'HOUR' TIME_AGGREGATE_BY,     /* HOUR, DAY, HOUR_OF_DAY or database time pattern, TS<seconds> for time slice, NONE for no aggregation */
          'TIME' ORDER_BY              /* COUNT, TIME */
        FROM
          DUMMY
      )
    ) BI INNER JOIN
      M_BACKUP_CATALOG B ON
        CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(B.SYS_START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE B.SYS_START_TIME END BETWEEN BI.BEGIN_TIME AND BI.END_TIME AND
        ( BI.BACKUP_TYPE = 'DATA_BACKUP' AND B.ENTRY_TYPE_NAME IN ( 'complete data backup', 'differential data backup', 'incremental data backup', 'data snapshot' ) OR
          BI.BACKUP_TYPE != 'DATA_BACKUP' AND UPPER(B.ENTRY_TYPE_NAME) LIKE UPPER(BI.BACKUP_TYPE)
        ) AND
        B.STATE_NAME LIKE BI.BACKUP_STATUS AND
        B.MESSAGE LIKE BI.MESSAGE LEFT OUTER JOIN
      ( SELECT
          BACKUP_ID,
          SOURCE_ID,
          HOST,
          SERVICE_TYPE_NAME,
          SOURCE_TYPE_NAME,
          BACKUP_SIZE,
          SUM(BACKUP_SIZE) OVER (PARTITION BY BACKUP_ID) TOTAL_BACKUP_SIZE
        FROM
          M_BACKUP_CATALOG_FILES
      ) BF ON
        B.BACKUP_ID = BF.BACKUP_ID LEFT OUTER JOIN
      M_LOG_BUFFERS L ON
        L.HOST = BF.HOST AND
        L.VOLUME_ID = BF.SOURCE_ID
      WHERE
        IFNULL(BF.HOST, '') LIKE BI.HOST AND
        IFNULL(BF.SERVICE_TYPE_NAME, '') LIKE BI.SERVICE_NAME AND
        IFNULL(UPPER(BF.SOURCE_TYPE_NAME), '') LIKE UPPER(BI.BACKUP_DATA_TYPE)
    GROUP BY
      CASE
        WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'TIME') != 0 THEN
          CASE
            WHEN BI.TIME_AGGREGATE_BY LIKE 'TS%' THEN
              TO_VARCHAR(ADD_SECONDS(TO_TIMESTAMP('2014/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS'), FLOOR(SECONDS_BETWEEN(TO_TIMESTAMP('2014/01/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS'),
              CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(B.SYS_START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE B.SYS_START_TIME END) / SUBSTR(BI.TIME_AGGREGATE_BY, 3)) * SUBSTR(BI.TIME_AGGREGATE_BY, 3)), 'YYYY/MM/DD HH24:MI:SS')
            ELSE TO_VARCHAR(CASE BI.TIMEZONE WHEN 'UTC' THEN ADD_SECONDS(B.SYS_START_TIME, SECONDS_BETWEEN(CURRENT_TIMESTAMP, CURRENT_UTCTIMESTAMP)) ELSE B.SYS_START_TIME END, BI.TIME_AGGREGATE_BY)
          END
        ELSE 'any'
      END,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'HOST')             != 0 THEN BF.HOST                                         ELSE MAP(BI.HOST, '%', 'any', BI.HOST)                         END,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'SERVICE')          != 0 THEN BF.SERVICE_TYPE_NAME                            ELSE MAP(BI.SERVICE_NAmE, '%', 'any', BI.SERVICE_NAME)         END,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BACKUP_ID')        != 0 THEN TO_VARCHAR(B.BACKUP_ID)                         ELSE 'any'                                                     END,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BACKUP_TYPE')      != 0 THEN B.ENTRY_TYPE_NAME                               ELSE MAP(BI.BACKUP_TYPE, '%', 'any', BI.BACKUP_TYPE)           END,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'BACKUP_DATA_TYPE') != 0 THEN BF.SOURCE_TYPE_NAME                             ELSE MAP(BI.BACKUP_DATA_TYPE, '%', 'any', BI.BACKUP_DATA_TYPE) END,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'STATE')            != 0 THEN B.STATE_NAME                                    ELSE MAP(BI.BACKUP_STATUS, '%', 'any', BI.BACKUP_STATUS)       END,
      CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'MESSAGE')          != 0 THEN CASE WHEN B.MESSAGE LIKE 'Not all data could be written%' THEN 'Not all data could be written' ELSE B.MESSAGE END
        ELSE MAP(BI.MESSAGE, '%', 'any', BI.MESSAGE) END,
      BI.MIN_BACKUP_TIME_S,
      BI.AGGREGATION_TYPE,
      BI.AGGREGATE_BY,
      BI.ORDER_BY
  )
  WHERE
  ( MIN_BACKUP_TIME_S = -1 OR SUM_RUNTIME_H >= MIN_BACKUP_TIME_S / 3600 )
)
ORDER BY
  MAP(ORDER_BY, 'COUNT', BACKUPS) DESC,
  START_TIME DESC,
  HOST,
  SERVICE_NAME
WITH HINT (NO_JOIN_REMOVAL)
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE
  RET=$?
  rm -f $INFILE
  return $RET
}

#
# function check_memory_used
#
check_memory_used ()
{
  cat >>$INFILE <<@EOF
select value from m_system_overview where section='Memory';
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE
  RET=$?
  rm -f $INFILE
  return $RET
}

#
# check_replication_status
#
check_replication_status ()
{
  cat >>$INFILE <<@EOF
SELECT host, LPAD(port, 5) port, site_name, secondary_site_name, secondary_host, LPAD(secondary_port, 5) secondary_port, replication_mode, MAP(secondary_active_status, 'YES', 1,0) secondary_active_status, MAP(UPPER(replication_status),'ACTIVE',0,'ERROR', 4, 'SYNCING',2, 'INITIALIZING',1,'UNKNOWN', 3, 99) replication_status, TO_DECIMAL(SECONDS_BETWEEN(SHIPPED_LOG_POSITION_TIME, LAST_LOG_POSITION_TIME), 10, 2) ship_delay_s, TO_DECIMAL((LAST_LOG_POSITION - SHIPPED_LOG_POSITION) * 64 / 1024 / 1024, 10, 2) async_buff_used_mb, secondary_reconnect_count, secondary_failover_count FROM sys.m_service_replication;
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE -F ' ' -a
  RET=$?
  rm -f $INFILE
  return $RET
}

#
# check_used_space
#
check_used_space ()
{
  cat >>$INFILE <<@EOF
SELECT
    V.HOST,
    LPAD(V.PORT, 5) PORT,
    LPAD(TO_DECIMAL(TOTAL_ALLOC_GB, 10, 2), 10) ALLOC_GB,
    LPAD(TO_DECIMAL(TOTAL_USED_GB, 10, 2), 10) USED_GB,
    LPAD(TO_DECIMAL(IFNULL(COLTAB_GB, 0), 10, 2), 9) COLTAB_GB,
    LPAD(TO_DECIMAL((TOTAL_USED_GB / TOTAL_ALLOC_GB) * 100, 10, 2), 10) PERCENT_USED
FROM
( SELECT          /* Modification section */
    '%' HOST,
    '%' PORT,
    'USED' ORDER_BY   /* HOST, ALLOC, USED */
FROM
    DUMMY
) BI INNER JOIN
( SELECT
    HOST,
    PORT,
    SUM(TOTAL_SIZE) / 1024 / 1024 / 1024 TOTAL_ALLOC_GB,
    SUM(USED_SIZE) / 1024 / 1024 / 1024 TOTAL_USED_GB
FROM
    M_VOLUME_FILES
WHERE
    FILE_TYPE = 'DATA'
GROUP BY
    HOST,
    PORT
) V ON
    V.HOST LIKE BI.HOST AND
    TO_VARCHAR(V.PORT) LIKE BI.PORT LEFT OUTER JOIN
( SELECT
    HOST,
    PORT,
    SUM(PHYSICAL_SIZE) / 1024 / 1024 / 1024 COLTAB_GB
FROM
    M_TABLE_VIRTUAL_FILES
GROUP BY
    HOST,
    PORT
) RCT ON
    RCT.HOST = V.HOST AND
    RCT.PORT = V.PORT
ORDER BY
    MAP(BI.ORDER_BY, 'HOST', V.HOST || V.PORT),
    MAP(BI.ORDER_BY, 'ALLOC', V.TOTAL_ALLOC_GB, 'USED', V.TOTAL_USED_GB) DESC
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE -F ' ' -a
  RET=$?
  rm -f $INFILE
  return $RET
}

#
# function check_missing_index
#
check_missing_index ()
{
  cat >>$INFILE <<@EOF
SELECT
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'SCHEMA')    != 0 THEN IC.SCHEMA_NAME     ELSE MAP(BI.SCHEMA_NAME, '%', 'any', BI.SCHEMA_NAME)           END SCHEMA_NAME,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'TABLE')     != 0 THEN IC.TABLE_NAME || MAP(BI.OBJECT_LEVEL, 'TABLE', '', MAP(C.PART_ID, 0, '', CHAR(32) || '(' || C.PART_ID || ')'))
      ELSE MAP(BI.TABLE_NAME, '%', 'any', BI.TABLE_NAME) END TABLE_NAME,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'INDEX')     != 0 THEN IC.INDEX_NAME      ELSE MAP(BI.INDEX_NAME, '%', 'any', BI.INDEX_NAME)             END INDEX_NAME,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'COLUMN')    != 0 THEN IC.COLUMN_NAME     ELSE MAP(BI.COLUMN_NAME, '%', 'any', BI.COLUMN_NAME)           END COLUMN_NAME,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'COMP_TYPE') != 0 THEN C.COMPRESSION_TYPE ELSE MAP(BI.COMPRESSION_TYPE, '%', 'any', BI.COMPRESSION_TYPE) END COMPRESSION_TYPE,
  LPAD(TO_DECIMAL(AVG(C.COUNT), 10, 0), 11) NUM_ROWS,
  TO_VARCHAR(COUNT(*)) C,
  CASE
    WHEN BI.AGGREGATE_BY != 'NONE' AND ( INSTR(BI.AGGREGATE_BY, 'SCHEMA') = 0 OR INSTR(BI.AGGREGATE_BY, 'TABLE') = 0 OR INSTR(BI.AGGREGATE_BY, 'COMMAND') = 0 ) THEN 'any'
    WHEN C.INDEX_TYPE = 'NONE' THEN '-- individual actions like recreation of primary / unique index'
    ELSE 'UPDATE' || CHAR(32) || '"' || IC.SCHEMA_NAME || '"."' || IC.TABLE_NAME || '" WITH PARAMETERS (' || CHAR (39) || 'OPTIMIZE_COMPRESSION' || CHAR(39) || '=' ||
      CHAR(39) || 'FORCE' || CHAR(39) || ');'
  END IMPLEMENTATION_COMMAND
FROM
( SELECT                   /* Modification section */
    '%' SCHEMA_NAME,
    '%' TABLE_NAME,
    '%' INDEX_NAME,
    '%' COLUMN_NAME,
    '%' COMPRESSION_TYPE,
    'TABLE' OBJECT_LEVEL,             /* TABLE, PARTITION */
    100000 MIN_RECORD_COUNT,
    'SCHEMA, TABLE, COMMAND' AGGREGATE_BY                       /* SCHEMA, TABLE, INDEX, COLUMN, COMP_TYPE, COMMAND or comma separated combinations, NONE for no aggregation */
  FROM
    DUMMY
) BI,
( SELECT
    SCHEMA_NAME,
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    CONSTRAINT
  FROM
  ( SELECT
      SCHEMA_NAME,
      TABLE_NAME,
      INDEX_NAME,
      COLUMN_NAME,
      CONSTRAINT,
      COUNT(*) OVER (PARTITION BY SCHEMA_NAME, TABLE_NAME, INDEX_NAME) NUM_COLUMNS
    FROM
      INDEX_COLUMNS
  )
  WHERE
    NUM_COLUMNS = 1 OR ( CONSTRAINT IN ('PRIMARY KEY', 'UNIQUE', 'NOT NULL UNIQUE' ) )
) IC,
( SELECT
    SCHEMA_NAME,
    TABLE_NAME,
    PART_ID,
    COLUMN_NAME,
    COMPRESSION_TYPE,
    COUNT,
    INDEX_TYPE,
    LOADED
  FROM
    M_CS_COLUMNS
) C,
( SELECT
    SUBSTR(VALUE, 1, LOCATE(VALUE, '.', 1, 2) - 1) VERSION,
    TO_NUMBER(SUBSTR(VALUE, LOCATE(VALUE, '.', 1, 2) + 1, LOCATE(VALUE, '.', 1, 3) - LOCATE(VALUE, '.', 1, 2) - 1) ||
    MAP(LOCATE(VALUE, '.', 1, 4), 0, '', '.' || SUBSTR(VALUE, LOCATE(VALUE, '.', 1, 3) + 1, LOCATE(VALUE, '.', 1, 4) - LOCATE(VALUE, '.', 1, 3) - 1 ))) REVISION
  FROM
    M_SYSTEM_OVERVIEW
  WHERE
    SECTION = 'System' AND
    NAME = 'Version'
) R
WHERE
  IC.SCHEMA_NAME LIKE BI.SCHEMA_NAME AND
  IC.TABLE_NAME LIKE BI.TABLE_NAME AND
  IC.INDEX_NAME LIKE BI.INDEX_NAME AND
  IC.COLUMN_NAME LIKE BI.COLUMN_NAME AND
  IC.SCHEMA_NAME = C.SCHEMA_NAME AND
  IC.TABLE_NAME = C.TABLE_NAME AND
  IC.COLUMN_NAME = C.COLUMN_NAME AND
  C.COMPRESSION_TYPE LIKE BI.COMPRESSION_TYPE AND
  ( BI.MIN_RECORD_COUNT = -1 OR C.COUNT >= BI.MIN_RECORD_COUNT ) AND
  ( C.LOADED = 'TRUE' AND C.INDEX_TYPE = 'NONE' OR
    C.COMPRESSION_TYPE = 'PREFIXED' OR
    C.COMPRESSION_TYPE = 'SPARSE' AND R.VERSION = '1.00' AND TO_NUMBER(R.REVISION) <= 122.02
  )  AND NOT EXISTS
  ( SELECT
      *
    FROM
      INDEXES IR,
      INDEX_COLUMNS ICR
    WHERE
      IR.SCHEMA_NAME = ICR.SCHEMA_NAME AND
      IR.TABLE_NAME = ICR.TABLE_NAME AND
      IR.INDEX_NAME = ICR.INDEX_NAME AND
      IR.INDEX_TYPE LIKE 'FULLTEXT%' AND
      C.SCHEMA_NAME = ICR.SCHEMA_NAME AND
      C.TABLE_NAME = ICR.TABLE_NAME AND
      C.COLUMN_NAME = ICR.COLUMN_NAME
  )
GROUP BY
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'SCHEMA')    != 0 THEN IC.SCHEMA_NAME     ELSE MAP(BI.SCHEMA_NAME, '%', 'any', BI.SCHEMA_NAME)           END,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'TABLE')     != 0 THEN IC.TABLE_NAME || MAP(BI.OBJECT_LEVEL, 'TABLE', '', MAP(C.PART_ID, 0, '', CHAR(32) || '(' || C.PART_ID || ')'))
      ELSE MAP(BI.TABLE_NAME, '%', 'any', BI.TABLE_NAME) END,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'INDEX')     != 0 THEN IC.INDEX_NAME      ELSE MAP(BI.INDEX_NAME, '%', 'any', BI.INDEX_NAME)             END,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'COLUMN')    != 0 THEN IC.COLUMN_NAME     ELSE MAP(BI.COLUMN_NAME, '%', 'any', BI.COLUMN_NAME)           END,
  CASE WHEN BI.AGGREGATE_BY = 'NONE' OR INSTR(BI.AGGREGATE_BY, 'COMP_TYPE') != 0 THEN C.COMPRESSION_TYPE ELSE MAP(BI.COMPRESSION_TYPE, '%', 'any', BI.COMPRESSION_TYPE) END,
  CASE
    WHEN BI.AGGREGATE_BY != 'NONE' AND ( INSTR(BI.AGGREGATE_BY, 'SCHEMA') = 0 OR INSTR(BI.AGGREGATE_BY, 'TABLE') = 0 OR INSTR(BI.AGGREGATE_BY, 'COMMAND') = 0 ) THEN 'any'
    WHEN C.INDEX_TYPE = 'NONE' THEN '-- individual actions like recreation of primary / unique index'
    ELSE 'UPDATE' || CHAR(32) || '"' || IC.SCHEMA_NAME || '"."' || IC.TABLE_NAME || '" WITH PARAMETERS (' || CHAR (39) || 'OPTIMIZE_COMPRESSION' || CHAR(39) || '=' ||
      CHAR(39) || 'FORCE' || CHAR(39) || ');'
  END
ORDER BY
  SUM(C.COUNT) DESC;
@EOF
  ${HDBSQL} -n ${HANA_HOST}:${HANA_PORT} -u ${HANA_USER} -p ${HANA_PASS} -I $INFILE -o $TMPFILE -F ' ' -a
  RET=$?
  rm -f $INFILE
  return $RET
}

umask 027
LC_ALL=en_US.UTF-8
LANG=en_US.UTF-8
#
# sourcing of HANA-Client-environment
#
if [ -z "$HDBCLIENT" -o ! -d "$HDBCLIENT" ] ; then
        echo "HANA Client dir $HDBCLIENT not found"
        exit $STATE_UNKNOWN
fi

if [ ! -x $HDBCLIENT/hdbclienv.sh ]; then
        echo "HANA environment $HDBCLIENT/hdbclienv.sh not found or not executable"
        exit $STATE_UNKNOWN
else
    . $HDBCLIENT/hdbclienv.sh >/dev/null 2>&1
fi

case "$HANA_FUNCTION" in
connection_time)
    start=$(date +%s.%N)
    get_connection_time
    sqlret=$?
    end=$(date +%s.%N)
    conn_time=$( echo "$end - $start" | bc -l )
    conn_time=$(printf "%1.2f" $conn_time)
    conn_time_int=$(echo $conn_time | cut -d '.' -f 1)

    if [ $sqlret -eq 0 ]; then
        [ -z $HANA_WARN ] && HANA_WARN=1
        [ -z $HANA_CRIT ] && HANA_CRIT=2
        ret_state=$STATE_OK
        [ $conn_time_int -ge $HANA_WARN ] && ret_state=$STATE_WARNING
        [ $conn_time_int -ge $HANA_CRIT ] && ret_state=$STATE_CRITICAL
        result_string="connected (${conn_time}s)"
        [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $result_string"
        [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $result_string"
        [ $ret_state -eq $STATE_OK ]       && result_string="OK - $result_string"
        PERF_OUT="|'connection-time'=$conn_time;$HANA_WARN;$HANA_CRIT;0;0"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;

last_backup)
    [ -z $HANA_LOOKBACK ] && HANA_LOOKBACK=3
    check_backup
    sqlret=$?
    if [ $sqlret -eq 0 ]; then
        last_backup=$(cat $TMPFILE | grep -v START_TIME | head -1)
        if [ -z "$last_backup" ]; then
            result_string="No successful data backup found in the last $HANA_LOOKBACK days"
            ret_state=$STATE_CRITICAL
        else
            # sample output:
            #"2023/02/20 19","any","any"," any","complete data backup","any","successful"," 1"," 0.00","AVG"," 41.98"," 129728.00"," 51.49"," 0.70","any"
            runtime=$(echo $last_backup | cut -d',' -f 11 | tr -d '[" ]')
            runtime_int=$(echo $runtime | cut -d'.' -f 1)
            [ -z $HANA_WARN ] && HANA_WARN=120
            [ -z $HANA_CRIT ] && HANA_CRIT=240
            [ $runtime_int -ge $HANA_WARN ] && ret_state=$STATE_WARNING
            [ $runtime_int -ge $HANA_CRIT ] && ret_state=$STATE_CRITICAL
            result_string="Last successful data backup of the past $HANA_LOOKBACK day(s) startet $(echo $last_backup | cut -d',' -f 14 | tr -d '[" ]') days ago (runtime: ${runtime}m)"
            PERF_OUT="|'runtime'=$runtime;$HANA_WARN;$HANA_CRIT;0;0"
            ret_state=$STATE_OK
        fi
        [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $result_string"
        [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $result_string"
        [ $ret_state -eq $STATE_OK ]       && result_string="OK - $result_string"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    rm -f $TMPFILE
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;

failed_log_backups)
    [ -z $HANA_LOOKBACK ] && HANA_LOOKBACK=120
    check_log_backup
    sqlret=$?
    if [ $sqlret -eq 0 ]; then
        num_errors=$(cat $TMPFILE |grep -v -i backup_id |wc -l)
        [ -z $HANA_WARN ] && HANA_WARN=1
        [ -z $HANA_CRIT ] && HANA_CRIT=1
        ret_state=$STATE_OK
        [ $num_errors -ge $HANA_CRIT ] && ret_state=$STATE_CRITICAL
        result_string="$num_errors log_backups failed during the last $HANA_LOOKBACK minutes"
        [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $result_string"
        [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $result_string"
        [ $ret_state -eq $STATE_OK ]       && result_string="OK - $result_string"
        [ $num_errors -gt 0 ] && cat $TMPFILE |grep -v -i backup_id
        PERF_OUT="|'log_backups_failed'=$num_errors;$HANA_WARN;$HANA_CRIT;0;0"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    rm -f $TMPFILE
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;

failed_data_backups)
    [ -z $HANA_LOOKBACK ] && HANA_LOOKBACK=24
    check_failed_data_backup
    sqlret=$?
    if [ $sqlret -eq 0 ]; then
        num_errors=$(cat $TMPFILE |grep -v -i backup_id |wc -l)
        [ -z $HANA_WARN ] && HANA_WARN=1
        [ -z $HANA_CRIT ] && HANA_CRIT=1
        ret_state=$STATE_OK
        [ $num_errors -ge $HANA_CRIT ] && ret_state=$STATE_CRITICAL
        result_string="$num_errors data_backups failed during the last $HANA_LOOKBACK hours"
        [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $result_string"
        [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $result_string"
        [ $ret_state -eq $STATE_OK ]       && result_string="OK - $result_string"
        [ $num_errors -gt 0 ] && cat $TMPFILE |grep -v -i backup_id
        PERF_OUT="|'data_backups_failed'=$num_errors;$HANA_WARN;$HANA_CRIT;0;0"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    #rm -f $TMPFILE
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;

memory_usage)
    check_memory_used
    sqlret=$?
    if [ $sqlret -eq 0 ]; then
        num_rows=$(cat $TMPFILE |grep -v -i section |wc -l)
        row=$(tail -1 $TMPFILE |tr -d '"')
        [ -z $HANA_WARN ] && HANA_WARN=15
        [ -z $HANA_CRIT ] && HANA_CRIT=10
        ret_state=$STATE_OK
        mem_physical=$(echo $row | cut -d',' -f 1 |awk '{print $2};')
        mem_unit=$(echo $row | cut -d',' -f 1 |awk '{print $3};')
        mem_used=$(echo $row | cut -d',' -f 3 |awk '{print $2};')
        mem_free=$(echo "$mem_physical-$mem_used" |bc -l |xargs printf "%0.2f")
        mem_free_pct=$(echo "$mem_free/$mem_physical*100" |bc -l |xargs printf "%0.0f")
        warn=$(echo "(100-$HANA_WARN)*$mem_physical/100" |bc -l|xargs printf "%0.2f")
        crit=$(echo "(100-$HANA_CRIT)*$mem_physical/100" |bc -l|xargs printf "%0.2f")
        result_string="${mem_used}$mem_unit of physical memory used"
        [ $mem_free_pct -lt $HANA_WARN ] && ret_state=$STATE_WARNING
        [ $mem_free_pct -lt $HANA_CRIT ] && ret_state=$STATE_CRITICAL
        [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $result_string"
        [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $result_string"
        [ $ret_state -eq $STATE_OK ]       && result_string="OK - $result_string"
        PERF_OUT="|'memory_usage'=$mem_used$mem_unit;$warn;$crit;0;$mem_physical"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    rm -f $TMPFILE
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;

replication_status)
    check_replication_status
    sqlret=$?
    if [ $sqlret -eq 0 ]; then
        num_rows=$(cat $TMPFILE |wc -l)
        # set default shipping delay (s)
        [ -z $HANA_WARN ] && HANA_WARN=10
        [ -z $HANA_CRIT ] && HANA_CRIT=20
        ret_state=$STATE_OK
        err_string="Replication Status Database $HANA_SID"
        result_string=""
        while read -r line
        do
            # examle-output:   "sap-db-p01","31043","sapH0Pnode1","sapH0Pnode2","sap-db-p02","31043","SYNCMEM",1,0,0.00,0.00,0,0
            echo $line | tr -d '"'| read -r HOST PORT SITE_NAME SECONDARY_SITE_NAME SECONDARY_HOST SECONDARY_PORT REPLICATION_MODE SECONDARY_ACTIVE_STATUS REPLICATION_STATUS SHIP_DELAY_S ASYNC_BUFF_USED_MB SECONDARY_RECONNECT_COUNT SECONDARY_FAILOVER_COUNT

            [ "$result_string" = "" ] && result_string="HOST PORT SITE_NAME SECONDARY_SITE_NAME SECONDARY_HOST SECONDARY_PORT REPLICATION_MODE SECONDARY_ACTIVE_STATUS REPLICATION_STATUS SHIP_DELAY_S ASYNC_BUFF_USED_MB SECONDARY_RECONNECT_COUNT SECONDARY_FAILOVER_COUNT\n"
            result_string="${result_string}${line}\n"

            if [ $(echo "$SHIP_DELAY_S > $HANA_WARN" |bc -l ) -ne 0 ]; then
                ret_state=$STATE_WARNING
                err_string="${err_string}, shipping-delay too high: ${HOST}:${PORT} ${SHIP_DELAY_S}"
                [ $(echo "$SHIP_DELAY_S > $HANA_CRIT" |bc -l) -ne 0 ] && ret_state=$STATE_CRITICAL
            fi
            if [ "$REPLICATION_MODE" != "SYNCMEM" ] && [ "$REPLICATION_MODE" != "ASYNC" ]; then
                ret_state=$STATE_CRITICAL
                err_string="${err_string}, Wrong Replication mode: ${HOST}:${PORT} ${REPLICATION_MODE}"
            fi
            if [ ${SECONDARY_ACTIVE_STATUS} -ne 1 ]; then
                ret_state=$STATE_CRITICAL
                err_string="${err_string}, Secondary host not active: ${HOST}:${PORT} $SECONDARY_SITE_NAME"
            fi
            [ "$perf_string" != "" ] && perf_string="${perf_string} "
            perf_string="${perf_string}'ship-delay-port-${PORT}'=${SHIP_DELAY_S}s;${HANA_WARN};${HANA_CRIT};0;0"
        done <$TMPFILE
        if [ $num_rows -eq 0 ]; then
            result_string="OK - (no replication configured for database $HANA_SID)"
        else
            [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $err_string\n$result_string"
            [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $err_string\n$result_string"
            [ $ret_state -eq $STATE_OK ]       && result_string="OK - $err_string\n$result_string"
        fi
        PERF_OUT="|$perf_string"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    rm -f $TMPFILE
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;


used_space)
    check_used_space
    sqlret=$?
    if [ $sqlret -eq 0 ]; then
        num_rows=$(cat $TMPFILE |wc -l)
        # set default shipping delay (s)
        [ -z $HANA_WARN ] && HANA_WARN=90
        [ -z $HANA_CRIT ] && HANA_CRIT=95
        ret_state=$STATE_OK
        err_string="Percent used space $HANA_SID"
        result_string=""
        while read -r line
        do
            # examle-output:   "lshdbprdfnt","32103","    753.93","    656.67","   209.15","     87.09%"
            echo $line | tr -d '"'| read -r HOST PORT ALLOC_GB USED_GB COLTAB_GB PERCENT_USED

            [ "$result_string" = "" ] && result_string="HOST PORT ALLOC_GB USED_GB COLTAB_GB PERCENT_USED\n"
            result_string="${result_string}${line}\n"

            if [ $(echo "$PERCENT_USED > $HANA_WARN" |bc -l ) -ne 0 ]; then
                ret_state=$STATE_WARNING
                err_string="${err_string}, percent_used too high: ${HOST}:${PORT} ${PERCENT_USED}"
                [ $(echo "$PERCENT_USED > $HANA_CRIT" |bc -l) -ne 0 ] && ret_state=$STATE_CRITICAL
            fi
            [ "$perf_string" != "" ] && perf_string="${perf_string} "
            perf_string="${perf_string}' ${HOST}:${PORT}'=${PERCENT_USED}%;${HANA_WARN};${HANA_CRIT};0;0"
        done <$TMPFILE
        if [ $num_rows -eq 0 ]; then
            result_string="OK - (no replication configured for database $HANA_SID)"
        else
            [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $err_string\n$result_string"
            [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $err_string\n$result_string"
            [ $ret_state -eq $STATE_OK ]       && result_string="OK - $err_string\n$result_string"
        fi
        PERF_OUT="|$perf_string"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    rm -f $TMPFILE
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;


missing_index)
    check_missing_index
    sqlret=$?
    if [ $sqlret -eq 0 ]; then
        num_rows=$(cat $TMPFILE |wc -l)
        # set default shipping delay (s)
        [ -z $HANA_WARN ] && HANA_WARN=1
        [ -z $HANA_CRIT ] && HANA_CRIT=2
        ret_state=$STATE_OK
        err_string="Index missing on $HANA_SID"
        result_string=""
        while read -r line
        do
            # examle-output:   "sap-db-p01","31043","sapH0Pnode1","sapH0Pnode2","sap-db-p02","31043","SYNCMEM",1,0,0.00,0.00,0,0
            echo $line | tr -d '"'| read -r SCHEMA_NAME TABLE_NAME INDEX_NAME COLUMN_NAME COMP_TYPE NUM_ROWS IMPLEMENTATION_COMMAND

            [ "$result_string" = "" ] && result_string="SCHEMA_NAME TABLE_NAME INDEX_NAME COLUMN_NAME COMP_TYPE NUM_ROWS IMPLEMENTATION_COMMAND\n"
            result_string="${result_string}${line}\n"

			if [ $num_rows > $HANA_WARN ]; then
                ret_state=$STATE_WARNING
                err_string="${err_string}, Index name: ${HOST}:${PORT} ${INDEX_NAME}"
                [ $num_rows > $HANA_CRIT ] && ret_state=$STATE_CRITICAL
            fi
            [ "$perf_string" != "" ] && perf_string="${perf_string} "
            perf_string="${perf_string}'schema-${SCHEMA_NAME},table-{TABLE_NAME}'=${INDEX_NAME}s;${HANA_WARN};${HANA_CRIT};0;0"
        done <$TMPFILE
        if [ $num_rows -eq 0 ]; then
            result_string="OK - no index missing for database $HANA_SID"
        else
            [ $ret_state -eq $STATE_CRITICAL ] && result_string="CRITICAL - $err_string\n$result_string"
            [ $ret_state -eq $STATE_WARNING ]  && result_string="WARNING - $err_string\n$result_string"
            [ $ret_state -eq $STATE_OK ]       && result_string="OK - $err_string\n$result_string"
        fi
        PERF_OUT="|$perf_string"
    else
        ret_state = $STATE_CRITICAL
        result_string="sql-statement failed"
    fi
    rm -f $TMPFILE
    echo "${result_string}${PERF_OUT}"
    exit $ret_state
    ;;

*)
    print_usage
                exit $STATE_UNKNOWN
esac