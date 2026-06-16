#!/bin/bash

# CONFIGURAZIONE: Inserisci i tuoi parametri qui
TENANT_ID="AAA3"           # ID del tenant Azure AD
CLIENT_ID="AAA1"           # ID cliente della tua applicazione registrata
CLIENT_SECRET="AAA2"   # Segreto cliente generato per la tua applicazione

# Endpoint per ottenere il token
TOKEN_ENDPOINT="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token"

# Richiesta del token di accesso
echo "Richiesta del token di accesso..."
TOKEN_RESPONSE=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
-d "client_id=$CLIENT_ID" \
-d "client_secret=$CLIENT_SECRET" \
-d "scope=https://graph.microsoft.com/.default" \
-d "grant_type=client_credentials" \
$TOKEN_ENDPOINT)

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Errore: Impossibile ottenere il token di accesso."
  #echo "Risposta: $TOKEN_RESPONSE"
  exit 1
fi

echo "Token ottenuto con successo!"

# Ottenere tutti i team dell'organizzazione
echo "========================================"
echo "Recupero dei team nell'organizzazione..."
TEAMS_RESPONSE=$(curl -s -X GET -H "Authorization: Bearer $ACCESS_TOKEN" \
"https://graph.microsoft.com/v1.0/teams")

#echo "Risposta API per i team:"
#echo "$TEAMS_RESPONSE"

TEAM_IDS=$(echo "$TEAMS_RESPONSE" | jq -r '.value[] | "\(.displayName): \(.id)"')

if [ -z "$TEAM_IDS" ]; then
  echo "Errore: Nessun team trovato oppure mancano autorizzazioni."
  #echo "Risposta: $TEAMS_RESPONSE"
  exit 1
fi

echo "Team trovati:"
echo "$TEAM_IDS"
echo "========================================"

# Ottenere i canali per ciascun team
echo "Recupero dei canali per i team trovati..."
for TEAM_ID in $(echo "$TEAMS_RESPONSE" | jq -r '.value[].id'); do
  #echo "Richiesta dei canali per il team $TEAM_ID"
  CHANNELS_RESPONSE=$(curl -s -X GET -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://graph.microsoft.com/v1.0/teams/$TEAM_ID/channels")

  #echo "Risposta API per i canali del team $TEAM_ID:"
  #echo "$CHANNELS_RESPONSE"

  CHANNEL_IDS=$(echo "$CHANNELS_RESPONSE" | jq -r '.value[] | "\(.displayName): \(.id)"')

  if [ -n "$CHANNEL_IDS" ]; then
    echo "Canali per il team $TEAM_ID:"
    echo "$CHANNEL_IDS"
    echo "========================================"
  else
    echo "Nessun canale trovato per il team $TEAM_ID."
    echo "========================================"
  fi
done

