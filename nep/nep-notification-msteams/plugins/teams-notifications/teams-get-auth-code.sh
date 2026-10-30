#!/usr/bin/bash

# Variabili di configurazione
CLIENT_ID="AAA1"                          # ID cliente della tua applicazione registrata
TENANT_ID="AAA3"                          # ID del tenant Azure AD
REDIRECT_URI="http://localhost:8080"                                      # Redirect URI configurata lato Office 365

# Funzione per ottenere l'Authorization Code
get_authorization_code() {
  echo "Apri il seguente URL nel browser per autorizzare l'app e ottenere l'Authorization Code:"
  AUTH_URL="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/authorize?client_id=$CLIENT_ID&response_type=code&redirect_uri=$REDIRECT_URI&scope=https://graph.microsoft.com/.default offline_access&state=12345"
  echo "$AUTH_URL"
  echo "Dopo aver autorizzato l'app, copia il codice di autorizzazione dalla barra degli indirizzi del browser."
}

get_authorization_code

