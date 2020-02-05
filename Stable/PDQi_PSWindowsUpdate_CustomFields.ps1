<#
.SYNOPSIS
    Use the PSWindowsUpdate PowerShell module to update 2 Custom Fields in PDQ Inventory (Last update check/Last update installed).
.DESCRIPTION
    Update check and install times are not reported within Windows anywhere that is easily found. The closest option is the date(s) of the last installed hotfix, which is inaccurate at best.
    Using the PSWindowsUpdate PowerShell module, we are able to leverage it to update Custom Fields in Inventory - fields which can then be used as filters and reported on.
.PARAMETER Days
    The number of days since the last update check and last installed update that you want as your threshold.
    Defaults to 30.
.PARAMETER ServerHostName
    The hostname of the computer that you have PDQ Inventory installed on. This script will use Invoke-Command to connect to the specificed hostname.
    Defaults to "PDQSERVER".
.PARAMETER CustomFieldLastUpdateCheck
    The name of the Custom Field that stores whether or not the number of days since the last time the target checked for updates is greater than the number of days specified by -Days.
    Defaults to "Last Update Check Older Than $Days Days".
.PARAMETER CustomFieldLastUpdateInstalled
    The name of the Custom Field that stores whether or not the number of days since the last time the target installed updates is greater than the number of days specified by -Days.
    Defaults to "Last Update Installed Over $Days Days Ago".
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

[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]    
    [int32]
    $Days = 30,

    [ValidateNotNullOrEmpty()]
    [string]
    $ServerHostName = "PDQSERVER",

    [ValidateNotNullOrEmpty()]
    [string]
    $CustomFieldLastUpdateCheck = "Last Update Check Older Than $Days Days",

    [ValidateNotNullOrEmpty()]
    [string]
    $CustomFieldLastUpdateInstalled = "Last Update Installed Over $Days Days Ago"
)

$Time = (Get-Date).Adddays(- $Days)

$CheckedDate   = Get-WULastScanSuccessDate
$InstalledDate = Get-WULastInstallationDate

[array]$CustomInfo = "Computer Name,$CustomFieldLastUpdateCheck,$CustomFieldLastUpdateInstalled"

$Checked   = $CheckedDate   -lt $Time
$Installed = $InstalledDate -lt $Time

$CustomInfo += "$env:COMPUTERNAME,$Checked,$Installed"

Invoke-Command -ComputerName $ServerHostName -ScriptBlock { 
    $TempFile = New-TemporaryFile
    $Using:CustomInfo | Out-File $TempFile
    PDQInventory ImportCustomFields -FileName $TempFile.FullName -AllowOverwrite
}