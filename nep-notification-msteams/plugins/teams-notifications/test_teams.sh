#!/bin/bash

# Variabili di configurazione
CLIENT_ID="AAA1"                          # ID cliente della tua applicazione registrata
CLIENT_SECRET="AAA2"                  # Segreto cliente generato per la tua applicazione
TENANT_ID="AAA3"                          # ID del tenant Azure AD
REDIRECT_URI="http://localhost:8080"                                      # Redirect URI configurata lato Office 365
TEAM_ID="AAA4"                            # ID del team di Microsoft Teams
CHANNEL_ID="AAA5" # ID del canale di Microsoft Teams
MESSAGE="Messaggio inviato con app autentication"
AUTHORIZATION_CODE="AAA6"

# Endpoint Microsoft Graph
TOKEN_ENDPOINT="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token"
GRAPH_ENDPOINT="https://graph.microsoft.com/v1.0/teams/$TEAM_ID/channels/$CHANNEL_ID/messages"

# Funzione per ottenere l'Authorization Code
get_authorization_code() {
  echo "Apri il seguente URL nel browser per autorizzare l'app e ottenere l'Authorization Code:"
  AUTH_URL="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/authorize?client_id=$CLIENT_ID&response_type=code&redirect_uri=$REDIRECT_URI&scope=https://graph.microsoft.com/.default offline_access&state=12345"
  echo "$AUTH_URL"
  echo "Dopo aver autorizzato l'app, copia il codice di autorizzazione dalla barra degli indirizzi del browser."
}

# Funzione per ottenere l'Access Token iniziale
get_initial_access_token() {
  echo "Richiesta dell'Access Token iniziale..."
  RESPONSE=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=authorization_code" \
  -d "code=$AUTHORIZATION_CODE" \
  -d "redirect_uri=$REDIRECT_URI" \
  -d "scope=https://graph.microsoft.com/.default offline_access" \
  $TOKEN_ENDPOINT)

  ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')
  REFRESH_TOKEN=$(echo $RESPONSE | jq -r '.refresh_token')

  if [ "$ACCESS_TOKEN" != "null" ] && [ "$REFRESH_TOKEN" != "null" ]; then
    echo "Access Token e Refresh Token ottenuti con successo!"
    echo $ACCESS_TOKEN > access_token.txt
    echo $REFRESH_TOKEN > refresh_token.txt
  else
    echo "Errore durante l'ottenimento dell'Access Token: $RESPONSE"
    exit 1
  fi
}

# Funzione per ottenere un nuovo Access Token usando il Refresh Token
refresh_access_token() {
  echo "Richiesta di un nuovo Access Token tramite Refresh Token..."
  REFRESH_TOKEN=$(cat refresh_token.txt)
  RESPONSE=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=$REFRESH_TOKEN" \
  -d "scope=https://graph.microsoft.com/.default" \
  $TOKEN_ENDPOINT)

  ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')
  NEW_REFRESH_TOKEN=$(echo $RESPONSE | jq -r '.refresh_token')

  if [ "$ACCESS_TOKEN" != "null" ]; then
    echo "Nuovo Access Token ottenuto con successo!"
    echo $ACCESS_TOKEN > access_token.txt
    echo $NEW_REFRESH_TOKEN > refresh_token.txt
  else
    echo "Errore durante l'ottenimento del nuovo Access Token: $RESPONSE"
    exit 1
  fi
}

# Funzione per inviare un messaggio al canale Teams
send_message() {
  echo "Invio del messaggio al canale di Teams..."
  ACCESS_TOKEN=$(cat access_token.txt)
  JSON_PAYLOAD=$(cat <<EOF
{
  "body": {
    "content": "$MESSAGE"
  }
}
EOF
)

  RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  $GRAPH_ENDPOINT)

  if echo "$RESPONSE" | grep -q '"id"'; then
    echo "Messaggio inviato con successo!"
  else
    echo "Errore durante l'invio del messaggio: $RESPONSE"
  fi
}

# Flusso principale
if [ -z "$AUTHORIZATION_CODE" ]; then
  get_authorization_code
  echo "Inserisci l'Authorization Code nella variabile AUTHORIZATION_CODE e riesegui lo script."
  exit 0
fi

if [ ! -f access_token.txt ] || [ ! -f refresh_token.txt ]; then
  get_initial_access_token
else
  refresh_access_token
fi

send_message

