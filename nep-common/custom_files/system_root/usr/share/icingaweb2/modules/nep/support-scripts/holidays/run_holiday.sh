#!/bin/bash

cd "$(dirname "$0")"

python_script="/usr/share/icingaweb2/modules/nep/support-scripts/holidays/holidays4ne4.py"

python3.6 "$python_script"

if [[ $? -eq 0 ]]; then
  echo "$python_script Done!"
else
  echo "Error $python_script. Exit!"
  exit 1
fi