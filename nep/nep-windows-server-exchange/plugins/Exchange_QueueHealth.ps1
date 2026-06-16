# Test Queue Health
#
# This script will look at each queue and determine the status of each.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Originally created by Joshua Kirkes (joshua@awesomejar.com)
# at AwesomeJar Consulting, LLC in San Francisco, CA
#
# Revision History
# 5/23/2011	Joshua Kirkes		Created
# 7/7/2011	Marc Koene		Revision
#
# To execute from within NSClient++
#
#[NRPE Handlers]
#check_queue_health=cmd /c echo C:\Scripts\Nagios\QueueHealth.ps1 | PowerShell.exe -Command -
#
# On the check_nrpe command include the -t 30, since it takes some time to load the Exchange cmdlet's.

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

$Outputlb = ""
$Outputval = ""

$NagiosStatus = "0"
$NagiosDescription = ""
$maxQueue = 0
$ComputerName =  gc env:computername

#ForEach ($Server in Get-ExchangeServer) {
$Server = Get-ExchangeServer $ComputerName
	if ($Server.ServerRole -like "*Mailbox*") {
#	if ($Server.ServerRole -like "*Hub*") {
		ForEach ($Queue in Get-Queue -Server $Server) {
$Queue.Identity.Type
$Queue.MessageCount
 	# Look for lagged queues - critical if over 20
	if ($Queue.MessageCount -gt "80" ) {
		# Format the output for Nagios
		if ($NagiosDescription -ne "") 	{
			$NagiosDescription = $NagiosDescription + ", " 	}
			$NagiosDescription = $NagiosDescription + $Queue.Identity + " queue has " + $Queue.MessageCount + " messages to " + $Queue.NextHopDomain

		# Set the status to failed.
		$NagiosStatus = "2"

	# Look for lagged queues - warning if over 10
	} elseif ($Queue.MessageCount -gt "60") {
		# Format the output for Nagios
		if ($NagiosDescription -ne "") 	{
			$NagiosDescription = $NagiosDescription + ", " 	}
			$NagiosDescription = $NagiosDescription + $Queue.Identity + " queue has " + $Queue.MessageCount + " messages to " + $Queue.NextHopDomain

	# Don't lower the status level if we already have a critical event
	if ($NagiosStatus -ne "2") {
			$NagiosStatus = "1" }
		}
if ($Queue.MessageCount -gt $maxQueue){
$maxQueue = $Queue.MessageCount
}
	}
}
#}

if ($outputval -eq "") {
$outputval = "'Status'=1;2;3 'Max Queue'=$maxQueue;60;80"
}
else {
$outputval = $outputval + " 'Status'=1;2;3 'Max Queue'=$maxQueue;60;80"
}
# Output, what level should we tell our caller?
if ($NagiosStatus -eq "2") {
	$outputlb =  "CRITICAL: " + $NagiosDescription
#	Write-Host "CRITICAL: " $NagiosDescription
} elseif ($NagiosStatus -eq "1") {
	$outputlb =  "WARNING: " + $NagiosDescription
#	Write-Host "WARNING: " $NagiosDescription
} else {
	$outputlb =  "OK: All mail queues within limits."
#	Write-Host "OK: All mail queues within limits."
}
$output = "$outputlb|$outputval"
$output
exit $NagiosStatus

