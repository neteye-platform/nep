#!/usr/bin/bash

PROG="`basename $0`"
ICINGA2HOST="`hostname`"

## Function helpers
Usage() {
cat << EOF

Required parameters:
  -d LONGDATETIME (\$icinga.long_date_time\$)
  -l HOSTNAME (\$host.name\$)
  -n HOSTDISPLAYNAME (\$host.display_name\$)
  -o HOSTOUTPUT (\$host.output\$)
  -s HOSTSTATE (\$host.state\$)
  -t NOTIFICATIONTYPE (\$notification.type\$)
  -w TEAMS_WEBHOOK_URL (\$teams_webhook_url\$)
  -m NOTIFICATION_METHOD (\$teams_notification_method\$)
  -a CLIENT_ID (\$teams_client_id\$)
  -y CLIENT_SECRET (\$teams_client_secret\$)
  -f TENANT_ID (\$teams_tenant_id\$)
  -g TEAM_ID (\$teams_team_id\$)
  -z CHANNEL_ID (\$teams_channel_id\$)
  -j AUTHORIZATION_CODE (\$teams_authorization_code\$)
  -r REDIRECT_URI (\$teams_redirect_uri\$)
Optional parameters:
  -4 HOSTADDRESS (\$address\$)
  -6 HOSTADDRESS6 (\$address6\$)
  -X HOSTNOTES (\$host.notes\$)
  -b NOTIFICATIONAUTHORNAME (\$notification.author\$)
  -c NOTIFICATIONCOMMENT (\$notification.comment\$)
  -i ICINGAWEB2URL (\$notification_icingaweb2url\$, Default: unset)
  -v (\$notification_sendtosyslog\$, Default: false)

EOF
}

Help() {
  Usage;
  exit 0;
}

Error() {
  if [ "$1" ]; then
    echo $1
  fi
  Usage;
  exit 1;
}

urlencode() {
  local LANG=C i=0 c e s="$1"

  while [ $i -lt ${#1} ]; do
    [ "$i" -eq 0 ] || s="${s#?}"
    c=${s%"${s#?}"}
    [ -z "${c#[[:alnum:].~_-]}" ] || c=$(printf '%%%02X' "'$c")
    e="${e}${c}"
    i=$((i + 1))
  done
  echo "$e"
}

## Main
while getopts 4:6::b:c:d:hi:l:n:o:s:t:v:X:w:m:a:y:f:g:z:j:r: opt
do
  case "$opt" in
    4) HOSTADDRESS=$OPTARG ;;
    6) HOSTADDRESS6=$OPTARG ;;
    b) NOTIFICATIONAUTHORNAME=$OPTARG ;;
    c) NOTIFICATIONCOMMENT=$OPTARG ;;
    d) LONGDATETIME=$OPTARG ;; # required
    h) Help ;;
    i) ICINGAWEB2URL=$OPTARG ;;
    l) HOSTNAME=$OPTARG ;; # required
    n) HOSTDISPLAYNAME=$OPTARG ;; # required
    o) HOSTOUTPUT=$OPTARG ;; # required
    X) HOSTNOTES=$OPTARG ;;
    s) HOSTSTATE=$OPTARG ;; # required
    t) NOTIFICATIONTYPE=$OPTARG ;; # required
    v) VERBOSE=$OPTARG ;;
    w) TEAMS_WEBHOOK_URL=$OPTARG ;; # required for Webhook
    m) NOTIFICATION_METHOD=$OPTARG ;; # Metodo di notifica
    a) CLIENT_ID=$OPTARG ;;
    y) CLIENT_SECRET=$OPTARG ;;
    f) TENANT_ID=$OPTARG ;;
    g) TEAM_ID=$OPTARG ;;
    z) CHANNEL_ID=$OPTARG ;;
    j) AUTHORIZATION_CODE=$OPTARG ;;
    r) REDIRECT_URI=$OPTARG ;;
   \?) echo "ERROR: Invalid option -$OPTARG" >&2
       Error ;;
    :) echo "Missing option argument for -$OPTARG" >&2
       Error ;;
    *) echo "Unimplemented option: -$OPTARG" >&2
       Error ;;
  esac
done

shift $((OPTIND - 1))

## Keep formatting in sync with teams-service-notification.sh
for P in LONGDATETIME HOSTNAME HOSTDISPLAYNAME HOSTOUTPUT HOSTSTATE NOTIFICATIONTYPE ; do
        eval "PAR=\$${P}"

        if [ ! "$PAR" ] ; then
                Error "Required parameter '$P' is missing."
        fi
done

## Build the message's subject
SUBJECT="[$NOTIFICATIONTYPE] Host $HOSTDISPLAYNAME is $HOSTSTATE!"

## Build the notification message
NOTIFICATION_MESSAGE=`cat << EOF
***** Host Monitoring on $ICINGA2HOST *****

$HOSTDISPLAYNAME is $HOSTSTATE!

Info:    $HOSTOUTPUT

When:    $LONGDATETIME
Host:    $HOSTNAME
EOF
`

## Check whether IPv4 was specified.
if [ -n "$HOSTADDRESS" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE
IPv4:    $HOSTADDRESS"
fi

## Check whether IPv6 was specified.
if [ -n "$HOSTADDRESS6" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE
IPv6:    $HOSTADDRESS6"
fi

## Check whether host notes was specified.
if [ -n "$HOSTNOTES" ] ; then
        NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE
Host notes: $HOSTNOTES"
fi

## Check whether author and comment was specified.
if [ -n "$NOTIFICATIONCOMMENT" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

Comment by $NOTIFICATIONAUTHORNAME:
  $NOTIFICATIONCOMMENT"
fi

## Check whether Icinga Web 2 URL was specified.
if [ -n "$ICINGAWEB2URL" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

$ICINGAWEB2URL/icingadb/host?name=$(urlencode "$HOSTNAME")"
fi

## Check whether verbose mode was enabled and log to syslog.
if [ "$VERBOSE" = "true" ] ; then
  logger "$PROG sends $SUBJECT => $USEREMAIL"
fi

#################################################
# INIZIO HTML FORMAT
################################################

html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

case "$HOSTSTATE" in
  UP)       ICON="🟢" ;;
  DOWN)     ICON="🔴" ;;
  UNKNOWN)  ICON="🟣" ;;
  *)        ICON="⚪️" ;;
esac

case "$HOSTSTATE" in
  DOWN)     ACK="true" ;;
  UNKNOWN)  ACK="true" ;;
esac

## Build the notification message (HTML)
NL='<br/>'          # scorciatoia per il ritorno a capo in HTML

NOTIFICATION_MESSAGE_HTML="
<b>***** Host Monitoring on $(html_escape "$ICINGA2HOST") *****</b>${NL}${NL}
<b>$ICON $(html_escape "$HOSTDISPLAYNAME")</b> is <b>$(html_escape "$HOSTSTATE")</b>!${NL}${NL}
<b>Info:</b> $(html_escape "$HOSTOUTPUT")${NL}
<b>When:</b> $(html_escape "$LONGDATETIME")${NL}
<b>Host:</b> $(html_escape "$HOSTNAME")${NL}"

# eventuali campi opzionali
[ -n "$HOSTADDRESS"  ] && NOTIFICATION_MESSAGE_HTML+="\n<b>IPv4:</b> $(html_escape "$HOSTADDRESS")"
[ -n "$HOSTADDRESS6" ] && NOTIFICATION_MESSAGE_HTML+="\n<b>IPv6:</b> $(html_escape "$HOSTADDRESS6")"
[ -n "$HOSTNOTES"    ] && NOTIFICATION_MESSAGE_HTML+="\n<b>Host notes:</b> $(html_escape "$HOSTNOTES")"

if [ -n "$NOTIFICATIONCOMMENT" ]; then
  NOTIFICATION_MESSAGE_HTML+="\n\n<i>Comment by $(html_escape "$NOTIFICATIONAUTHORNAME"):</i>${NL}$(html_escape "$NOTIFICATIONCOMMENT")"
fi

if [ -n "$ICINGAWEB2URL" ]; then
  NOTIFICATION_MESSAGE_HTML+="\n\n<a href=\"$ICINGAWEB2URL/monitoring/host/show?host=$(urlencode "$HOSTNAME")\">View Problem in NetEye</a>"
fi

if [ "$ACK" == "true" ]; then
  NOTIFICATION_MESSAGE_HTML+="\n\n<a href=\"${ICINGAWEB2URL}/monitoring/host/acknowledge-problem?host=$(urlencode "$HOSTNAME")\">Acknowledge Problem in NetEye</a>"
fi

# sostituisci tutti i \n con <br/> (serve per gli append precedenti)
NOTIFICATION_MESSAGE_HTML=$(echo -e "$NOTIFICATION_MESSAGE_HTML" | sed ':a;N;$!ba;s/\n/<br\/>/g')

###############################################
# FINE HTML FORMAT
###############################################



###############################################
## Teams App Registration
###############################################

# Endpoint Microsoft Graph
TOKEN_ENDPOINT="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token"
GRAPH_ENDPOINT="https://graph.microsoft.com/v1.0/teams/$TEAM_ID/channels/$CHANNEL_ID/messages"

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

  echo $ACCESS_TOKEN
  echo $REFRESH_TOKEN

  if [ "$ACCESS_TOKEN" != "null" ] && [ "$REFRESH_TOKEN" != "null" ]; then
    echo "Access Token and Refresh Token obtained successfully!"
    echo $ACCESS_TOKEN > /neteye/shared/icinga2/conf/icinga2/scripts/access_token.txt
    echo $REFRESH_TOKEN > /neteye/shared/icinga2/conf/icinga2/scripts/refresh_token.txt
  else
    echo "Error obtaining the Access Token: $RESPONSE"
    exit 1
  fi
}

# Function to obtain a new Access Token using the Refresh Token
refresh_access_token() {
  echo "Requesting a new Access Token using the Refresh Token..."
  REFRESH_TOKEN=$(cat /neteye/shared/icinga2/conf/icinga2/scripts/refresh_token.txt)
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
    echo $ACCESS_TOKEN > /neteye/shared/icinga2/conf/icinga2/scripts/access_token.txt
    echo $NEW_REFRESH_TOKEN > /neteye/shared/icinga2/conf/icinga2/scripts/refresh_token.txt
  else
    echo "Error obtaining the new Access Token: $RESPONSE"
    exit 1
  fi
}

# Function to send a message to the Teams channel
send_message() {
  echo "Sending message to the Teams channel..."
  ACCESS_TOKEN=$(cat /neteye/shared/icinga2/conf/icinga2/scripts/access_token.txt)

  JSON_PAYLOAD=$(jq -n \
    --arg ctype "html" \
    --arg content "$NOTIFICATION_MESSAGE_HTML" \
    '{body:{contentType:$ctype, content:$content}}')

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

###############################################

case "$NOTIFICATION_METHOD" in
  webhook)
    # Send message to Teams Webhook
    curl --silent --output /dev/null \
      --header "Content-Type: application/json" \
      --request POST \
      --data "{\"text\": \"$NOTIFICATION_MESSAGE\", \"summary\": \"$SUBJECT\"}" "$TEAMS_WEBHOOK_URL"
    ;;

  app)
    # Main flow
    if [ -z "$AUTHORIZATION_CODE" ]; then
      echo "Enter the Authorization Code in the AUTHORIZATION_CODE variable and rerun the script."
      exit 1
    fi
    # Send message to Teams App Registration
    if [ ! -f /neteye/shared/icinga2/conf/icinga2/scripts/access_token.txt ] || [ ! -f /neteye/shared/icinga2/conf/icinga2/scripts/refresh_token.txt ]; then
      get_initial_access_token
    else
      refresh_access_token
    fi
    send_message
    ;;

  *)
    echo "Unknown notification method: $NOTIFICATION_METHOD"
    exit 1
    ;;
esac

