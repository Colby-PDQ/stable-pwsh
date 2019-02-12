# Set Execution Policy if needed.
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
Clear-Host

# Logging.
Start-Transcript -Path C:\Logs\Rename.txt -Force -NoClobber -Append
Clear-Host

$Creds = $null
# Set $CUser to the currently logged-on user.
$CUser = [System.Security.Principal.WindowsIdentity]::GetCurrent() | select -ExpandProperty Name

while ($null -eq $Creds) {
    Write-Warning "Domain credentials are required."

    if (([Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Domain Admins")) { 
        Write-Host "Currently logged in with a domain admin account"
        $Creds = Get-Credential -Username "$CUser" -Message "Enter Password for $CUser"
    }
    else {
        Write-Host "Currently logged in with a non-domain admin account"
        # Update $CUser here to match your admin naming scheme, if you have one.
        $Creds = Get-Credential -Username "$CUser" -Message "Enter Password for $CUser"
    }
}
Clear-Host

$Confirm = $null

while ($Confirm -ne "y") {
    #Collects the name of the computer to be changed. 
    Write-Host ""
    $DestComputer = Read-Host -Prompt "Enter the name of the computer you want to change the name of: "
    Write-host "Current computer name: " $DestComputer

    # Collect the new name for the computer.
    Write-Host ""
    $NewName = Read-Host -Prompt "Please enter the computer name you want to use "
    
    # Confirm the name change.
    Write-Host ""
    Write-host "Current computer name: " $DestComputer
    Write-host "New Computer Name: " $NewName
    Write-Host ""
    $Confirm = Read-Host -prompt "Are these names correct? (y/n)"
}

# Rename the destination computer
Write-Host ""
Rename-Computer -ComputerName $DestComputer -NewName $NewName -DomainCredential  $Creds -Force
Write-Host ""
        
# Prompts for whether or not you want to restart the renamed computer immediately.
Write-Host -ForegroundColor Yellow "A restart is required to finish renaming. Issues will occur if too much time passes without a restart."
$Reboot = Read-host -Prompt "Do you want to restart the computer? (y/n)"
Write-Host ""
        
If ($Reboot -eq "y") {
    Restart-Computer -ComputerName $DestComputer -Credential $Creds -Force
}
elseif ($Reboot -eq "n") {
    Write-Host -ForegroundColor Yellow "Remember to restart the computer within the next 10-15 minutes to avoid possible communication issues!"
}

# Stop logging
Stop-Transcript