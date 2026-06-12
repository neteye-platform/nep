#! /usr/bin/perl
#
# (c)2011 Luca Di Stefano, Wuerth Phoenix s.r.l.
# (c)2012-2013 Juergen Vigna, Wuerth Phoenix s.r.l.
# send bug reports to <luca.distefano@wuerth-phoenix.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
#
# Checks smstools log for get the current state of modem (network registration and signal strength)
#
# Usage:
#
#

##NEW SMSTOOLS LOG
#
# gives strength and registration out of the box
#
#2011-03-16 10:42:33,6, GSM1: Signal Strength Indicator: (27,0) -59 dBm (Excellent), Bit Error Rate: less than 0.2 %
# o sulla versione piu vecchia
#2011-03-16 10:42:33,6, GSM1: Signal Strength Indicator: (27,0) -59 dBm, Bit Error Rate: less than 0.2 %
#2011-03-16 10:42:33,6, GSM1: Checking if Modem is registered to the network
#2011-03-16 10:42:34,6, GSM1: Modem is registered to the network
#2011-03-16 10:42:34,6, GSM1: Selecting PDU mode
#2011-03-16 10:42:34,6, GSM1: Checking memory size
#2011-03-16 10:42:35,6, GSM1: Used memory is 0 of 50
#2011-03-16 10:42:35,6, GSM1: No SMS received
#2011-03-16 10:42:45,6, GSM1: Checking device for incoming SMS
#2011-03-16 10:42:45,6, GSM1: Checking if modem is ready
#2011-03-16 10:42:45,6, GSM1: Pre-initializing modem

##OLD SMSTOOLS LOG
#
# add in /etc/smsd.conf
# regular_run_interval = 60
# regular_run_cmd = AT+CREG?;+CSQ;+COPS?
#
#2011-03-24 14:17:56,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 12,0 +COPS: 0,2,22201 OK
#2011-03-24 14:19:17,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 12,0 +COPS: 0,2,22201 OK
#2011-03-24 14:20:34,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 11,3 +COPS: 0,2,22201 OK
#2011-03-24 14:21:44,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 10,0 +COPS: 0,2,22201 OK
#2011-03-24 14:23:04,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 10,0 +COPS: 0,2,22201 OK
#2011-03-24 14:24:23,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 10,0 +COPS: 0,2,22201 OK
#2011-03-24 14:25:46,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 11,0 +COPS: 0,2,22201 OK
#2011-03-24 14:26:55,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 10,0 +COPS: 0,2,22201 OK
#2011-03-24 14:28:31,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 11,0 +COPS: 0,2,22201 OK
#2011-03-24 14:30:48,5, GSM1: CMD: AT+CREG?;+CSQ;+COPS?: +CREG: 0,1 +CSQ: 12,0 +COPS: 0,2,22201 OK


use strict;
use Getopt::Long;
use IO::File;
use Monitoring::Plugin qw(%ERRORS);

my $PROGNAME = "check_modem_smst";
my $version  = "1.4.2";

## utility subroutines

sub print_revision ($$) {
        my $commandName    = shift;
        my $pluginRevision = shift;
        print "$commandName v$pluginRevision (monitoring-plugins 1.4.15)\n";
        print
"This monitoring plugins come with ABSOLUTELY NO WARRANTY. You may redistribute\ncopies of the plugins under the terms of the GNU General Public License.\nFor more information about these matters, see the file named COPYING.\n";
}

sub support () {
        my $support =
'Send email on neteye-blog.it if you have questions\nregarding use of this software.\nPlease include version information with all correspondence (when possible,\nuse output from the --version option of the plugin itself).\n';
        $support =~ s/@/\@/g;
        $support =~ s/\\n/\n/g;
        print $support;
}

sub usage {
        my $format = shift;
        printf( $format, @_ );
        exit $ERRORS{'UNKNOWN'};
}

##------------------------------------------------------------------##

sub print_usage () {
        print "Usage: $PROGNAME [-f <file>] [-t <timeframe>] [-s <expected-signal-strength>] [-S <search-string>] [-b <buffer-size>]\n";
}

sub print_help () {
        print( $PROGNAME, $version );
        print "Copyright (c) 2011 Luca Di Stefano, Wuerth Phoenix s.r.l.
This plugin checks smstools log for get the current state
 of modem (network registration and signal strength).
";
        print_usage();
        print "
-f,--file <file>
  smstools log file (default: /var/log/smstools.log)
-w <expected-signal-strength>
   expected signal strength, if the detected strength is less than the given value
   the script gives warning (default: 8)
-c <expected-signal-strength>
   expected signal strength, if the detected strength is less than the given value
   the script gives critical (default: 0)
-b, --buffer <chars>
   How many chars of the log are read from the tail value should be a negative one! (default: -100000)
-d,--device <device-name>
   If you want to check for a defined device f.ex.: GSM1
-t,--timerange <minutes>
   How many minutes you want to go back in time for checking the logfile (default: 5).
";
        support();
}

###################################################################################

$ENV{'PATH'}     = '';
$ENV{'BASH_ENV'} = '';
$ENV{'ENV'}      = '';

my ( $show_version, $show_help, $opt_S );
my ( $seekpos, $timerange, $log, $critical_signal, $warn_signal, $device, $debug, $verbose );

Getopt::Long::Configure('bundling');
GetOptions(
        "V|version"   => \$show_version,
        "h|help|?"    => \$show_help,
        "c|csignal=s" => \$critical_signal,
        "w|wsignal=s" => \$warn_signal,
        "f|file=s"    => \$log,
        "d|device=s"  => \$device,
        "b|bytes=s"   => \$seekpos,
        "t|timerange=s"   => \$timerange,
        "D|debug"     => \$debug,
        "v|verbose"   => \$verbose
) or die;

if ($show_version) {
        print_revision( $PROGNAME, $version );
        exit 2;
}

if ($show_help) { print_help(); exit 2; }

##-------------------------------------------------------------------##

#setting defaults

($log)        || ( $log        = "/var/log/smstools.log" );
($seekpos)    || ( $seekpos    = -100000 );
if ($seekpos > 0) {
        $seekpos = -$seekpos;
}
($critical_signal) || ( $critical_signal = 0 );
($timerange) || ($timerange = 5);
($warn_signal) || ($warn_signal = 8);

##-------------------------------------------------------------------##
#getting current datetime
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
my ( $line, $pattern, $state, $signal, $signal_dbm, $stext, $registered, $quality );
my $tflag = 0;

if (($min - $timerange) < 0) {
        my $t1 = time;
        my $t2 = $t1 - ($timerange * 60);
        my ( $sec1, $min1, $hour1, $mday1, $mon1, $year1, $wday1, $yday1, $isdst1 ) = localtime($t2);
        $pattern = sprintf( "%4d-%02d-%02d (%02d:%02d", $year1 + 1900, $mon1 + 1, $mday1, $hour1, $min1);
        $min1++;
        while ( $min1 < 60) {
                $pattern .= sprintf("|%02d:%02d", $hour1, $min1);
                $min1++;
        }
        $pattern .= sprintf( ")|%4d-%02d-%02d (%02d:00", $year + 1900, $mon + 1, $mday, $hour);
        $timerange=$timerange + ($min - $timerange);
        $tflag = 1;
} else {
        $pattern = sprintf( "%4d-%02d-%02d (%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min - $timerange);
}

my $omin = $min+1;
while ( $omin-$timerange <= $min) {
        $pattern .= sprintf("|%02d:%02d", $hour, $omin-$timerange);
        $omin++;
}
$pattern .= ")";

#TODO device
#$pattern = "2011-03-24 15:(20|21):";
#$log     = "/home/luca/Downloads/grep_sms.log";

#$pattern = "2011-03-16 13:(38|39":";
#$pattern = "2011-03-03 09:(00):";

if ($device) {
        #2011-03-24 14:51:25,5, GSM1:
        $pattern = $pattern . ":\\d{1,2},\\d, " . $device;
}

#parse the log
open( FILE, $log );
seek( FILE, $seekpos, 2 );

$stext      = "Unknown";
$signal     = 0;
$registered = 0;
$quality = 0;
my $outtxt = "";

while ( $line = <FILE> ) {
        #filtering the selected time period
        if ( $line =~ /^($pattern):/ ) {
                if ($debug) {
                        print "$line\n";
                }
                if ($line =~ /Checking if Modem is registered to the network/ ) {
                        # ignore this lines!!!
                #check if modem is registered to gsm network
                } elsif ($registered && $line =~ /Modem handler 0 has started/ ) {
                        if ($debug || $verbose) {
                                $outtxt.=$line;
                        }
                        $registered = 0;
                } elsif (!$registered && $line =~ /Modem is registered to the network/ ) {
                        if ($debug || $verbose) {
                                $outtxt.=$line;
                        }
                        $registered = 1;
                # check for the signal strenght and also for registration
                } elsif ($line =~ /Signal Strength Indicator: \((\d{1,2}),\d+\) \-\d+ dBm/ ) {
                        if ($debug || $verbose) {
                                $outtxt.=$line;
                        }
                        #check the signal strength
                        my ($b) = $line =~ m/Signal Strength Indicator: \((\d{1,2}),\d+\) \-\d+ dBm/;
                        # CSQ = 99 means there is no signal at all!!!
                        if ($b && ($b > $signal) && ($b != 99)) {
                                $signal = $b;
                                $signal_dbm = -113;
                                $signal_dbm += $signal * 2;
                                if ($signal_dbm > -75) {
                                        $stext="Excellent";
                                } elsif ($signal_dbm > -85) {
                                        $stext="Good";
                                } elsif ($signal_dbm > -95) {
                                        $stext = "Workable";
                                } elsif ($signal_dbm > -110) {
                                        $stext = "Marginal";
                                } else {
                                        $stext = "Too Low";
                                }
                        }
                } elsif ($line =~ /AT\+CREG\?;\+CSQ;\+COPS\?: \+CREG: \d,(\d).* \+CSQ: (\d{1,2}),\d{1,2}/ ) {
                        if ($debug || $verbose) {
                                $outtxt.=$line;
                        }
                        #this is the same control of above if the following run command is enabled
                        #regular_run_cmd = AT+CREG?;+CSQ;+COPS?
                        #we are *NOT* interested at the moment in the COPS output
                        my ( $a, $b ) = $line =~ m/AT\+CREG\?;\+CSQ;\+COPS\?: \+CREG: \d,(\d).* \+CSQ: (\d{1,2}),\d{1,2}/;
                        $registered = $a if ($a);
                        # CSQ = 99 means there is no signal at all!!!
                        if ($b && ($b > $signal) && ($b != 99)) {
                                $signal = $b;
                                $signal_dbm = -113;
                                $signal_dbm += $signal * 2;
                                if ($signal_dbm > -75) {
                                        $stext="Excellent";
                                } elsif ($signal_dbm > -85) {
                                        $stext="Good";
                                } elsif ($signal_dbm > -95) {
                                        $stext = "Workable";
                                } elsif ($signal_dbm > -110) {
                                        $stext = "Marginal";
                                } else {
                                        $stext = "Too Low";
                                }
                        }
                } elsif ($debug) {
                        print "$line\n";
                }
        }
}

close(FILE);

my $state_text='UNKNOWN';
#check signal strength constraint and registration ( 1 = home network, 5 = roaming )
if ( $signal < $critical_signal || ( $registered != 1 && $registered != 5 ) ) {
        $state_text='CRITICAL';
}
else {
        if ( $signal < $warn_signal ) {
                $state_text='WARNING';
        } else {
                $state_text='OK';
        }
}
$state = $ERRORS{ $state_text };

if ( $stext eq "Unknown" ) {
        print $state_text . " - State " . $state . " registered " . $registered . " signal " . $signal . "|signal=$signal;$warn_signal;$critical_signal;0;30\n";
} else {
        print $state_text . " - State " . $state . " registered " . $registered . " signal " . $signal . " (" . $stext . ")|signal=$signal;$warn_signal;$critical_signal;0;30\n";
}

if ($debug) {
        print $pattern. "\n";
        print "Log "
          . $log
          . " seek "
          . $seekpos
          . " device "
          . $device
          . " min sig "
          . $critical_signal
          . " warn sig "
          . $warn_signal . "\n";
}

if ($debug || $verbose) {
        print $outtxt;
}
exit $state;
