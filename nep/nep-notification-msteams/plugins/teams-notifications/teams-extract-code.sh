#!/usr/bin/env bash

# Incollo qui l'URL completo che il browser restituisce
REDIRECT_URL=""

# Estrai la parte 'code' tutto ciò che sta dopo 'code=' e prima del '&'
AUTH_CODE="${REDIRECT_URL#*code=}"
AUTH_CODE="${AUTH_CODE%%&*}"

echo "Il mio authorization code è: $AUTH_CODE"
