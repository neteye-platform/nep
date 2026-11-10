#!/usr/bin/perl
# NetEye HTML Email Notification
# Version 3.0.0
#
# Originally based on work by Martin Fuerstenau / Frank Migge (GPL).
#
# Changes from 2.0.0:
#   [SECURITY] HTML entity encoding applied to ALL user-supplied variables
#              embedded in the HTML body (host output, service output,
#              longserviceoutput, comment, author, hostname, alias, address).
#   [SECURITY] Header injection protection: CR/LF stripped from all values
#              used in mail headers (To, From, Subject).
#   [BUGFIX]   URLs updated to IcingaDB paths:
#                /icingadb/host?name=<host>
#                /icingadb/service?name=<svc>&host.name=<host>
#   [FEATURE]  --icingaweb2url (-i) added as preferred URL source, matching
#              the $notification_icingaweb2url$ Director variable. When set,
#              it is used directly as the base URL.
#              --nagios (-N) / --ssl (-s) retained for backward compatibility.
#              If both are provided, --icingaweb2url takes precedence.
#   [BUGFIX]   $longserviceoutput now rendered in both text and HTML parts
#              (was parsed from CLI but silently discarded).
#   [BUGFIX]   Boundary strings now use distinct random seeds; no longer
#              possible to produce identical boundary1/boundary2 in same second.
#   [BUGFIX]   Missing %NOTIFICATIONCOLOR keys no longer silently produce
#              unquoted bgcolor= attributes; unknown states fall back to #757575.
#   [QUALITY]  State and notification-type colors moved into script as defaults.
#              %NOTIFICATIONCOLOR in .cfg is still accepted as an override for
#              backward compatibility.
#   [QUALITY]  Replaced deprecated <font> tags and unquoted HTML attributes
#              with fully inline-CSS table layout (Outlook + Gmail safe).
#   [QUALITY]  Template updated to WP/NetEye brand: dark header, colored state
#              banner, 2-column data table, red CTA button, dark footer.
#   [QUALITY]  Added use strict / use warnings.
#   [QUALITY]  Config errors now produce a fatal message instead of silently
#              producing a broken email.

use strict;
use warnings;
use Getopt::Long;
use Mail::Sendmail;
use Digest::MD5 qw(md5_hex);
use MIME::Base64 qw(encode_base64);
use File::Basename;

my $PROG_VERSION = '3.0.0';

# ---------------------------------------------------------------------------
# Config-file variables (populated by: do "$config_file")
# Declare as 'our' so the config file's assignments reach this scope.
# ---------------------------------------------------------------------------
our $smtphost;           # required: SMTP relay hostname or IP
our $logofile;           # required: absolute path to logo image (PNG/JPG/GIF)
our %NOTIFICATIONCOLOR;  # optional: legacy color override map

# ---------------------------------------------------------------------------
# Built-in color maps (keys are uppercase, as Icinga2 delivers them).
# Override individual entries via %NOTIFICATIONCOLOR in the .cfg file.
# ---------------------------------------------------------------------------
my %STATE_COLOR = (
    UP          => '#2e7d32',   # green
    DOWN        => '#c62828',   # red
    OK          => '#2e7d32',   # green
    WARNING     => '#e65100',   # dark orange
    CRITICAL    => '#c62828',   # red
    UNKNOWN     => '#6a1fa2',   # purple
    UNREACHABLE => '#c62828',   # red
);

my %TYPE_COLOR = (
    PROBLEM           => '#c62828',   # red
    RECOVERY          => '#2e7d32',   # green
    ACKNOWLEDGEMENT   => '#1565c0',   # blue
    FLAPPINGSTART     => '#f57f17',   # amber
    FLAPPINGSTOP      => '#2e7d32',   # green
    FLAPPINGDISABLED  => '#757575',   # grey
    DOWNTIMESTART     => '#00695c',   # teal
    DOWNTIMEEND       => '#00695c',   # teal
    DOWNTIMECANCELLED => '#00695c',   # teal
    CUSTOM            => '#4527a0',   # deep purple
);

# Brand palette (not configurable; edit here for white-labelling)
my $BRAND_HEADER_BG = '#1a1a1a';
my $BRAND_RED       = '#e30613';
my $LABEL_BG        = '#f5f5f5';
my $LABEL_COLOR     = '#555555';
my $VALUE_COLOR     = '#222222';
my $DIVIDER_COLOR   = '#e0e0e0';
my $FOOTER_BG       = '#1a1a1a';
my $FOOTER_TEXT     = '#aaaaaa';

# 1x1 transparent GIF — used as fallback when $logofile is not found
my $EMPTY_IMG = 'R0lGODlhAQABAJEAAAAAAP///////wAAACH5BAEAAAIALAAAAAABAAEAAAICTAEAOw==';

# ---------------------------------------------------------------------------
# Runtime variables
# ---------------------------------------------------------------------------
my ($opt_help, $opt_version, $opt_thruk, $opt_ssl);
my $opt_format = 'html';   # 'html' (default) or 'text' — set via --format
my ($config_file, $NagHost, $icingaweb2url_arg);
my ($recipients, $mail_sender);
my ($notificationtype, $datetime, $state);
my ($hostname, $hostalias, $hostaddress);
my ($servicedesc, $servicedispname, $serviceoutput, $longserviceoutput);
my ($notificationauthor, $notificationcmt);

# Set by create_message_html(), referenced in MIME assembly
my $logo_id;

my ($text_msg, $html_msg);
my ($boundary1, $boundary2);
my ($logo_img, $logo_type, $logo_name);

# ---------------------------------------------------------------------------
# Option parsing
# ---------------------------------------------------------------------------
Getopt::Long::Configure('bundling');
GetOptions(
    'V|version'            => \$opt_version,
    'h|help'               => \$opt_help,
    't|thruk'              => \$opt_thruk,
    's|ssl'                => \$opt_ssl,
    'c|configuration:s'    => \$config_file,
    'N|nagios:s'           => \$NagHost,
    'i|icingaweb2url:s'    => \$icingaweb2url_arg,
    'S|smtphost:s'         => \$smtphost,
    'r|recipients:s'       => \$recipients,
    'mail_sender:s'        => \$mail_sender,
    'notificationtype:s'   => \$notificationtype,
    'datetime:s'           => \$datetime,
    'hostaddress:s'        => \$hostaddress,
    'hostalias:s'          => \$hostalias,
    'hostname:s'           => \$hostname,
    'notificationauthor:s' => \$notificationauthor,
    'notificationcmt:s'    => \$notificationcmt,
    'servicedesc:s'        => \$servicedesc,
    'servicedispname:s'    => \$servicedispname,
    'serviceoutput:s'      => \$serviceoutput,
    'longserviceoutput:s'  => \$longserviceoutput,
    'state:s'              => \$state,
    'format:s'             => \$opt_format,  # 'html' or 'text'; default 'html'
) or do { print_usage(); exit 2; };

if ($opt_help)    { help();          exit 0; }
if ($opt_version) { print_version(); exit 0; }
# Validate --format
$opt_format = lc($opt_format // 'html');
die "Error: --format must be 'html' or 'text', got '$opt_format'.
"
    unless $opt_format eq 'html' || $opt_format eq 'text';

# ---------------------------------------------------------------------------
# Config file loading
# ---------------------------------------------------------------------------
if (!defined $config_file || $config_file eq '') {
    $config_file = dirname($0) . '/' . basename($0, '.pl') . '.cfg';
}

if (-e $config_file) {
    die "Configuration file '$config_file' is empty.\n"         if  -z $config_file;
    die "Configuration file '$config_file' is not a plain file.\n" unless -f $config_file;
    ## no critic (ProhibitStringyEval)
    do $config_file;
    die "Error loading '$config_file': $@\n" if $@;
} else {
    die "Configuration file '$config_file' not found.\n";
}

# Merge any %NOTIFICATIONCOLOR keys from config into the built-in maps.
# This keeps backward compatibility with existing .cfg files.
if (%NOTIFICATIONCOLOR) {
    for my $key (keys %NOTIFICATIONCOLOR) {
        $STATE_COLOR{$key} = $NOTIFICATIONCOLOR{$key} if exists $STATE_COLOR{$key};
        $TYPE_COLOR{$key}  = $NOTIFICATIONCOLOR{$key} if exists $TYPE_COLOR{$key};
    }
}

# ---------------------------------------------------------------------------
# State normalization
# When --state is sourced from an Icinga DSL argument, Icinga2 passes the raw
# numeric state value instead of text. This mapping handles both host states
# (0-2) and service states (0-3) so the script works correctly regardless of
# whether the Director argument is String ($service.state$) or Icinga DSL.
# ---------------------------------------------------------------------------
my %HOST_STATE_NUM_MAP = (0 => 'UP', 1 => 'DOWN', 2 => 'UNREACHABLE');
my %SVC_STATE_NUM_MAP  = (0 => 'OK',  1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN');

if (defined $state && $state =~ /^\d+$/) {
    my $is_host = (!defined $servicedesc || $servicedesc eq '');
    $state = $is_host
        ? ($HOST_STATE_NUM_MAP{$state} // "UNKNOWN($state)")
        : ($SVC_STATE_NUM_MAP{$state}  // "UNKNOWN($state)");
}

# ---------------------------------------------------------------------------
# Validate required parameters
# ---------------------------------------------------------------------------
die "Error: --recipients (-r) is required.\n"       unless defined $recipients  && $recipients ne '';
die "Error: --notificationtype is required.\n"       unless defined $notificationtype && $notificationtype ne '';
die "Error: --datetime is required.\n"               unless defined $datetime    && $datetime ne '';
die "Error: --hostname is required.\n"               unless defined $hostname    && $hostname ne '';
die "Error: --state is required.\n"                  unless defined $state       && $state ne '';
die "Error: \$smtphost not defined in config file.\n" unless defined $smtphost   && $smtphost ne '';

if (defined $servicedesc && $servicedesc ne '') {
    die "Error: --serviceoutput required when --servicedesc is given.\n"
        unless defined $serviceoutput && $serviceoutput ne '';
}

# ---------------------------------------------------------------------------
# Header injection protection: strip CR and LF from all header-bound values
# ---------------------------------------------------------------------------
sub strip_header {
    my ($val) = @_;
    return '' unless defined $val;
    $val =~ s/[\r\n]+/ /g;
    $val =~ s/^\s+|\s+$//g;
    return $val;
}

# ---------------------------------------------------------------------------
# UTC timestamp display
# $icinga.long_date_time$ arrives as e.g. "2026-04-23 12:25:17 +0200"
# We display it with both local time and UTC so recipients in any timezone
# can unambiguously locate the event.
# ---------------------------------------------------------------------------
sub datetime_to_utc {
    my ($dt_str) = @_;
    return $dt_str unless defined $dt_str;

    # Parse: "YYYY-MM-DD HH:MM:SS +HHMM" or "YYYY-MM-DD HH:MM:SS +HH:MM"
    if ($dt_str =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s*([+-])(\d{2}):?(\d{2})$/) {
        my ($local_str, $sign, $off_h, $off_m) = ($1, $2, $3, $4);
        my $offset_secs = ($off_h * 3600 + $off_m * 60) * ($sign eq '+' ? 1 : -1);

        # Parse local time components
        my ($y, $mo, $d, $h, $mi, $s) = $local_str =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)/;

        # Convert to epoch using timegm (treats input as UTC), then adjust for offset
        require Time::Local;
        my $epoch = Time::Local::timegm($s, $mi, $h, $d, $mo - 1, $y) - $offset_secs;

        # Format UTC time
        my @utc = gmtime($epoch);
        my $utc_str = sprintf("%04d-%02d-%02d %02d:%02d:%02d UTC",
            $utc[5]+1900, $utc[4]+1, $utc[3], $utc[2], $utc[1], $utc[0]);

        # Return combined display: local time + UTC
        return "$local_str $sign$off_h:$off_m ($utc_str)";
    }

    # If parsing fails, return original unchanged
    return $dt_str;
}

my $datetime_display = datetime_to_utc($datetime);

$recipients      = strip_header($recipients);
$mail_sender     = strip_header($mail_sender // '');
$notificationtype = strip_header($notificationtype);
$state           = strip_header($state);
$hostname        = strip_header($hostname);

# ---------------------------------------------------------------------------
# HTML entity encoding: applied to every variable embedded in the HTML body
# Encodes: & < > " '
# ---------------------------------------------------------------------------
sub html_encode {
    my ($val) = @_;
    return '' unless defined $val;
    $val =~ s/&/&amp;/g;
    $val =~ s/</&lt;/g;
    $val =~ s/>/&gt;/g;
    $val =~ s/"/&quot;/g;
    $val =~ s/'/&#39;/g;
    return $val;
}

# ---------------------------------------------------------------------------
# Build base URL
# --icingaweb2url takes precedence; --nagios/--ssl used as fallback.
# ---------------------------------------------------------------------------
my $base_url;
if (defined $icingaweb2url_arg && $icingaweb2url_arg ne '') {
    ($base_url = $icingaweb2url_arg) =~ s{/+$}{};
} elsif (defined $NagHost && $NagHost ne '') {
    my $proto = (defined $opt_ssl) ? 'https' : 'http';
    $base_url = "$proto://$NagHost";
}

# IcingaWeb2 on NetEye is served under the /neteye prefix, so the module
# paths are /neteye/icingadb/... . Append /neteye to the base URL unless the
# supplied value already ends in it (so an --icingaweb2url that already
# includes the prefix is not doubled). This lets administrators configure
# just the bare IP/FQDN in nx_neteye_web_interface_fqdn.
if (defined $base_url) {
    $base_url =~ s{/+$}{};
    $base_url .= '/neteye' unless $base_url =~ m{/neteye$};
}

my ($host_url, $detail_url);
if (defined $base_url) {
    $host_url   = $base_url . '/icingadb/host?name=' . urlencode($hostname);
    $detail_url = (defined $servicedesc && $servicedesc ne '')
        ? $base_url . '/icingadb/service?name=' . urlencode($servicedesc)
                    . '&host.name='             . urlencode($hostname)
        : $host_url;
}

# ---------------------------------------------------------------------------
# Resolve display names (alias preferred over internal name)
# ---------------------------------------------------------------------------
my $display_host = (defined $hostalias && $hostalias ne '') ? $hostalias : $hostname;
my $display_svc  = (defined $servicedispname && $servicedispname ne '')
                 ? $servicedispname
                 : (defined $servicedesc ? $servicedesc : '');

# ---------------------------------------------------------------------------
# Build email subject
# ---------------------------------------------------------------------------
my $subject = (defined $servicedesc && $servicedesc ne '')
    ? "NetEye: [$notificationtype] $display_svc on $display_host is $state"
    : "NetEye: [$notificationtype] $display_host is $state";
$subject = strip_header($subject);

# ---------------------------------------------------------------------------
# Color helpers with fallback to neutral grey for unrecognized values
# ---------------------------------------------------------------------------
sub get_state_color {
    my ($s) = @_;
    return $STATE_COLOR{uc($s)} // '#757575';
}

sub get_type_color {
    my ($t) = @_;
    return $TYPE_COLOR{uc($t)} // '#757575';
}

# ---------------------------------------------------------------------------
# Logo
# ---------------------------------------------------------------------------
my $logo_available = 0;
if (defined $logofile && $logofile ne '' && -f $logofile) {
    $logo_img       = b64encode_img($logofile);
    $logo_type      = ($logofile =~ m/\.([^.]+)$/) ? lc($1) : 'png';
    $logo_name      = basename($logofile);
    $logo_available = 1;
} else {
    $logo_img  = $EMPTY_IMG;
    $logo_type = 'gif';
    $logo_name = 'logo.gif';
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Build and send
# ---------------------------------------------------------------------------
create_boundary();
create_message_text();
create_message_html() if $opt_format eq 'html';

my %mail_hash = (
    To      => $recipients,
    Subject => $subject,
    smtp    => $smtphost,
);
$mail_hash{From}   = $mail_sender if $mail_sender ne '';
$mail_hash{Sender} = $mail_sender if $mail_sender ne '';

my $mail_body;

if ($opt_format eq 'text') {
    # Text-only email: single text/plain part, no HTML, no logo attachment.
    # Suitable for recipients or gateways that cannot render HTML.
    $mail_hash{'content-type'} = 'text/plain; charset=utf-8';
    $mail_body = $text_msg;
} else {
    # Multipart/alternative: text/plain fallback + HTML with embedded logo.
    $mail_hash{'content-type'} = qq(multipart/alternative; boundary="$boundary1");
    $mail_body = "This is a multi-part message in MIME format.\n";

    # --- Part 1: text/plain ---
    $mail_body .= "--$boundary1\n";
    $mail_body .= "Content-Type: text/plain; charset=utf-8\n";
    $mail_body .= "Content-Transfer-Encoding: 8bit\n\n";
    $mail_body .= "$text_msg\n";

    # --- Part 2: multipart/related (HTML + embedded logo) ---
    $mail_body .= "--$boundary1\n";
    $mail_body .= qq(Content-Type: multipart/related; boundary="$boundary2"\n\n);
    $mail_body .= "--$boundary2\n";
    $mail_body .= "Content-Type: text/html; charset=utf-8\n";
    $mail_body .= "Content-Transfer-Encoding: 8bit\n\n";
    $mail_body .= "$html_msg\n";

    $mail_body .= "--$boundary2\n";
    $mail_body .= "Content-Type: image/$logo_type; name=\"$logo_name\"\n";
    $mail_body .= "Content-Transfer-Encoding: base64\n";
    $mail_body .= "Content-ID: <$logo_id>\n";
    $mail_body .= "Content-Disposition: inline; filename=\"$logo_name\"\n\n";
    $mail_body .= "$logo_img\n";
    $mail_body .= "--$boundary2--\n\n";
    $mail_body .= "--$boundary1--\n";
}

$mail_hash{body} = $mail_body;

sendmail(%mail_hash) or die $Mail::Sendmail::error;
exit 0;


###############################################################################
# Subroutines
###############################################################################

# ---------------------------------------------------------------------------
# create_boundary — generates two distinct MIME boundary strings.
# Uses separate random seeds so boundary1 != boundary2 even within one second.
# ---------------------------------------------------------------------------
sub create_boundary {
    my $seed1 = md5_hex(time() . rand(1_000_000));
    my $seed2 = md5_hex(time() . rand(1_000_000) . $$);
    $boundary1 = '======Part1=' . substr($seed1, 0, 24);
    $boundary2 = '======Part2=' . substr($seed2, 0, 24);
}

# ---------------------------------------------------------------------------
# create_content_id — returns a unique Content-ID for embedded MIME parts
# ---------------------------------------------------------------------------
sub create_content_id {
    my $unique = rand(100) . substr(md5_hex(time()), 0, 23);
    $unique =~ s/(.{5})/$1\./g;
    return "part.${unique}\@MAIL";
}

# ---------------------------------------------------------------------------
# create_message_text — builds the text/plain part ($text_msg)
# No HTML encoding needed here; plain text only.
# ---------------------------------------------------------------------------
sub create_message_text {
    $text_msg  = "NetEye Monitoring System Notification\n";
    $text_msg .= "======================================\n\n";
    $text_msg .= "Notification Type : $notificationtype\n";
    $text_msg .= "State             : $state\n";
    # Use display name (alias preferred over internal hostname) — same logic as HTML part
    $text_msg .= "Hostname          : $display_host\n";
    if ($display_host ne $hostname) {
        $text_msg .= "Host (internal)   : $hostname\n";
    }
    if (defined $hostaddress && $hostaddress ne '') {
        $text_msg .= "Host Address      : $hostaddress\n";
    }

    if (defined $servicedesc && $servicedesc ne '') {
        # Strip any HTML from service output for the plain text part
        (my $svc_plain = $serviceoutput) =~ s/<[^<>]*>//g;
        $text_msg .= "Service           : " . ($display_svc ne '' ? $display_svc : $servicedesc) . "\n";
        $text_msg .= "Service Output    : $svc_plain\n";

        if (defined $longserviceoutput && $longserviceoutput ne '') {
            (my $long_plain = $longserviceoutput) =~ s/<[^<>]*>//g;
            $long_plain =~ s/\\n/\n/g;
            $text_msg .= "\nAdditional Output:\n$long_plain\n";
        }
    }

    if (defined $notificationauthor && $notificationauthor ne ''
     && defined $notificationcmt    && $notificationcmt    ne '') {
        $text_msg .= "\nAuthor  : $notificationauthor\n";
        $text_msg .= "Comment : $notificationcmt\n";
    }

    $text_msg .= "\nEvent Time : $datetime_display\n";
    $text_msg .= "--------------------------------------\n";

    if (defined $detail_url) {
        $text_msg .= "\nView in NetEye : $detail_url\n";
    }
}

# ---------------------------------------------------------------------------
# create_message_html — builds the text/html part ($html_msg)
# ALL user-supplied variables are passed through html_encode() before
# being embedded in the HTML body.
# ---------------------------------------------------------------------------
sub create_message_html {

    # Pre-encode every value that will appear in the HTML body
    my $enc_type        = html_encode($notificationtype);
    my $enc_state       = html_encode($state);
    my $enc_hostname    = html_encode($hostname);
    my $enc_alias       = html_encode($hostalias    // '');
    my $enc_address     = html_encode($hostaddress  // '');
    my $enc_author      = html_encode($notificationauthor // '');
    my $enc_comment     = html_encode($notificationcmt    // '');
    my $enc_datetime    = html_encode($datetime_display);
    my $enc_disphost    = html_encode($display_host);
    my $enc_dispsvc     = html_encode($display_svc);
    my $enc_servicedesc = html_encode($servicedesc  // '');

    # Service output: encode entities first, then convert newlines to <br>
    # Order matters: encode before substituting <br> so we don't double-encode
    my $enc_svcout = '';
    if (defined $serviceoutput && $serviceoutput ne '') {
        $enc_svcout = html_encode($serviceoutput);
        $enc_svcout =~ s/\n/<br>/g;
        $enc_svcout =~ s/\\n/<br>/g;
    }

    my $enc_longsvcout = '';
    if (defined $longserviceoutput && $longserviceoutput ne '') {
        $enc_longsvcout = html_encode($longserviceoutput);
        $enc_longsvcout =~ s/\n/<br>/g;
        $enc_longsvcout =~ s/\\n/<br>/g;
    }

    # CID for the embedded logo
    $logo_id = create_content_id();

    # Colors
    my $state_color = get_state_color($state);
    my $type_color  = get_type_color($notificationtype);

    # Safe URL for CTA button (html_encode the URL to prevent attribute injection)
    my $cta_url     = defined $detail_url  ? html_encode($detail_url)  : '';
    my $host_url_h  = defined $host_url    ? html_encode($host_url)    : '';

    # Summary line for the state banner
    my $banner_text = (defined $servicedesc && $servicedesc ne '')
        ? "$enc_dispsvc on $enc_disphost is $enc_state"
        : "$enc_disphost is $enc_state";

    # -----------------------------------------------------------------------
    # HTML layout:
    #   - Dark header banner (brand) with embedded logo right-aligned
    #   - Colored state banner (state color) with summary line
    #   - 2-column data table
    #   - CTA button (WP red) linking to IcingaDB
    #   - Dark footer
    #
    # Rules for email-client compatibility:
    #   - All styles are inline (Gmail strips <head>/<style>)
    #   - Table-based layout (Outlook ignores flexbox/grid)
    #   - bgcolor attribute on <td> in addition to inline style (Outlook fallback)
    #   - Max width 600px
    #   - No external resources (logo is embedded as CID)
    # -----------------------------------------------------------------------

    $html_msg = <<HTML_START;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NetEye Monitoring Notification</title>
</head>
<body style="margin:0;padding:0;background-color:#f0f0f0;font-family:Arial,Helvetica,sans-serif;">
<table border="0" cellpadding="0" cellspacing="0" width="100%"
       style="background-color:#f0f0f0;">
  <tr>
    <td align="center" style="padding:24px 0;">

      <!-- ============================================================
           Main container — 600px
           ============================================================ -->
      <table border="0" cellpadding="0" cellspacing="0" width="600"
             style="background-color:#ffffff;">

        <!-- ============================================================
             HEADER: dark background with embedded logo
             ============================================================ -->
        <tr>
          <td bgcolor="$BRAND_HEADER_BG"
              style="background-color:$BRAND_HEADER_BG;padding:18px 28px;">
            <table border="0" cellpadding="0" cellspacing="0" width="100%">
              <tr>
                <td style="font-family:Arial,Helvetica,sans-serif;
                            font-size:20px;font-weight:bold;
                            color:#ffffff;vertical-align:middle;">
                  NetEye Monitoring
                </td>
                <td align="right" style="vertical-align:middle;">
                  ${\( $logo_available ? qq(
                  <div style="background-color:#ffffff;display:inline-block;
                               padding:6px 10px;line-height:0;">
                    <img src="cid:$logo_id" width="82" height="62"
                         alt="NetEye" style="display:block;border:0;">
                  </div>) : '' )}
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- ============================================================
             STATE BANNER: color driven by host/service state
             ============================================================ -->
        <tr>
          <td bgcolor="$state_color"
              style="background-color:$state_color;padding:16px 28px;">
            <span style="font-family:Arial,Helvetica,sans-serif;
                          font-size:17px;font-weight:bold;color:#ffffff;">
              $banner_text
            </span>
          </td>
        </tr>

        <!-- ============================================================
             DATA TABLE: 2-column label/value rows
             ============================================================ -->
        <tr>
          <td style="padding:0;">
            <table border="0" cellpadding="0" cellspacing="0" width="100%">
HTML_START

    # Helper: emit a single data row
    # row($label, $value_html, $value_bg)
    # $value_bg is optional; defaults to #ffffff
    my $row = sub {
        my ($label, $value_html, $bg) = @_;
        $bg //= '#ffffff';
        return
            qq(<tr>\n) .
            qq(  <td width="160" bgcolor="$LABEL_BG"\n) .
            qq(      style="background-color:$LABEL_BG;padding:11px 20px;\n) .
            qq(             border-bottom:1px solid $DIVIDER_COLOR;\n) .
            qq(             font-family:Arial,Helvetica,sans-serif;\n) .
            qq(             font-size:12px;font-weight:bold;\n) .
            qq(             color:$LABEL_COLOR;vertical-align:top;">\n) .
            qq(    $label\n) .
            qq(  </td>\n) .
            qq(  <td bgcolor="$bg"\n) .
            qq(      style="background-color:$bg;padding:11px 20px;\n) .
            qq(             border-bottom:1px solid $DIVIDER_COLOR;\n) .
            qq(             font-family:Arial,Helvetica,sans-serif;\n) .
            qq(             font-size:13px;color:$VALUE_COLOR;\n) .
            qq(             vertical-align:top;">\n) .
            qq(    $value_html\n) .
            qq(  </td>\n) .
            qq(</tr>\n);
    };

    # Notification Type row — type-colored badge
    my $type_badge = qq(<span style="display:inline-block;padding:3px 10px;)
                   . qq(background-color:$type_color;color:#ffffff;)
                   . qq(font-family:Arial,Helvetica,sans-serif;)
                   . qq(font-size:12px;font-weight:bold;">$enc_type</span>);
    $html_msg .= $row->('Notification Type', $type_badge);

    # State row — state-colored badge
    my $state_badge = qq(<span style="display:inline-block;padding:3px 10px;)
                    . qq(background-color:$state_color;color:#ffffff;)
                    . qq(font-family:Arial,Helvetica,sans-serif;)
                    . qq(font-size:12px;font-weight:bold;">$enc_state</span>);
    $html_msg .= $row->('State', $state_badge);

    # Hostname (with link if URL available)
    my $hostname_cell = $host_url_h
        ? qq($enc_disphost<br><a href="$host_url_h" )
        . qq(style="color:$BRAND_RED;font-size:11px;">View host in NetEye &rsaquo;</a>)
        : $enc_disphost;
    if ($enc_alias ne '' && $enc_alias ne $enc_disphost) {
        $hostname_cell .= "<br><span style=\"color:#888888;font-size:11px;\">$enc_alias</span>";
    }
    $html_msg .= $row->('Hostname', $hostname_cell);

    # Host Address
    if ($enc_address ne '') {
        $html_msg .= $row->('Host Address', $enc_address);
    }

    # Service rows (only in service mode)
    if (defined $servicedesc && $servicedesc ne '') {
        $html_msg .= $row->('Service', $enc_dispsvc ne '' ? $enc_dispsvc : $enc_servicedesc);

        my $svcout_cell = $enc_svcout;
        if ($cta_url ne '') {
            $svcout_cell .= qq(<br><a href="$cta_url" )
                          . qq(style="color:$BRAND_RED;font-size:11px;">View service in NetEye &rsaquo;</a>);
        }
        $html_msg .= $row->('Service Output', $svcout_cell);

        if ($enc_longsvcout ne '') {
            $html_msg .= $row->(
                'Additional Output',
                qq(<span style="font-size:12px;color:#444444;">$enc_longsvcout</span>)
            );
        }
    }

    # Author + Comment (acknowledgements, downtime, custom)
    if ($enc_author ne '' && $enc_comment ne '') {
        $html_msg .= $row->('Author',  $enc_author);
        $html_msg .= $row->('Comment', $enc_comment);
    }

    # Event Time
    $html_msg .= $row->('Event Time', $enc_datetime);

    $html_msg .= <<HTML_TABLE_END;
            </table>
          </td>
        </tr>
HTML_TABLE_END

    # CTA button — only rendered when a URL is available
    if ($cta_url ne '') {
        $html_msg .= <<HTML_CTA;
        <!-- ============================================================
             CTA BUTTON
             ============================================================ -->
        <tr>
          <td align="center" style="padding:24px 28px;">
            <!--[if mso]>
            <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml"
              xmlns:w="urn:schemas-microsoft-com:office:word"
              href="$cta_url" style="height:40px;v-text-anchor:middle;width:200px;"
              arcsize="8%" stroke="f" fillcolor="$BRAND_RED">
              <w:anchorlock/>
              <center style="color:#ffffff;font-family:Arial,Helvetica,sans-serif;
                             font-size:14px;font-weight:bold;">
                View in NetEye
              </center>
            </v:roundrect>
            <![endif]-->
            <!--[if !mso]><!-->
            <a href="$cta_url"
               style="background-color:$BRAND_RED;color:#ffffff;
                      font-family:Arial,Helvetica,sans-serif;font-size:14px;
                      font-weight:bold;text-decoration:none;padding:11px 32px;
                      display:inline-block;">
              View in NetEye
            </a>
            <!--<![endif]-->
          </td>
        </tr>
HTML_CTA
    }

    # Footer
    $html_msg .= <<HTML_FOOTER;
        <!-- ============================================================
             FOOTER
             ============================================================ -->
        <tr>
          <td bgcolor="$FOOTER_BG"
              style="background-color:$FOOTER_BG;padding:18px 28px;
                     text-align:center;">
            <p style="margin:0;font-family:Arial,Helvetica,sans-serif;
                       font-size:12px;color:$FOOTER_TEXT;">
              NetEye Monitoring &mdash; Würth-IT GmbH
            </p>
            <p style="margin:6px 0 0 0;font-family:Arial,Helvetica,sans-serif;
                       font-size:11px;color:#666666;">
              This is an automated notification. Please do not reply to this email.
            </p>
          </td>
        </tr>

      </table>
      <!-- end main container -->

    </td>
  </tr>
</table>
</body>
</html>
HTML_FOOTER

}

# ---------------------------------------------------------------------------
# urlencode — percent-encodes a string for use in URLs
# ---------------------------------------------------------------------------
sub urlencode {
    my ($str) = @_;
    $str =~ s/([^A-Za-z0-9\-_.~])/sprintf('%%%02X', ord($1))/eg;
    return $str;
}

# ---------------------------------------------------------------------------
# b64encode_img — base64-encodes a binary image file
# ---------------------------------------------------------------------------
sub b64encode_img {
    my ($file) = @_;
    open(my $fh, '<', $file) or die "Cannot open logo file '$file': $!\n";
    binmode $fh;
    local $/;
    my $data = <$fh>;
    close $fh;
    return encode_base64($data);
}

# ---------------------------------------------------------------------------
# Utility: version / usage / help
# ---------------------------------------------------------------------------
sub print_version {
    print "\nmail-html-notification.pl version $PROG_VERSION\n\n";
}

sub print_usage {
    print <<USAGE;

Usage: $0 [OPTIONS]

Required:
  -r, --recipients=<addr>           \$user.email\$
      --notificationtype=<type>     \$notification.type\$
      --datetime=<datetime>         \$icinga.long_date_time\$
      --hostname=<name>             \$host.name\$
      --state=<state>               \$host.state\$ or \$service.state\$
      --mail_sender=<addr>          \$notification_mailfrom\$

Optional (general):
  -N, --nagios=<fqdn>               NetEye hostname (used to construct base URL)
  -s, --ssl                         Use HTTPS instead of HTTP with --nagios
  -i, --icingaweb2url=<url>         Full base URL (\$notification_icingaweb2url\$)
                                    Takes precedence over --nagios/--ssl
      --hostaddress=<ip>            \$address\$
      --hostalias=<alias>           \$host.display_name\$
      --notificationauthor=<name>   \$notification.author\$
      --notificationcmt=<text>      \$notification.comment\$

Optional (service mode — triggers service notification layout):
      --servicedesc=<name>          \$service.name\$ (enables service mode)
      --servicedispname=<name>      \$service.display_name\$
      --serviceoutput=<text>        \$service.output\$
      --longserviceoutput=<text>    \$service.output.full\$

Other:
  -S, --smtphost=<host>             SMTP relay (overridden by config file)
  -c, --configuration=<path>        Path to .cfg file (default: same dir, same basename)
  -t, --thruk                       (Ignored; retained for backward compatibility)
  -V, --version                     Print version
  -h, --help                        Print this help

USAGE
}

sub help {
    print_version();
    print_usage();
    print <<HELPTEXT;
This script sends Icinga2 / NetEye host and service notifications as
multipart (text + HTML) email. The HTML part uses an inline-CSS table layout
compatible with Outlook, Gmail, and other major email clients.

URL generation:
  Preferred: pass --icingaweb2url=\$notification_icingaweb2url\$ in the
             Director Notification Command. Links will use IcingaDB paths:
               /icingadb/host?name=<hostname>
               /icingadb/service?name=<svc>&host.name=<hostname>
  Fallback:  pass --nagios=<fqdn> [--ssl] to construct the base URL manually.

Configuration file:
  Must define: \$smtphost and \$logofile (see mail-html-notification.cfg).
  May define:  %NOTIFICATIONCOLOR to override built-in state/type colors.

HELPTEXT
}
