# Test Mailbox Database Health
#
# This script will look at all mailbox databases
# and determine the status of each.
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
# Originally created by Jeff Roberson (jeffrey.roberson@gmail.com)
# at Bethel College, North Newton, KS
#
# Revision History
# 5/10/2010	Jeff Roberson		Creation
#
# To execute from within NSClient++
#
#[NRPE Handlers]
#check_mailbox_health=cmd /c echo C:\Scripts\Nagios\MailboxHealth.ps1 | PowerShell.exe -Command -
#
# On the check_nrpe command include the -t 20, since it takes some time to load
# the Exchange cmdlet's.

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
$Outputlb = ""
$Outputval = ""
$OutputStatus = 0

$NagiosStatus = "0"
$NagiosDescription = ""

ForEach ($DataBase in Get-MailboxDatabase -Server $env:computername) {
$Server = $env:computername
$Name = $DataBase.Name
$Identity = "$Name\$Server"
	ForEach ($Status in Get-MailboxDatabaseCopyStatus -Identity $Identity) {
		switch ($Status.Status) {
			"Failed" {
				$NagiosStatus = "2"
				$OutputStatus = 2

				if ($NagiosDescription -ne "") {
					$NagiosDescription = $NagiosDescription + ", "
				}
				$NagiosDescription = $NagiosDescription + $Status.Name + " is " + $Status.Status
			}

			"Dismounted" {
				$NagiosStatus = "2"
				$OutputStatus = 2
				if ($NagiosDescription -ne "") {
					$NagiosDescription = $NagiosDescription + ", "
				}
				$NagiosDescription = $NagiosDescription + $Status.Name + " is " + $Status.Status
			}

			"Resynchronizing" {
				if ($NagiosStatus -ne "2") {
					$NagiosStatus = "1"
					$OutputStatus = 1
				}
				if ($NagiosDescription -ne "") {
					$NagiosDescription = $NagiosDescription + ", "
				}
				$NagiosDescription = $NagiosDescription + $Status.Name + " is " + $Status.Status
			}

			"Suspended" {
				if ($NagiosStatus -ne "2") {
					$NagiosStatus = "1"
					$OutputStatus = 1
				}
				if ($NagiosDescription -ne "") {
					$NagiosDescription = $NagiosDescription + ", "
				}
				$NagiosDescription = $NagiosDescription + $Status.Name + " is " + $Status.Status
			}

			"Mounting" {
				if ($NagiosStatus -ne "2") {
					$NagiosStatus = "1"
					$OutputStatus = 1
				}
				if ($NagiosDescription -ne "") {
					$NagiosDescription = $NagiosDescription + ", "
				}
				$NagiosDescription = $NagiosDescription + $Status.Name + " is " + $Status.Status
			}
			"Mounted" {
				if (($NagiosStatus -ne "2") -or ($NagiosStatus -ne "1")) {
					$NagiosStatus = "0"
					$OutputStatus = 0
				}
				if ($NagiosDescription -ne "") {
					$NagiosDescription = $NagiosDescription + ", "
				}
				$NagiosDescription = $NagiosDescription + $Status.Name + " is " + $Status.Status
			}
			"Healthy" {
				if (($NagiosStatus -ne "2") -or ($NagiosStatus -ne "1")) {
					$NagiosStatus = "0"
					$OutputStatus = 0
				}
				if ($NagiosDescription -ne "") {
					$NagiosDescription = $NagiosDescription + ", "
				}
				$NagiosDescription = $NagiosDescription + $Status.Name + " is " + $Status.Status
			}

#			"Healthy" {}
#			"Mounted" {}
		}

	$Outputchk = $Status.DatabaseName
if ($outputval -eq "") {
$outputval = "'$Outputchk'=$OutputStatus;1;2"
}
else {
$outputval = $outputval + " '$Outputchk'=$OutputStatus;1;2"
}



	}
}

# Output, what level should we tell our caller?
if ($NagiosStatus -eq "2") {
	$outputlb =  "CRITICAL: " + $NagiosDescription
#	Write-Host "CRITICAL: " $NagiosDescription
} elseif ($NagiosStatus -eq "1") {
	$outputlb =  "WARNING: " + $NagiosDescription
#	Write-Host "WARNING: " $NagiosDescription
} else {
	$outputlb =  "OK: All Mailbox Databases are mounted and healthy."
#	Write-Host "OK: All Mailbox Databases are mounted and healthy."
}
$output = "$outputlb|$outputval"
$output

exit $NagiosStatus
