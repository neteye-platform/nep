#! /usr/bin/perl
# nagios: +epn
#
# check_alyvix3_testcases.pl - Get Monitoring Values from Alyvix3 Service API passively
#
# Copyright (C) 2020-2024 Juergen Vigna
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
# Report bugs to:  juergen.vigna@wuerth-phoenix.com
#
# Modified:
# 19/09/2023 VIJU: Adapted to Alyvix Serivice 2.3 now with /v0 API prefix
# 03/03/2023 VIJU: Support new Alyvix Service API
# 18/07/2024 VIJU: Added support for Alyvix Service v3 API
# 04/10/2024 VIJU: Fixed getting JWT Token only over a Basic-Auth URL
# 16/10/2024 VIJU: Added Report Hostname as hostname in monitoring and in Alyvix Frontend could be different
#

use strict;
use warnings;

use LWP::Simple;
use JSON;
use Data::Dumper;
use Getopt::Long;
use Date::Parse;
use HTTP::Cookies;
require HTTP::Request;
use LWP::UserAgent;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use REST::Client;
use MIME::Base64;
use URI::Encode qw( uri_encode );

my $PROGNAME = "check_alyvix3_testcases.pl";
my $VERSION  = "2.1.0";
sub print_help ();
sub print_usage ();

my @opt_verbose      = [];
my $opt_help         = undef;
my $opt_debug        = 0;
my $opt_host         = undef;
my $opt_hostname     = undef;
my $opt_masterhostname = 'icinga2-master.neteyelocal';
my $opt_reporthostname = undef;
my $opt_servicepre   = undef;
my $opt_testuser     = undef;
my $opt_timeout      = 0;
my $opt_testing      = 0;
my $opt_apiversion   = undef;
my $opt_tenant       = undef;
my $opt_apibase      = 'v0/testcases';
my $opt_proxybase    = undef;
my $opt_statedir     = "/var/spool/neteye/tmp";
my $opt_userpass     = undef;
my $opt_webuserpass  = undef;
my $opt_jwt          = 0;

# Get the options
Getopt::Long::Configure('bundling');
GetOptions(
	'h'			=> \$opt_help,
	'v'			=> \@opt_verbose,
	'verbose'		=> \@opt_verbose,
	'help'			=> \$opt_help,
	'D'			=> \$opt_debug,
	'debug'			=> \$opt_debug,
	'testing'		=> \$opt_testing,
	'H=s'			=> \$opt_host,
	'host=s'		=> \$opt_host,
	'N=s'			=> \$opt_hostname,
	'hostname=s'		=> \$opt_hostname,
	'M=s'			=> \$opt_masterhostname,
	'masterhostname=s'	=> \$opt_masterhostname,
	'R=s'			=> \$opt_reporthostname,
	'reporthostname=s'	=> \$opt_reporthostname,
	'T=s'			=> \$opt_servicepre,
	'testcasepre=s'		=> \$opt_servicepre,
	'U=s'			=> \$opt_testuser,
	'testuser=s'		=> \$opt_testuser,
	't=i'			=> \$opt_timeout,
	'timeout=i'		=> \$opt_timeout,
	'd=s'			=> \$opt_statedir,
	'statedir=s'		=> \$opt_statedir,
	'p=s'			=> \$opt_userpass,
	'userpass=s'		=> \$opt_userpass,
	'w=s'			=> \$opt_webuserpass,
	'webuserpass=s'		=> \$opt_webuserpass,
	'A=s'			=> \$opt_apibase,
	'apibase=s'		=> \$opt_apibase,
	'P=s'			=> \$opt_proxybase,
	'useproxypass=s'	=> \$opt_proxybase,
	'J'			=> \$opt_jwt,
	'usejwt'		=> \$opt_jwt,
	'V=i'			=> \$opt_apiversion,
	'apiversion=i'		=> \$opt_apiversion,
	'E=s'			=> \$opt_tenant,
	'tenant=s'		=> \$opt_tenant,
	) || print_help();

# If somebody wants the help ...
if ($opt_help) {
	print_help();
}

if (! defined($opt_host)) {
	print "ERROR: Missing Alyvix3 Server Host Name/IP (-H)!\n";
	exit 3;
}

if (! defined($opt_hostname)) {
	print "ERROR: Missing Monitoring Hostname (-N)!\n";
	exit 3;
}

if (! defined($opt_userpass)) {
	print "ERROR: Missing Icinga2 API user:password (-p)!\n";
	exit 3;
}

if (! defined($opt_webuserpass)) {
	$opt_webuserpass = $opt_userpass;
}

if (defined($opt_apiversion) && ($opt_apiversion > 1)) {
	if (! defined($opt_tenant)) {
		print "ERROR: Missing Tenant Name to check (-E)!\n";
		exit 3;
	}
}

if (! defined($opt_reporthostname)) {
	$opt_reporthostname = $opt_hostname;
}

# Global Variables
my $request_url = "https://${opt_masterhostname}:5665";
my @services;
my %testcases;
my %tenants;
my %timeouts;

# --------------------------------------------------- helper -----------------------------------------
#

sub get_testcase_status {
	my $opt_apiversion = shift;
	my $opt_host = shift;
	my $opt_testcase = shift;
	my $opt_timeout = shift;
	my $opt_hostname = shift;
	my $opt_reporthostname = shift;
	my $opt_service = shift;
	my $opt_tenant = shift;
	my $base_url = "https://${opt_host}/${opt_apibase}/${opt_testcase}";
	my $output_url = $base_url;
	if (defined($opt_proxybase)) {
		$output_url = "${opt_proxybase}/${opt_apibase}/${opt_testcase}";
	}
	my $m;
	my @measures;
	my $runCode="";
	my $id = undef;
	my $request;
	my $response;
	my $hash_content;
	my $json_content;
	my $useragent = LWP::UserAgent->new;
	$useragent->ssl_opts(
		SSL_verify_mode => SSL_VERIFY_NONE,
		verify_hostname => 0
	);

	if ($opt_apiversion) {
		if ($opt_apiversion > 1) {
			$base_url = "https://${opt_host}/v${opt_apiversion}/${opt_tenant}/testcases";
		} else {
			$base_url = "https://${opt_host}/${opt_apibase}";
		}
		if ($opt_jwt) {
			$response = $useragent->get($base_url, "Authorization" => "Bearer $opt_jwt");
		} else {
			$response = $useragent->get($base_url);
		}
        	if (!$response->is_success) {
        	        print "UNKNOWN - Could not connect to server (${base_url}) [", $response->status_line , "]\n";
        	        exit 3;
        	}
	        $hash_content = JSON::decode_json($response->content);
	        if (!defined($hash_content)) {
	                printf "UNKNOWN - cannot decode JSON string\n";
	                exit 3;
	        }
		if ($opt_debug) {
	        	printf "TESTCASES:%s\n",Data::Dumper::Dumper($hash_content);
		}
		my $t = $hash_content->{testcases};
		my @arr = @$t;
		my $size = @arr;
		my $n = 0;
		my $tname;
		while (($n < $size) && !defined($id)) {
			$tname = $arr[$n]->{name};
			if ($tname =~ /$opt_testcase/) {
				$id = $arr[$n]->{id};
			}
			$n++;
		}
		if (!defined($id)) {
			print "UNKNOWN - Testcase $opt_testcase not found";
			exit 3;
		}
		if ($opt_apiversion > 1) {
			$base_url = "https://$opt_host/v${opt_apiversion}/${opt_tenant}/testcases/" . $id;
		} else {
			$base_url = "https://$opt_host/${opt_apibase}/" . $id;
		}
	}
	if ($opt_apiversion > 1) {
		# Get Last Runcode
		if ($opt_jwt) {
			$response = $useragent->get("${base_url}/runs?page=1&pagelen=1", "Authorization" => "Bearer $opt_jwt");
		} else {
			$response = $useragent->get("$base_url}/runs?page=1&pagelen=1");
		}
		if (!$response->is_success) {
			print "UNKNOWN - Could not connect to server (${base_url}) [", $response->status_line , "]\n";
			exit 3;
		}
		if (!defined($response->content)) {
			print "UNKNOWN - cannot access Alyvix Server API ($opt_testcase)\n";
			exit 3;
		}
		$hash_content = JSON::decode_json($response->content);
		if (!defined($hash_content)) {
			printf "UNKNOWN - cannot decode JSON string ($opt_testcase)\n";
			exit 3;
		}
		if ($opt_debug) {
			printf "RUNS:%s\n",Data::Dumper::Dumper($hash_content);
		}
		if (!exists(${hash_content}->{values}[0]->{runcode})) {
			return 31;
		}
		$runCode = "/" . ${hash_content}->{values}[0]->{runcode};
	}
	# Get Last Measures
	if ($opt_jwt) {
		$response = $useragent->get("${base_url}/measures${runCode}?testcase_case_screenshot=false", "Authorization" => "Bearer $opt_jwt");
	} else {
		if ($opt_apiversion) {
			$response = $useragent->get("${base_url}/measures${runCode}?testcase_case_screenshot=false");
		} else {
			$response = $useragent->get("${base_url}/");
		}
	}

	if (!$response->is_success) {
		print "UNKNOWN - Could not connect to server (${base_url}) [", $response->status_line , "]\n";
		exit 3;
	}

	$json_content = $response->content;
	if (!defined($json_content)) {
		print "UNKNOWN - cannot access Alyvix Server API ($opt_testcase)\n";
		exit 3;
	}
	if ($opt_debug) {
		printf "%s\n", $json_content;
	}

	$hash_content = JSON::decode_json($json_content);
	if (!defined($hash_content)) {
		printf "UNKNOWN - cannot decode JSON string ($opt_testcase)\n";
		exit 3;
	}

	if ($opt_apiversion == 0) {
		$m = $hash_content->{measures};
		@measures = @$m;
	} else {
		@measures = @$hash_content;
	}
	my $URL;
	my $size = @measures;
	my $n = 0;
	my $testuser = "ALL";
	my $teststate;
	my $testduration;
	my $testcode = undef;
	my $testtime;
	my $perfout = "";
	my $perfname;
	my $perfvalue = 0;
	my $perfvalout;
	my $perfstate;
	my $perfexit;
	my $perfwarn;
	my $perfcrit;
	my $statestr = "OK";
	my $nprob = 0;
	my $ntot = 0;
	my $oldcode = "";
	my $oldstr = "OLD";
	my $now = time();
	my $probstr = "";
	my $outstr = "";
	my $verbstr = "";
	if (defined($opt_testuser)) {
		$testuser = $opt_testuser;
	}

	if ($size <= 0) {
		return 20;
	}

	my $statefile = $opt_statedir . "/alyvix3_${opt_host}_${opt_testcase}_${testuser}.state";

	if (-e $statefile) {
		open(my $fh_in, '<', $statefile)
			or die "Can't open \"$statefile\": $!\n";
		while (<$fh_in>) {
			chomp;
			$oldcode = "$_";
		}
		close($fh_in);
	}

	while($n < $size) {
		if (defined($opt_testuser)) {
			if (defined($measures[$n]->{domain_username})) {
				$testuser = $measures[$n]->{domain_username};
			} else {
				$testuser = $measures[$n]->{username};
			}
			if ($testuser ne $opt_testuser) {
				$n++;
				next;
			}
		}
		if (!defined($testcode)) {
			$testcode     = $measures[$n]->{test_case_execution_code};
			if ($opt_debug) { print "First TESTCODE: $testcode\n"; }
			$teststate    = $measures[$n]->{test_case_state};
			$testduration = $measures[$n]->{test_case_duration_ms};
			$testtime     = substr($measures[$n]->{timestamp_epoch}, 0, 10);
		} elsif ($testcode ne $measures[$n]->{test_case_execution_code}) {
			if ($opt_debug) { print "TESTCODE: $testcode" . " : " . $measures[$n]->{test_case_execution_code} . "\n"; }
			my $newtesttime = substr($measures[$n]->{timestamp_epoch}, 0, 10);
			if ($opt_debug) { print "Changed TESTCODE: $testtime < $newtesttime\n"; }
			if ($testtime > $newtesttime) {
				$n++;
				next;
			}
			# Reset all newer data available
			$perfout = "";
			$probstr = "";
			$verbstr = "";
			$ntot    = 0;
			$nprob   = 0;
			$testcode     = $measures[$n]->{test_case_execution_code};
			if ($opt_debug) { print "New TESTCODE: $testcode\n"; }
			$teststate    = $measures[$n]->{test_case_state};
			$testduration = $measures[$n]->{test_case_duration_ms};
			$testtime     = substr($measures[$n]->{timestamp_epoch}, 0, 10);
		}

		if ($measures[$n]->{transaction_name} ne $measures[$n]->{transaction_alias}) {
			$perfname  = $measures[$n]->{transaction_name} . "_" . $measures[$n]->{transaction_alias};
		} else {
			$perfname  = $measures[$n]->{transaction_name};
		}
		$perfvalue = $measures[$n]->{transaction_performance_ms};
		$perfstate = $measures[$n]->{transaction_state};
		$perfwarn  = $measures[$n]->{transaction_warning_ms};
		$perfexit = $measures[$n]->{transaction_exit};
		if (!defined($perfwarn) || $perfwarn !~ /[0-9]*/) {
			$perfwarn = "";
		}
		$perfcrit  = $measures[$n]->{transaction_critical_ms};
		if (!defined($perfcrit) || $perfcrit !~ /[0-9]*/) {
			$perfcrit = "";
		}
		if (defined($perfvalue) && $perfwarn && $perfcrit) {
			$perfout .= " ${perfname}=${perfvalue}ms;${perfwarn};${perfcrit};0;";
		}
		if ($opt_debug) { print "PERFSTATE:${perfname}->${perfstate}:\n"; }
		if ($perfwarn && $perfcrit && ($perfstate != 0) && defined($perfvalue)) {
			$ntot++;
			if ($perfstate == 1) {
				$nprob++;
				$probstr .= ",$perfname:WARNING";
			} elsif ($perfstate == 2) {
				$nprob++;
				$probstr .= ",$perfname:CRITICAL";
			} else {
				$nprob++;
				$probstr .= ",$perfname:UNKNOWN";
			}
		} elsif ($perfexit =~ /fail/) {
			$nprob++;
			$probstr .= ",$perfname:FAIL";
		} elsif ($perfwarn && $perfcrit) {
			$ntot++;
		}
		if ($#opt_verbose) {
			my $pv;
			if (defined($perfvalue)) {
				$pv = $perfvalue;
			} else {
				$pv = "[n/a]";
			}
			if ($perfwarn && $perfcrit) {
				$perfvalout = "${pv}ms/$perfwarn/$perfcrit";
			} else {
				$perfvalout = "${pv}ms";
			}
			if (($#opt_verbose > 1) || ($perfwarn && $perfcrit)) {
				if ($perfstate == 0) {
					$verbstr .= "OK - $perfname ($perfvalout)\n";
				} elsif ($perfstate == 1) {
					$verbstr .= "WARNING - $perfname ($perfvalout)\n";
				} elsif ($perfstate == 2) {
					$verbstr .= "CRITICAL - $perfname ($perfvalout)\n";
				} else {
					$verbstr .= "UNKNOWN - $perfname ($perfvalout)";
				}
			}
		}
		$n++;
	}

	if (!defined($testcode)) {
		$teststate = 3;
		$outstr = "UNKNOWN - Could not find any performace data for the testcase $opt_testcase!";
		$verbstr = "";
		passive_set_service($opt_hostname, $opt_service, $teststate, $outstr, $verbstr, "");
		return 3;
	}

	if ($teststate == 1) {
		$statestr = "WARNING";
	} elsif ($teststate == 2) {
		$statestr = "CRITICAL";
	} elsif ($teststate > 2) {
		$statestr = "UNKNOWN";
	}

	if ($opt_timeout > 0) {
		my $timediff = $now - $testtime;
		if ($timediff > $opt_timeout) {
			if ($opt_debug) {
				print "TIMEOUT $timediff > $opt_timeout\n";
			}
			$statestr = "UNKNOWN";
			$teststate = 3;
			$oldcode = $testcode;
			$oldstr = "TIMEOUT";
		}
	}

	if ($opt_apiversion == 0) {
		$URL = "${output_url}/reports/?runcode=${testcode}";
	} else {
		$URL = "/neteye/alyvix/testcases?nodeName=${opt_reporthostname}&testcaseId=${id}&tab=reports&runcode=${testcode}";
	}
	my $testtimestr = scalar localtime $testtime;
	if ($opt_debug) {
		print "$testcode -> $oldcode\n";
	}
	if ($opt_testing) {
		print "${statestr} - $nprob/$ntot problem(s)${probstr} (Last Run: $testtimestr) (<a href='${URL}' target='_blank'>Log</a>) | duration=${testduration}ms;;;0;${perfout}\n";
		if ($#opt_verbose) {
			print "$verbstr";
		}
	} elsif ($testcode ne $oldcode) {
		$outstr="${statestr} - $nprob problem(s)${probstr} (Last Run: $testtimestr) (<a href='${URL}' target='_blank'>Log</a>)";
		passive_set_service($opt_hostname, $opt_service, $teststate, $outstr, $verbstr, "duration=${testduration}ms;;;0;${perfout}");
		open(my $fh_out, '>', $statefile)
			or die "Can't create \"$statefile\": $!\n";
		print($fh_out "${testcode}\n");
		close($fh_out);
	} elsif ($oldstr eq "TIMEOUT") {
		$outstr="${statestr} - $nprob problem(s)${probstr} [$oldstr] (Last Run: $testtimestr) (<a href='${URL}' target='_blank'>Log</a>)\n";
		passive_set_service($opt_hostname, $opt_service,$teststate, $outstr, $verbstr, "");
	} else {
		$teststate += 10;
	}
	return $teststate;
}

sub get_alyvix_services {
	my $hostname   = shift;
	my $servicepre = shift;

	my $client = REST::Client->new();
	$client->setHost($request_url);
	$client->getUseragent()->ssl_opts(verify_hostname => 0);
	#$client->setCa("/neteye/shared/monitoring/data/root-ca.crt");
	$client->addHeader("Accept", "application/json");
	$client->addHeader("X-HTTP-Method-Override", "GET");
	$client->addHeader("Authorization", "Basic " . encode_base64($opt_userpass));
	my %json_data;
	if (defined $servicepre) {
		%json_data = (
			filter => "host.name==\"$hostname\" && match(\"$servicepre*\",service.name)",
		);
	} else {
		%json_data = (
			filter => "host.name==\"$hostname\"",
		);
	}
	my $data = encode_json(\%json_data);
	$client->POST("/v1/objects/services", $data);

	my $status = $client->responseCode();
	my $response = $client->responseContent();
	if ($status != 200) {
	        print "UNKNOWN: Cannot get Services -> Error: " . $response . "\n";
		exit 3;
	}
	my $hash_content = JSON::decode_json($response);
	if (!defined($hash_content)) {
		printf "UNKNOWN - cannot decode JSON string for Services\n";
		exit 3;
	}
	my $m = $hash_content->{results};
	my @results = @$m;
	my $size = @results;
	if (!@results) {
		if (defined $servicepre) {
			printf "UNKNOWN - No Alyvix Services found on Host '$hostname' with prefix '$servicepre'\n";
		} else {
			printf "UNKNOWN - No Alyvix Services found on Host '$hostname'\n";
		}
		exit 3;
	}
	my $n = 0;
	foreach my $service ( @results ) {
		if (!defined($service->{attrs}->{vars}->{alyvix_testcase_name})) {
			next;
		}
		if ($opt_debug) {
			print $service->{attrs}->{name} . ":" . $service->{attrs}->{vars}->{alyvix_testcase_name} . "\n";
		}
		$services[$n]  = $service->{attrs}->{name};
		$testcases{$service->{attrs}->{name}} = $service->{attrs}->{vars}->{alyvix_testcase_name};
		if (defined($service->{attrs}->{vars}->{alyvix_timeout})) {
			$timeouts{$service->{attrs}->{name}} = $service->{attrs}->{vars}->{alyvix_timeout};
		} else {
			$timeouts{$service->{attrs}->{name}} = $opt_timeout;
		}
		if (defined($service->{attrs}->{vars}->{alyvix_tenant})) {
			$tenants{$service->{attrs}->{name}} = $service->{attrs}->{vars}->{alyvix_tenant};
		} else {
			$tenants{$service->{attrs}->{name}} = $opt_tenant;
		}
		if ($opt_debug) {
			print "Timeout: " . $timeouts{$service->{attrs}->{name}} . "\n";
			print "Tenant: " . $tenants{$service->{attrs}->{name}} . "\n";
		}
		$n++;
	}
}

sub passive_set_service {
	my $HOSTNAME = shift;
	my $SERVICE  = shift;
	my $state    = shift;
	my $outstr   = shift;
	my $verbstr  = shift;
	my $perfstr  = shift;

	my $client = REST::Client->new();
	$client->setHost($request_url);
	$client->getUseragent()->ssl_opts(verify_hostname => 0);
	#$client->setCa("pki/icinga2-ca.crt");
	$client->addHeader("Accept", "application/json");
	$client->addHeader("X-HTTP-Method-Override", "POST");
	$client->addHeader("Authorization", "Basic " . encode_base64($opt_userpass));
	my $thost = `hostname`;
	chomp $thost;
		#pretty => 'true',
	my $pout;
	if (defined($verbstr)) {
		$pout = "$outstr\n$verbstr";
	} else {
		$pout = "$outstr";
	}
	my %json_data = (
		type => 'Service',
		filter => "host.name==\"$HOSTNAME\" && service.name==\"$SERVICE\"",
		exit_status => $state,
		plugin_output => "$pout",
		check_source => "$thost",
		performance_data => $perfstr,
	);
	my $data = encode_json(\%json_data);
	$client->POST("/v1/actions/process-check-result", $data);

	my $status = $client->responseCode();
	my $response = $client->responseContent();
	if ($status != 200) {
	        print "UNKNOWN: Cannot set Service in PassiveMode -> Error: ($status)" . $response . "\n";
		exit 3;
	}
}

sub print_help() {
	printf "%s, Version %s\n",$PROGNAME, $VERSION;
	print "Copyright (c) 2020-2023 Juergen Vigna\n";
	print "This program is licensed under the terms of the\n";
	print "GNU General Public License\n(check source code for details)\n";
	print "\n";
	printf "Get monitoring results for a Testcase from Alyvix3 Server\n";
	print "\n";
	print_usage();
	print "\n";
	print " -V (--version)     Programm version\n";
	print " -h (--help)        usage help\n";
	print " -v (--verbose)     verbose output\n";
	print " -D (--debug)       debug output\n";
	print " -H (--host)        Alyvix3 Server hostname/ip\n";
	print " -N (--hostname)    Alyvix3 Monitoring Hostname\n";
	print " -M (--masterhostname) Icinga2 Master/Web Hostname for API and Web access\n";
	print " -R (--reporthostname) Hostname inside the Alyvix Frontend for Report URL\n";
	print " -U (--testuser)    Alyvix3 Testcase user (default: ALL_USERS)\n";
	print " -t (--timeout)     Alyvix3 Testcase values older then timeout gives UNKNOWN (default: $opt_timeout)\n";
	print " -d (--statedir)    Directory where to write the statefiles (default: $opt_statedir)\n";
	print " -p (--userpass)    User:Password for Icinga2 API access\n";
	print " -w (--webuserpass) User:Password for Icinga2 Web access (default: <userpass> of -p)\n";
	print " -A (--apibase)     Alyvix3 Server API BaseURL (default: $opt_apibase)\n";
	print " -P (--proxypass)   The Output Url to access logs uses a proxypass (ONLY for OLD API)\n";
	print " -J (--usejwt)      Use and get the JWT Token from the Neteye Webinterface\n";
	print " -V (--apiversion)  Alyvix Service version (0,1,2,3) (default: discovered but only 1 or 2)\n";
	print " -E (--tenant)      Alyvix Testcase Tenant, must have if APIVERSION=3\n";
	print "\n";
	exit 0;
}

sub print_usage() {
	print "Usage: \n";
	print "  $PROGNAME (-H|--host <hostname/ip>) (-N|--hostname <host.name>) (-p|--userpass <user:pass>) [-U|--testuser <user>] [-t|--timeout <int>] [-d|--statedir <dir>] [-w|--webuserpass <user:pass>] [-A|--apibase <apibase>] [-P|--proxypass <proxy-pre>] [-M|--masterhostname <hostname>] [-R|--reporthostname <hostname>] [-J] [-V <APIVERSION>] [-E <tenant>]\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
}

sub get_api_version {
	my $opt_host = shift;

	my $base_url = "https://${opt_host}";
	my $useragent = LWP::UserAgent->new;
	$useragent->ssl_opts(
		SSL_verify_mode => SSL_VERIFY_NONE,
		verify_hostname => 0
	);
	my $request = HTTP::Request->new('GET', $base_url);
	my $response = $useragent->request($request);

	if (!defined($response->content)) {
		print "UNKNOWN - Could not connect to alyvix server (${base_url}) [", $response->status_line , "]\n";
		exit 3;
	}

	if ($response->content =~ /token is missing/) {
		return 1;
	}
	$opt_jwt=0;
	return 0;
}

sub get_jwt_token {
	my $opt_apiversion = shift;
	my $opt_host = shift;
	my $opt_user = shift;
	my $opt_password = shift;

	my $base_url = "https://${opt_host}";
	my $ua = new LWP::UserAgent();
	$ua->ssl_opts(
		SSL_verify_mode => SSL_VERIFY_NONE,
		verify_hostname => 0
	);
	my $URL;
	my $response;

	#
	# JWT Request
	#

	if ($opt_apiversion > 1) {
		$URL = ${base_url} . "/neteye/alyvix/jwt-v1";
	} else {
		$URL = ${base_url} . "/neteye/api/v1/jwt";
	}
	$response = $ua->get($URL,
		'Host' => ${opt_host},
		'Accept' => 'application/json',
		'X-HTTP-Method-Override' => 'GET',
		'Authorization' => "Basic " . encode_base64("$opt_user:$opt_password"));
	if (!defined($response->content)) {
		print "UNKNOWN - Could not connect to NetEye Web (${base_url}) [", $response->status_line , "]\n";
		exit 3;
	}

	my $json_content = JSON::decode_json($response->content);
	if (!defined($json_content->{token})) {
		print "UNKNOWN - Could get JWT Token [", $response->status_line , "]\n";
		exit 3;
	}
	return $json_content->{token};
}

#
# ------------------------------------------ START MAIN --------------------------------------------
#

if (!defined($opt_apiversion)) {
	$opt_apiversion = get_api_version($opt_host);
}
if ($opt_apiversion > 0) {
	if (! defined($opt_hostname)) {
		print "ERROR: Missing Alyvix Server Hostname (-N)!\n";
		exit 3;
	}
	if (! defined($opt_masterhostname)) {
		print "ERROR: Missing NetEye Server Hostname (-M)!\n";
		exit 3;
	}

	if ($opt_jwt) {
		my @cred = split ":", $opt_webuserpass;
		my $u = $cred[0];
		my $p = $cred[1];
		$opt_jwt = get_jwt_token($opt_apiversion, $opt_masterhostname, $u, $p);
		if ($#opt_verbose > 1) {
			print "JWTTOKEN=$opt_jwt\n";
		}
	}
}
get_alyvix_services($opt_hostname, $opt_servicepre);
my $n = 0;
my $outstr = "";
my @statestr = ( "OK", "WARNING", "CRITICAL", "UNKNOWN" );

foreach my $service ( sort @services ) {
	my $state = get_testcase_status($opt_apiversion, $opt_host, $testcases{$service}, $timeouts{$service}, $opt_hostname, $opt_reporthostname, $service, $tenants{$service});
	if ($state >= 30) {
		$state = 3;
		$outstr .= "[" . $statestr[$state] . "]\t{NO REPORTS} $service\n";
	} elsif ($state >= 20) {
		$state = 3;
		$outstr .= "[" . $statestr[$state] . "]\t{DISABLED} $service\n";
	} elsif ($state >= 10) {
		$state -= 10;
		$outstr .= "[" . $statestr[$state] . "]\t(OLD) $service\n";
	} else {
		$outstr .= "[" . $statestr[$state] . "]\t$service\n";
	}
	$n++;
}

if (defined $opt_servicepre) {
	print "OK - Run all Alyvix '$opt_servicepre' services\n$outstr";
} else {
	print "OK - Run all Alyvix services\n$outstr";
}
exit 0;
