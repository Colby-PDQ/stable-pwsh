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
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]    
    [int32]
    $Days = 30,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ServerHostName = "PDQSERVER"
)

$Time = (Get-Date).Adddays(- $Days)

$CustomFieldName1 = "Last Update Check Older Than $Days Days"
$CustomFieldName2 = "Last Update Installed Over $Days Days Ago"

$CheckedDate   = Get-WULastScanSuccessDate
$InstalledDate = Get-WULastInstallationDate

[array]$CustomInfo = "Computer Name,$CustomFieldName1,$CustomFieldName2"

$Checked   = $CheckedDate   -lt $Time
$Installed = $InstalledDate -lt $Time

$CustomInfo += "$env:COMPUTERNAME,$Checked,$Installed"

Invoke-Command -ComputerName $ServerHostName -ScriptBlock { 
    $TempFile = New-TemporaryFile
    $Using:CustomInfo | Out-File $TempFile
    PDQInventory ImportCustomFields -FileName $TempFile.FullName -AllowOverwrite
}