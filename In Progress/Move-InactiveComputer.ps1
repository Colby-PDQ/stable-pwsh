# Enable basic logging
Start-Transcript -Path "C:\Logs\Move-Inactive.txt" -Force -NoClobber -Append
Clear-Host

# Gets time stamps for all computers in the domain that have NOT logged in since after specified date
import-module activedirectory

#Set the target time
$DaysInactive = 45
$time = (Get-Date).Adddays( - ($DaysInactive))
 
# Get all AD computers with lastLogonTimestamp ($DaysInactive) less than the current day.
# Example filters are included - change/add/remove as needed.
$ADPull = Get-ADComputer -Filter {
    LastLogonTimeStamp -lt $time -and
    OperatingSystem -notlike '*server*' -and
    Name -notlike '*ESX*' -and
    Name -notlike '*server*' -and
    Enabled -eq $True

} -Properties LastLogonTimeStamp,extensionAttribute1 | Where-Object {$_.extensionAttribute1 -ne 'DND'}

# Display results of the filter for verification
$ADPull | Select-Object -ExpandProperty Name | Out-GridView
$confirm = Read-Host -Prompt "Proceed? (y/n)"

if ($confirm -eq "y") {
    foreach ($comp in $ADPull) {
        # Disable each computer before moving it.
        Set-ADComputer -Identity $comp -Enabled $false -WhatIf
        Move-ADObject -Identity $comp.DistinguishedName -TargetPath "OU=Computers,DC=contoso,DC=com" -WhatIf
    }
}

Write-Host ""
Read-Host -Prompt "Press any key to exit"

#Stop logging
Stop-Transcript