<#
.SYNOPSIS
    Use the PSWindowsUpdate Powershell module to update 2 custom fields in PDQ Inventory (Last update check/Last update installed)
.DESCRIPTION
    Update check and install times are not reported within Windows anywhere that is easily found. The closest option is the date(s) of the last installed hotfix, which is inaccurate at best.
    Using the PSWindowsUpdate Powershell module, we are able to leverage it to update custom fields in Inventory - fields which can then be used as filters and reported on.
.EXAMPLE
    I have typically had this as a Tool in Inventory that I could run on-demand as needed (as well as remove possible conflicts with how Inventory handles running scripts vs how Deploy does it),
    but there is no reason you could not create a package in Deploy and schedule it if desired. Just be sure to test thoroughly.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    The default timeframe is simply 30 days (with checks for < and >). Change that to any timeframe you wish.
    The CustomFieldName(s) need to match what you named your fields exactly - I would recommend copy/pasting from Inventory into here.
    
    In this example the Custom Fields were created as a True/False (checkbox) type. If you want to use another type (integer for example),
    you'll need to change $Checked and $Installed to be set to your desired data type.

#>

$Days = 30
$time = (Get-Date).Adddays( - ($Days))

$CustomFieldName1 = "Last Update Check older than 30 days"
$CustomFieldName2 = "Last Update Installed Over 30 Days Ago"
$ComputerName = $env:COMPUTERNAME

$CheckedDate = Get-WULastScanSuccessDate
$InstalledDate = Get-WULastInstallationDate

[array]$CustomInfo = "Computer Name,$CustomFieldName1,$CustomFieldName2"

$Checked = $CheckedDate -lt $time
$Installed = $InstalledDate -lt $time

$CustomInfo += "$ComputerName,$Checked,$Installed"

Invoke-Command -ComputerName PDQSERVER -ScriptBlock { 
    ($TempFile = New-TemporaryFile) 
    ($Using:CustomInfo | Out-File $TempFile) 
    (PDQInventory ImportCustomFields -FileName $TempFile.FullName -AllowOverwrite) }