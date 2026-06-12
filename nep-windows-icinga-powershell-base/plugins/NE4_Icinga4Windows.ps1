#----------install framework---------------
#must have internet access
    [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11';
    $ProgressPreference                         = 'SilentlyContinue';
    [string]$ScriptFile                         = 'C:\temp\IcingaForWindows.ps1';

    Invoke-WebRequest `
        -UseBasicParsing `
        -Uri 'https://packages.icinga.com/IcingaForWindows/IcingaForWindows.ps1' `
        -OutFile ( New-Item -Path $ScriptFile -Force);

    & $ScriptFile `
        -ModuleDirectory 'C:\Program Files\WindowsPowerShell\Modules\' `
        -AllowUpdate `
        -SkipWizard;
#------------Add repo-----------------------
Add-IcingaRepository `
    -Name 'Icinga Stable' `
    -RemotePath 'https://packages.icinga.com/IcingaForWindows/stable/ifw.repo.json';
#------------Add Plugins---------------------
Install-IcingaComponent -Name 'plugins' -Version '1.8.0' -Force -Confirm;
