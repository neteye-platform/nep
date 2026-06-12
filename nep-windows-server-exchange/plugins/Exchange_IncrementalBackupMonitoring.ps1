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
$ThreshHold = 5
$ThreshHoldCritical = 6

$Results = Get-MailboxDatabase -Server $env:computername -Status | Select Identity,Server,LastIncrementalBackup,LastFullBackup,LastCopyBackup | where {$_.Server -eq $env:computername}

foreach($itm in $Results){

		if($itm -eq $null){
			$Output = "OK: No Databases are active on this host"
			$NagiosResult = 0
		}else{
			if($itm.LastIncrementalBackup -eq $null){
				$lastBackupSeed = 9999
				$Outputchk = 0

			}else{
				$lastBackupSeed = New-TimeSpan $($itm.LastIncrementalBackup) $(Get-Date)
				$Outputchk = $lastBackupSeed.days
			}
#			if($lastBackupSeed.days -gt $ThreshHold -or $lastBackupSeed -eq 9999){
			if($lastBackupSeed.days -gt $ThreshHold){
				$Res = "CRITICAL: Database Backup out of Schedule: " + $itm.Identity
				$Output += $Res + " "
				$statFlag = 2
			}elseif($lastBackupSeed -eq 9999){

				$lastFullBackupSeed =  New-TimeSpan $($itm.LastFullBackup) $(Get-Date)
				$lastCopyBackupSeed =  New-TimeSpan $($itm.LastCopyBackup) $(Get-Date)

				if (($lastFullBackupSeed.days -eq 0) -or ($lastCopyBackupSeed.days -eq 0))  {

#				if ((get-date).DayOfWeek -eq "Monday"){
				$Res = "Warning: No incremental Database Backup: " + $itm.Identity
				$Output += $Res + " "
				$statFlag = 3
				}
			else { #if ($lastBackupSeed.days -lt $ThreshHold){
				$Res = "Warning: No incremental Database Backup: " + $itm.Identity
				$Output += $Res + " "
				$statFlag = 4
				}
			}else{
				$Output += "OK: Database: " + $itm.identity + " has a recent backup" + " "
				$statFlag = 0

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
if($statFlag -eq 2){
	$NagiosStatus = 1
	$NagiosDescription =  "WARNING: Database incrementalbackup out of Schedule."
}#	$NagiosDescription =  $Res
elseif($statFlag -eq 3){
	$NagiosStatus = 0
	$NagiosDescription =  "OK: Fullbackup today - no incremental Database Backup."
}
elseif($statFlag -eq 4){
	$NagiosStatus = 0
	$NagiosDescription =  "OK: No ncremental Database Backup, but lower then threshhold."
}
elseif($statFlag -eq 1){
	$NagiosStatus = 1
	$NagiosDescription =  "WARNING: No incremental Database Backup."
#	$NagiosDescription =  $Res
}
else{
	$NagiosStatus = 0
	$NagiosDescription =  "OK: All Databases have a recent incrementalbackup."
}
$output = "$NagiosDescription|$outputval"
$output
exit $NagiosStatus