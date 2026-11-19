#!/bin/bash

# Configuration variables
CLIENT_ID="AAA1"                          # Client ID of your registered application
CLIENT_SECRET="AAA2"                      # Client secret generated for your application
TENANT_ID="AAA3"                          # Azure AD tenant ID
REDIRECT_URI="http://localhost:8080"      # Redirect URI configured on the Office 365 side
TEAM_ID="AAA4"                            # Microsoft Teams team ID
CHANNEL_ID="AAA5"                         # Microsoft Teams channel ID
MESSAGE="Message sent with authentication app"
AUTHORIZATION_CODE="AAA6"

# Endpoint Microsoft Graph
TOKEN_ENDPOINT="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token"
GRAPH_ENDPOINT="https://graph.microsoft.com/v1.0/teams/$TEAM_ID/channels/$CHANNEL_ID/messages"

# Function to obtain the Authorization Code
get_authorization_code() {
  echo "Open the following URL in the browser to authorize the app and obtain the Authorization Code:"
  AUTH_URL="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/authorize?client_id=$CLIENT_ID&response_type=code&redirect_uri=$REDIRECT_URI&scope=https://graph.microsoft.com/.default offline_access&state=12345"
  echo "$AUTH_URL"
  echo "After authorizing the app, copy the authorization code from the browser's address bar."
}

# Function to obtain the initial Access Token
get_initial_access_token() {
  echo "Requesting the initial Access Token..."
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
    echo "Access Token and Refresh Token obtained successfully!"
    echo $ACCESS_TOKEN > access_token.txt
    echo $REFRESH_TOKEN > refresh_token.txt
  else
    echo "Error obtaining the Access Token: $RESPONSE"
    exit 1
  fi
}

# Function to obtain a new Access Token using the Refresh Token
refresh_access_token() {
  echo "Requesting a new Access Token using the Refresh Token..."
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
    echo "New Access Token obtained successfully!"
    echo $ACCESS_TOKEN > access_token.txt
    echo $NEW_REFRESH_TOKEN > refresh_token.txt
  else
    echo "Error obtaining the new Access Token: $RESPONSE"
    exit 1
  fi
}

# Function to send a message to the Teams channel
send_message() {
  echo "Sending message to the Teams channel..."
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
    echo "Message sent successfully!"
  else
    echo "Error sending the message: $RESPONSE"
  fi
}

# Main flow
if [ -z "$AUTHORIZATION_CODE" ]; then
  get_authorization_code
  echo "Enter the Authorization Code in the AUTHORIZATION_CODE variable and rerun the script."
  exit 0
fi

if [ ! -f access_token.txt ] || [ ! -f refresh_token.txt ]; then
  get_initial_access_token
else
  refresh_access_token
fi

send_message
