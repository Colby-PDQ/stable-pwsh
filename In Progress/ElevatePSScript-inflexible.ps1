#Elevates the script if it was not run from an Administrative Powershell instance.

#If script is run locally, the line below can be used instead of the method starting on line 6
#$MyFileName = "$PSScriptRoot\******.ps1"

#This method allows for running this script (and associated scripts) from a UNC path
$currentDirectory = Get-Location
$currentDrive = Split-Path -qualifier $currentDirectory.Path
$logicalDisk = Gwmi Win32_LogicalDisk -filter "DriveType = 4 AND DeviceID = '$currentDrive'"
$UNC = $currentDirectory.Path.Replace($currentDrive, $logicalDisk.ProviderName)

$MyFileName = "$UNC\******.ps1"

Clear-Host

if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Running as an Administrator."
    Start-Process powershell -ArgumentList "-File $MyFileName"
}
else {
    Write-Output "Restarting script as an Administrator"
    Start-Process powershell -ArgumentList "-File $MyFileName" -verb RunAs
    exit
}