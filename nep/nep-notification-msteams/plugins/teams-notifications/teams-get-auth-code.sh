#!/usr/bin/bash

# Configuration variables
CLIENT_ID="AAA1"                          # Client ID of your registered application
TENANT_ID="AAA3"                          # Azure AD tenant ID
REDIRECT_URI="http://localhost:8080"                                      # Redirect URI configured on the Office 365 side

# Helper to get the Authorization Code
get_authorization_code() {
  echo "Open the following URL in the browser to authorize the app and obtain the Authorization Code:"
  AUTH_URL="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/authorize?client_id=$CLIENT_ID&response_type=code&redirect_uri=$REDIRECT_URI&scope=https://graph.microsoft.com/.default offline_access&state=12345"
  echo "$AUTH_URL"
  echo "After authorizing the app, copy the authorization code from the browser's address bar."
}

get_authorization_code
