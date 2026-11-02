#!/bin/bash

# CONFIGURATION: Insert your parameters here
TENANT_ID="AAA3"           # Azure AD tenant ID
CLIENT_ID="AAA1"           # Client ID of your registered application
CLIENT_SECRET="AAA2"   # Client secret generated for your application

# Endpoint to obtain the token
TOKEN_ENDPOINT="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token"

# Request the access token
echo "Requesting access token..."
TOKEN_RESPONSE=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
-d "client_id=$CLIENT_ID" \
-d "client_secret=$CLIENT_SECRET" \
-d "scope=https://graph.microsoft.com/.default" \
-d "grant_type=client_credentials" \
$TOKEN_ENDPOINT)

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Error: Unable to obtain access token."
  #echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "Token successfully obtained!"

# Get all teams in the organization
echo "========================================"
echo "Retrieving teams in the organization..."
TEAMS_RESPONSE=$(curl -s -X GET -H "Authorization: Bearer $ACCESS_TOKEN" \
"https://graph.microsoft.com/v1.0/teams")

#echo "Risposta API per i team:"
#echo "$TEAMS_RESPONSE"

TEAM_IDS=$(echo "$TEAMS_RESPONSE" | jq -r '.value[] | "\(.displayName): \(.id)"')

if [ -z "$TEAM_IDS" ]; then
  echo "Error: No teams found or missing permissions."
  #echo "Response: $TEAMS_RESPONSE"
  exit 1
fi

echo "Teams found:"
echo "$TEAM_IDS"
echo "========================================"

# Get channels for each team
echo "Retrieving channels for the found teams..."
for TEAM_ID in $(echo "$TEAMS_RESPONSE" | jq -r '.value[].id'); do
  #echo "Requesting channels for team $TEAM_ID"
  CHANNELS_RESPONSE=$(curl -s -X GET -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://graph.microsoft.com/v1.0/teams/$TEAM_ID/channels")

  #echo "API response for channels of team $TEAM_ID:"
  #echo "$CHANNELS_RESPONSE"

  CHANNEL_IDS=$(echo "$CHANNELS_RESPONSE" | jq -r '.value[] | "\(.displayName): \(.id)"')

  if [ -n "$CHANNEL_IDS" ]; then
    echo "Channels for team $TEAM_ID:"
    echo "$CHANNEL_IDS"
    echo "========================================"
  else
    echo "No channels found for team $TEAM_ID."
    echo "========================================"
  fi
done
