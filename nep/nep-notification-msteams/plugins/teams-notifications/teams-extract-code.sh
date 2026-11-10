#!/usr/bin/env bash

# Paste here the full url obtained after authorizing the app in the browser
REDIRECT_URL=""

# Extract the 'code' part, everything after 'code=' and before the '&'
AUTH_CODE="${REDIRECT_URL#*code=}"
AUTH_CODE="${AUTH_CODE%%&*}"

echo "My authorization code is: $AUTH_CODE"
