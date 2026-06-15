# Nagios Exchange 2010 Backup Monitoring Script
# Author: Andy Grogan
# Version 1.0
# www.telnetport25.com
# ----------------------------------------
# Compatibility:
# ----------------------------------------
# Nagios Version: 3.x
# Exchange Version: 2010
# Powershell Version: 2.0
# NSClient++ Version: 3.x
# ----------------------------------------

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
#$localServerName = Get-WmiObject -Class Win32_ComputerSystem | Select Name
#$localServerName = $env:computername
$Outputlb = ""
$Outputval = ""
$OutputStatus = 0
$NagiosDescription = ""
$ThreshHold = 8
$ThreshHoldCritical = 9
$Results = Get-MailboxDatabase -Server $env:computername -Status | Select Identity,Server,LastFullBackup,LastIncrementalBackup | where {$_.Server -eq $env:computername}

foreach($itm in $Results){

		if($itm -eq $null){
			$Output = "OK: No Databases are active on this host"
			$NagiosResult = 0
		}else{
			if($itm.LastFullBackup -eq $null){
				$lastBackupSeed = 9999
				$Outputchk = $ThreshHoldCritical

			}else{
				$lastBackupSeed = New-TimeSpan $($itm.LastFullBackup) $(Get-Date)
				if ($itm.LastIncrementalBackup -ne $null){
					$lastIncrementalSeed = New-TimeSpan $($itm.LastIncrementalBackup) $(Get-Date)
				}
				$Outputchk = $lastBackupSeed.days
			}
			if($lastBackupSeed.days -gt $ThreshHold -or $lastBackupSeed -eq 9999){
				if (($lastIncrementalSeed.Days -gt $ThreshHold) -and ((get-date).DayOfWeek -eq "Monday"))   {
					$Res = "CRITICAL: Database Backup out of Schedule: " + $itm.Identity
					$Output += $Res + " "
					$statFlag = 1
					}
				else{
					$Res = "WARNING: Database Backup out of Schedule: " + $itm.Identity
					$Output += $Res + " "
					$statFlag = 1
					}
			}else{
				$Output += "OK: Database: " + $itm.identity + " has a recent backup" + " "
			}
				if ($NagiosDescription -ne "")
					{
					$NagiosDescription = $NagiosDescription + ", "
					}
					$NagiosDescription = $NagiosDescription + $itm.Identity

		}
#$Outputchk = $lastBackupSeed.days
$Outputlb = $itm.Identity
if ($outputval -eq "") {
$outputval = "'$Outputlb'=$Outputchk;$ThreshHold;$ThreshHoldCritical"
}
else {
$outputval = $outputval + " '$Outputlb'=$Outputchk;$ThreshHold;$ThreshHoldCritical"
}

}
#Write-Host $Output
if($statFlag -eq 1){
	$NagiosStatus = 0
	$NagiosDescription = "OK: All Databases have a recent Copybackup. $output"
	}
elseif($statFlag -eq 2){
	$NagiosStatus = 1
	$NagiosDescription = "WARNING: Database Backup out of Schedule! $output"
#	$NagiosDescription = $Res
}
else{
	$NagiosDescription =  "OK: All Databases have a recent Fullbackup. $output"
	$NagiosStatus = 0
}
$output = "$NagiosDescription | $outputval"
$output
exit $NagiosStatus
