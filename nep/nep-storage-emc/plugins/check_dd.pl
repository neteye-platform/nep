#!/usr/bin/perl -w

# Copyright (c) 2006 Dy 4 Systems Inc.
#
# based on code by Christoph Kron and S. Ghosh (check_ifstatus)
#
# Modified by pierre.gremaud@bluewin.ch JAN 2008
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#



use strict;
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Net::SNMP;
use Getopt::Long;
use File::Basename;
Getopt::Long::Configure('bundling');

my $PROGNAME = 'check_dd.pl';
my $PROGREVISION = '1.0';

sub print_help ();
sub usage ();
sub process_arguments ();

my ($status,$timeout,$answer,$perfdata,$hostname,$volume);
my ($seclevel,$authproto,$secname,$authpass,$privpass,$snmp_version);
my ($auth,$priv,$session,$error,$response,$snmpoid,$variable);
my ($warning,$critical,$opt_h,$opt_V);
my %snmpresponse;

my $state = 'UNKNOWN';
my $community='public';
my $maxmsgsize = 1472; # Net::SNMP default is 1472
my $port = 161;

my $snmpfileSystemSpaceEntry = '.1.3.6.1.4.1.19746.1.3.2.1.1';
my $snmpfileSystemResourceName = '.1.3.6.1.4.1.19746.1.3.2.1.1.2';
my $snmpfileSystemPercentUsed = '.1.3.6.1.4.1.19746.1.3.2.1.1.6';
my $snmpcurrentAlertEntry = '.1.3.6.1.4.1.19746.1.4.1.1.1';
my $snmpcurrentAlertDescription = '.1.3.6.1.4.1.19746.1.4.1.1.1.3';


# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
	print "ERROR: No snmp response from $hostname (alarm timeout)\n";
	exit $ERRORS{'UNKNOWN'};
};

$status = process_arguments();
if ( $status != 0 ) {
	print_help();
	exit $ERRORS{'OK'};
}

alarm($timeout);

# do the query
# if querying for alerts, then table could be not defined
if ( $variable eq 'ALERTS' ) {
  if ( ! defined ( $response = $session->get_table($snmpoid) ) ) {
	$answer='No Alerts Found';
	$session->close;
	$state = 'OK';
	print "$variable $state - $answer\n";
	exit $ERRORS{$state};
  }
}
# if querying another table, then table should be defined

elsif ( ! defined ( $response = $session->get_table($snmpoid) ) ) {
	$answer=$session->error;
	$session->close;
	$state = 'CRITICAL';
	print "$state:$answer for $snmpoid with snmp version $snmp_version\n";
	exit $ERRORS{$state};
}

$session->close;
alarm(0);

foreach my $snmpkey (keys %{$response} ) {
	my ($oid,$key) = ( $snmpkey =~ /(.*)\.(\d+)$/ );
	$snmpresponse{$oid}{$key} = $response->{$snmpkey};
}

if ( $variable eq 'ALERTS' ) {
	$state = 'WARNING';
	foreach my $key ( keys %{$snmpresponse{$snmpcurrentAlertDescription}} ) {

		my $alert = $snmpresponse{$snmpcurrentAlertDescription}{$key};
		$answer .= "$alert ";
		$perfdata = '';

	}
}



if ( $variable eq 'DISKUSED' ) {
	$state = 'OK';
	foreach my $key ( keys %{$snmpresponse{$snmpfileSystemResourceName}} ) {
		if ( defined $volume ) {
			if ( $snmpresponse{$snmpfileSystemResourceName}{$key} eq $volume ) {
				my $volume = $snmpresponse{$snmpfileSystemResourceName}{$key};
				my $volume_name = basename($volume);
 				# my $used = $snmpresponse{$snmpfilesysdfTabledfEntrydfKBytesUsed}{$key};
				# my $total = $snmpresponse{$snmpfilesysdfTabledfEntrydfKBytesTotal}{$key};
				# my $avail = $snmpresponse{$snmpfilesysdfTabledfEntrydfKBytesAvail}{$key};
				my $percent = $snmpresponse{$snmpfileSystemPercentUsed}{$key};
				$answer = sprintf("%s:%d%% ",$volume,$percent);
				$perfdata = sprintf("'$volume_name'=%d ",$percent);
				$state = 'WARNING' if ( ( defined $warning ) && ( $percent >= $warning ) );
				$state = 'CRITICAL' if ( ( defined $warning ) && ( $percent >= $critical ) );
				last;
			}
		} else {
			my $volume = $snmpresponse{$snmpfileSystemResourceName}{$key};
			my $volume_name = basename($volume);
			# my $used = $snmpresponse{$snmpfilesysdfTabledfEntrydfKBytesUsed}{$key};
			# my $total = $snmpresponse{$snmpfilesysdfTabledfEntrydfKBytesTotal}{$key};
			# my $avail = $snmpresponse{$snmpfilesysdfTabledfEntrydfKBytesAvail}{$key};
			my $percent = $snmpresponse{$snmpfileSystemPercentUsed}{$key};
			$answer .= sprintf("%s:%d%% ",$volume,$percent);
			$perfdata .= sprintf("'$volume_name'=%d ",$percent);
			$state = 'WARNING' if ( ( defined $warning ) && ( $percent >= $warning ) && ( $state ne 'CRITICAL') );
			$state = 'CRITICAL' if ( ( defined $warning ) && ( $percent >= $critical ) );
		}
	}
	if ( ( ! defined $answer ) && ( defined $volume ) ) {
		$state = 'UNKNOWN';
		$answer = "unknown volume: $volume";
		$perfdata = '';
	}
}


print "$variable $state - $answer|$perfdata\n";
exit $ERRORS{$state};

sub usage () {
	print "\nMissing arguments!\n\n";
	print "check_dd.pl -H <ip_address> -v variable [-w warn_range] [-c crit_range]\n";
	print "             [-C community] [-t timeout] [-p port-number]\n";
	print "              -v DISKUSED - disk space used\n";
	print "              -v ALERTS - print current alerts\n";
	exit $ERRORS{'UNKNOWN'};
}

sub print_help () {
	print "check_dd plugin for Nagios monitors the status\n";
	print "of a DataDaomain Appliance like DD430\n\n";
	print "Usage:\n";
	print "  -H, --hostname\n\thostname to query (required)\n";
	print "  -C, --community\n\tSNMP read community (defaults to public)\n";
	print "  -t, --timeout\n\tseconds before the plugin tims out (default=$TIMEOUT)\n";
	print "  -p, --port\n\tSNMP port (default 161\n";
	print "  -P, --snmp_version\n\t1 for SNMP v1 (default), 2 for SNMP v2c\n\t\t3 for SNMP v3 (requires -U)\n";
	print "  -L, --seclevel\n\tchoice of \"noAuthNoPriv\", \"authNoPriv\", \"authpriv\"\n";
	print "  -U, --secname\n\tuser name for SNMPv3 context\n";
	print "  -a, --authproto\n\tauthentication protocol (MD5 or SHA1)\n";
	print "  -A, --authpass\n\tauthentication password\n";
	print "  -X, --privpass\n\tprivacy password in hex with 0x prefix generated by snmpkey\n";
	print "  -V, --version\n\tplugin version\n";
	print "  -w, --warning\n\twarning level\n";
	print "  -c, --critical\n\tcritical level\n";
	print "  -v, --variable\n\tvariable to query, can be:\n";
	print "\t\tDISKUSED - disk space used\n";
	print "\t\tALERTS - print current alerts\n";
	print "  -o, --volume\n\tvolume to query (defaults to all)\n";
	print "  -h, --help\n\tusage help\n\n";
	print_revision($PROGNAME,"\$Revision: 1.2 $PROGREVISION\$");
}

sub process_arguments () {
	$status = GetOptions (
		'V' => \$opt_V, 'version' => \$opt_V,
		'h' => \$opt_h, 'help' => \$opt_h,
		'P=i' => \$snmp_version, 'snmp_version=i' => \$snmp_version,
		'C=s' => \$community, 'community=s' => \$community,
		'L=s' => \$seclevel, 'seclevel=s' => \$seclevel,
		'a=s' => \$authproto, 'authproto=s' => \$authproto,
		'U=s' => \$secname, 'secname=s' => \$secname,
		'A=s' => \$authpass, 'authpass=s' => \$authpass,
		'X=s' => \$privpass, 'privpass=s' => \$privpass,
		'H=s' => \$hostname, 'hostname=s' => \$hostname,
		't=i' => \$timeout, 'timeout=i' => \$timeout,
		'v=s' => \$variable, 'variable=s' => \$variable,
		'w=i' => \$warning, 'warning=i' => \$warning,
		'c=i' => \$critical, 'critical=i' => \$critical,
		'o=s' => \$volume, 'volume=s' => \$volume,
	);

	if ( $status == 0 ) {
		print_help();
		exit $ERRORS{'OK'};
	}

	if ( $opt_V ) {
		print_revision($PROGNAME,"\$Revision: 1.0 $PROGREVISION\$");
		exit $ERRORS{'OK'};
	}

	if ( ! utils::is_hostname($hostname) ) {
		usage();
		exit $ERRORS{'UNKNOWN'};
	}

	unless ( defined $timeout ) {
		$timeout = $TIMEOUT;
	}

	if ( ! $snmp_version ) {
		$snmp_version = 1;
	}

	if ( $snmp_version =~ /3/ ) {
		if ( defined $seclevel && defined $secname ) {
			unless ( $seclevel eq ('noAuthNoPriv' || 'authNopriv' || 'authPriv' ) ) {
				usage();
				exit $ERRORS{'UNKNOWN'};
			}

			if ( $seclevel eq ('authNoPriv' || 'authPriv' ) ) {
				unless ( $authproto eq ('MD5' || 'SHA1') ) {
					usage();
					exit $ERRORS{'UNKNOWN'};
				}
				if ( ! defined $authpass ) {
					usage();
					exit $ERRORS{'UNKNOWN'};
				} else {
					if ( $authpass =~ /^0x/ ) {
						$auth = "-authkey => $authpass";
					} else {
						$auth = "-authpassword => $authpass";
					}
				}
			}

			if ( $seclevel eq 'authPriv' ) {
				if ( ! defined $privpass ) {
					usage();
					exit $ERRORS{'UNKNOWN'};
				} else {
					if ( $privpass -~ /^0x/ ) {
						$priv = "-privkey => $privpass";
					} else {
						$priv = "-privpassword => $privpass";
					}
				}
			}
		} else {
			usage();
			exit $ERRORS{'UNKNOWN'};
		}
	}

	# create the SNMP session
	if ( $snmp_version =~ /[12]/ ) {
		($session,$error) = Net::SNMP->session(
					-hostname => $hostname,
					-community => $community,
					-port => $port,
					-version => $snmp_version,
		);
		if ( ! defined $session ) {
			$state = 'UNKNOWN';
			$answer = $error;
			print "$state:$answer";
			exit $ERRORS{$state};
		}
	} elsif ( $snmp_version  =~ /3/ ) {
		if ( $seclevel eq 'noAuthNoPriv' ) {
			($session,$error) = Net::SNMP->session(
						-hostname => $hostname,
						-community => $community,
						-port => $port,
						-version => $snmp_version,
						-username => $secname,
			);
		} elsif ( $seclevel eq 'authNoPriv' ) {
			($session,$error) = Net::SNMP->session(
						-hostname => $hostname,
						-community => $community,
						-port => $port,
						-version => $snmp_version,
						-username => $secname,
						-authprotocol => $authproto,
						$auth
			);
		} elsif ( $seclevel eq 'authPriv' ) {
			($session,$error) = Net::SNMP->session(
						-hostname => $hostname,
						-community => $community,
						-port => $port,
						-version => $snmp_version,
						-username => $secname,
						-authprotocol => $authproto,
						$auth,
						$priv
			);
		}
		if ( ! defined $session ) {
			$state = 'UNKNOWN';
			$answer = $error;
			print "$state:$answer";
			exit $ERRORS{$state};
		}
	} else {
		$state = 'UNKNOWN';
		print "$state: No support for SNMP v$snmp_version\n";
		exit $ERRORS{$state};
	}

	# check the supported variables
	if ( ! defined $variable ) {
		print_help();
		exit $ERRORS{'UNKNOWN'};
	} else {
		if ( $variable eq 'DISKUSED' ) {
			$snmpoid = $snmpfileSystemSpaceEntry;
		}
		elsif ( $variable eq 'ALERTS' ) {
			$snmpoid = $snmpcurrentAlertEntry;
		} else {
			print_help();
			exit $ERRORS{'UNKNOWN'};
		}
	}

	return $ERRORS{'OK'};
}
