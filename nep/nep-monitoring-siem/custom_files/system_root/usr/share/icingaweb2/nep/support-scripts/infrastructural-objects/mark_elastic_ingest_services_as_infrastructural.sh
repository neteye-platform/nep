#!/usr/bin/env bash

# Force script termination in case some command returns an error
set -euo pipefail

show_help() {
  cat <<EOF
Mark Elastic Ingest services as infrastructural in Icinga Director.

This script finds services with names matching "Elastic Ingest Status%"
that are not yet marked with nx_is_infrastructural and sets:
  nx_is_infrastructural = y

Usage:
  $0 [--help|-h]
  
EOF
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
esac

# Select Elastic Ingest services that are not yet marked as infrastructural.
QUERY="
SELECT h.object_name, s.object_name
FROM icinga_host h
INNER JOIN icinga_service s ON s.host_id = h.id
WHERE h.object_type = 'object'
  AND s.object_type = 'object'
  AND s.object_name LIKE 'Elastic Ingest Status%'
  AND s.id NOT IN (
    SELECT service_id
    FROM icinga_service_var
    WHERE varname = 'nx_is_infrastructural'
    ORDER BY 1
  )
ORDER BY 2,1;
"

# Output is tab-separated with headers; skip the header row before reading pairs.
mysql -D director -B -e "$QUERY" | tail -n +2 | \
while IFS=$'\t' read -r host service
do
  # Set the Director custom variable used to flag infrastructural services.
    echo "Updating service '$service' on host '$host'"
    icingacli director service set "$service" --host "$host" --vars.nx_is_infrastructural "y"
done
