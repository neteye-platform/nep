# Notification Email

The `nep-notification-email` adds to the Notification Facility provided with `nep-notification-base` the ability to send Notifications by email, in two channels:

- **E-Mail (HTML)** — branded multipart (text + HTML) email with an embedded logo, state-coloured banner, a 2-column detail table and a "View in NetEye" button linking to IcingaDB.
- **E-Mail (text)** — plain-text only email produced from the same script, for gateways or clients that cannot render HTML.

Both channels are produced by a single Perl script, `mail-html-notification.pl`; the channel is selected per Director command via the `--format` argument (`html` is the default, `text` is set explicitly by the text commands).

# Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Packet Contents](#packet-contents)
4. [Configuration](#configuration)
5. [Usage](#usage)

## Prerequisites

This package can be installed on systems running the software described below. Systems with equivalent components are also suitable for installation.

| Software | Version |
| --- | ----------- |
| NetEye | 4.44+ |
| nep-common | 0.5.6+ |
| nep-notification-base | 0.0.6+ |

##### Required NetEye Modules

| NetEye Module |
| --- |
| Core |

### External dependencies

The setup script `pre/install_perl_dependencies.sh` installs the following from EPEL:

- `perl-Mail-Sendmail`

EPEL must be configured on every cluster node on which Icinga2 executes notifications.

## Installation

### NEP Installation

To set up the package `nep-notification-email`, use the Setup Utility:

```
nep-setup install nep-notification-email
```

After the installation is complete, you can use the objects and configure the NEP.

#### Finalizing Installation

After installation, deploy the Director configuration so that the imported commands and notification objects become active:

```
icingacli director config deploy
```

## Packet Contents

This `nep-notification-email` does not provide any object that the End User must create manually. All objects are created automatically after the current Director configuration is deployed.

### Director/Icinga Objects

The package contains the following Director objects.

#### Notification Templates

| Object Name | Channel | Containing File |
| --- | --- | --- |
| nx-nt-channel-html-email | HTML | conf.d/nx-notification-basic-html-email.conf |
| nx-nt-channel-html-email-for-host | HTML | conf.d/nx-notification-basic-html-email.conf |
| nx-nt-channel-html-email-for-service | HTML | conf.d/nx-notification-basic-html-email.conf |
| nx-nt-channel-text-email | text | conf.d/nx-notification-basic-text-email.conf |
| nx-nt-channel-text-email-for-host | text | conf.d/nx-notification-basic-text-email.conf |
| nx-nt-channel-text-email-for-service | text | conf.d/nx-notification-basic-text-email.conf |

#### Notification Apply Rules

| Object Name | Applies To | Containing File |
| --- | --- | --- |
| nx-n-basic-html-email-to-users-from-host | Host | conf.d/nx-notification-basic-html-email.conf |
| nx-n-basic-html-email-to-groups-from-host | Host | conf.d/nx-notification-basic-html-email.conf |
| nx-n-basic-html-email-to-users-from-service | Service | conf.d/nx-notification-basic-html-email.conf |
| nx-n-basic-html-email-to-groups-from-service | Service | conf.d/nx-notification-basic-html-email.conf |
| nx-n-basic-text-email-to-users-from-host | Host | conf.d/nx-notification-basic-text-email.conf |
| nx-n-basic-text-email-to-groups-from-host | Host | conf.d/nx-notification-basic-text-email.conf |
| nx-n-basic-text-email-to-users-from-service | Service | conf.d/nx-notification-basic-text-email.conf |
| nx-n-basic-text-email-to-groups-from-service | Service | conf.d/nx-notification-basic-text-email.conf |

#### Commands

All four commands invoke the same script. The text commands additionally pass `--format text`.

| Icinga Command | Script |
| --- | --- |
| nx-c-mail-html-host-notification | /neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.pl |
| nx-c-mail-html-service-notification | /neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.pl |
| nx-c-mail-text-host-notification | /neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.pl |
| nx-c-mail-text-service-notification | /neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.pl |

#### User Templates

| User Template name | Description |
| --- | --- |
| nx-ut-html-email | User template for the HTML channel. Carries `nx_mail_http_config_file` (path to the `.cfg`). |
| nx-ut-text-email | User template for the text channel, created by `post/add_user_template.sh`. |

#### Data Fields

The command basket defines the following Director Data Fields, associated with the four commands so they appear as Custom Properties when the commands are used:

| Data Field (varname) | Caption | Used for |
| --- | --- | --- |
| notification_from | [NX] Notification sender (From) | Sender address (`--mail_sender`) |
| nx_neteye_web_interface_fqdn | [NX] NetEye Web Interface FQDN | Base FQDN for IcingaDB links (`-N`) |
| nx_mail_gateway | [NX] Mail gateway (SMTP relay) | SMTP relay override (`-S`) |
| nx_mail_http_config_file | [NX] Mail HTTP config file | Per-user `.cfg` path (`-c`) |

### Constants

The setup script `pre/define_email_constants.sh` defines the following Icinga2 constants in a dedicated file `conf.d/nx-constants-notification-email.conf`. The standard notification template chain sources the notification variables from these constants.

| Constant | Default value | Notification variable it feeds |
| --- | --- | --- |
| NxEmailNotificationFrom | icinga@&lt;neteye-hostname&gt; | notification_from |
| NxEmailNotificationMaster | &lt;neteye-hostname&gt; | nx_neteye_web_interface_fqdn |
| NxEmailNotificationGateway | 127.0.0.1 | nx_mail_gateway |

### Channels

The setup script `pre/add_channel_to_list.sh` registers the channels in the notification channel list:

| Key | Name |
| --- | --- |
| html-email | E-Mail (HTML) |
| text-email | E-Mail (text) |

## Configuration

### Configuration file

The `.cfg` file is generated once at install time by `pre/add_default_config_file.sh` and is **never overwritten on upgrade**, so administrator changes are preserved.

Location: `/neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.cfg`

| Variable | Required | Notes |
| --- | --- | --- |
| `$smtphost` | Yes | SMTP relay hostname or IP. Must be reachable from all cluster nodes. Default `127.0.0.1`. |
| `$logofile` | No | Absolute path to a PNG/JPG/GIF logo embedded in HTML mail. If missing, the logo cell is omitted. Default `/usr/share/icingaweb2/public/img/neteye/neteye-logo.png`. |
| `%NOTIFICATIONCOLOR` | No | Optional override map for the built-in state/notification-type colours. |

### Notification variable flow

The three notification variables `notification_from`, `nx_neteye_web_interface_fqdn` and `nx_mail_gateway` reach the command arguments in one of two ways:

- **Standard NEP flow (automatic):** the conf-file notification templates (`nx-nt-channel-html-email`, `nx-nt-channel-text-email`) set these variables from the constants above. Any notification that imports the template chain — including the NEP apply rules — inherits them automatically. No Director configuration is required.
- **Custom notification template flow (manual):** when an administrator creates a custom notification template that does **not** import the NEP conf-file template chain, the variables are not inherited. In that case the administrator must set them as Custom Properties on the notification template (the Data Fields above make them available as named fields). At minimum `notification_from` must be set, otherwise the email has no `From` address and the send fails.

## Usage

### Manual script test (as the icinga user)

```
perl /neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.pl \
  -c /neteye/shared/icinga2/conf/icinga2/scripts/mail-html-notification.cfg \
  --notificationtype="PROBLEM" \
  --hostname="test-host.example.com" \
  --hostalias="Test Host" \
  --hostaddress="192.168.1.1" \
  --state="DOWN" \
  --datetime="$(date '+%Y-%m-%d %H:%M:%S %z')" \
  --mail_sender="monitoring@example.com" \
  -r "recipient@example.com" \
  -N "neteye.example.com" --ssl
```

For the text channel, add `--format text`.
