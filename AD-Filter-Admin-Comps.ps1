# Get the account name for each user in the selected group (Identity)
$ADMember = Get-ADGroupMember -Identity "All Administrators" -Recursive | Select-Object -ExpandProperty SamAccountName

# Using the results from $ADMember, filter through all computer objects in AD that match the name in any way
# and pull out the "sAMAccountName"
$ADComp = foreach ($member in $ADMember) {
    Get-ADComputer -Filter "Name -like '*$member*'" -Properties Name, extensionAttribute1 | Select-Object -ExpandProperty sAMAccountName
}

$GroupMembers = Get-ADGroupMember -Identity '_All Admin Computers'
$MissingComps = foreach ($Comp in $ADComp) {
    if ($Comp -notin $GroupMembers.SamAccountName) {
        $Comp
        Write-Host -ForegroundColor Red "$comp will be added."
        
    }
    else {
        Write-Host -ForegroundColor Green "$comp is already a member of the targeted group - skipping"
    }
}

# Add each computer in $ADComp to _All Admin Computers distribution group
Add-ADGroupMember -Identity "_All Admin Computers" -Members $MissingComps -WhatIf

# Set the 'extensionAttribute1` attribute to "DND" (Do Not Disable)
$MissingComps | Set-ADComputer -Replace @{extensionAttribute1 = "DND"} -WhatIf

Read-Host "Press enter to exit"