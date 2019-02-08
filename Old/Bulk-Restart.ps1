<#
# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator 

# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))

   {

   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host

   }

else

   {

   # We are not running "as Administrator" - so relaunch as administrator
   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";

   # Specify the current script path and name as a parameter
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;

   # Indicate that the process should be elevated
   $newProcess.Verb = "runas"; 

   # Start the new process
   [System.Diagnostics.Process]::Start($newProcess);

   # Exit from the current, unelevated, process
   exit

   }
#>

#Set Execution policy
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

#Filter results by string. Add the * wildcard unless you need a specific match
Write-Host "Enter search string. If searching for multiple computers, use the '*' wildcard"
$search = Read-Host "Search string: "

#Perform the search
$cn = Get-ADComputer -Filter "name -Like '$search'"
Get-ADComputer -Filter "name -Like '$search'" | Select -ExpandProperty Name | Out-GridView

#Get Domain admin credentials
$creds = Get-Credential -Message 'Enter your credentials...'

#Confirm the name change.
$Go=Read-Host -prompt "Proceed with computer restart? (Y / N)"

#Perform the replacement
If($Go -eq "Y") {
    ForEach ($comp in $cn) {
        #If a computer does not respond within 3 attempts, move on to the next one in the list
        if (Test-Connection -ComputerName $comp.name -Count 3 -Quiet) {
            Rename-Computer -ComputerName $comp.name -NewName ($comp.name -Replace "$search","$replace") -DomainCredential $creds -Force -Restart #-WhatIf
        }
    }
}
Read-Host "Done."