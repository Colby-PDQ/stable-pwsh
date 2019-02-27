Start-Transcript "Update members of AD group.txt" -NoClobber -Append -Force

# Get the account name for each user in the selected group (Identity)
$ADMember = Get-ADGroupMember -Identity "All Administrators" -Recursive | Select-Object -ExpandProperty SamAccountName

# Using the results from $ADMember, filter through all computer objects in AD that match the name in any way
# and pull out the "sAMAccountName" ()
$ADComp = foreach ($member in $ADMember) {
    Get-ADComputer -Filter "Name -like '*$member*'" | Select-Object -ExpandProperty sAMAccountName
}

foreach ($comp in $ADComp) {
    # Add each computer in $ADComp to _All Admin Computers distribution group
    Add-ADGroupMember -Identity "_All Admin Computers" -Members "$comp" #-WhatIf
    # Set the 'extensionAttribute1` attribute to "DND" (Do Not Disable)
    Set-ADComputer -Identity "$comp" -Replace @{extensionAttribute1="DND"} #-WhatIf
    }

Stop-Transcript