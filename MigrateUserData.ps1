# Logging
Start-Transcript -Path C:\MigrateLogs.txt -Force -NoClobber -Append | Out-Null

# Get domain credentials. Customize `-Username $CUser` to match your environment if you
# have a specific naming scheme for domain admin accounts vs regular users

$Creds = $null

# Set $CUser to the currently logged-on user
$CUser = [System.Security.Principal.WindowsIdentity]::GetCurrent() | select -ExpandProperty Name

while ($null -eq $Creds) {
    Write-Warning "Domain credentials are required."

    if (([Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Domain Admins")) { 
        Write-Host "Currently logged in with a domain admin account"
        $Creds = Get-Credential -Username "$CUser" -Message "Enter Password for $CUser"
    }
    else {
        Write-Host "Currently logged in with a non-domain admin account"
        $Creds = Get-Credential -Username "$CUser" -Message "Enter Password for $CUser"
    }
}

Clear-Host

# Loop until the $false flag is set
$Loop = $true

while ($Loop) {
    # Set variables for use later
    $Username = Read-Host -Prompt "Enter username to be copied"

    # Set folders to copy from profile
    $FoldersToCopy = @(
        'Desktop'
        'Downloads'
        'Favorites'
        'Documents'
        'Pictures'
        'Videos'
        'AppData\Local\Google'
    )

    # Empty variables for first run
    $ConfirmHost = $null
    $ConfirmDest = $null
    $ConfirmUser = $null

    Clear-Host
    
    # Gather host, destination, and profile username variables and confirm each one before moving on
    while ( $ConfirmHost -ne 'y' ) {
        $HostComputer = Read-Host -Prompt 'Enter the computer to copy from'

        if ( -not (Test-Connection -ComputerName $HostComputer -Count 2 -Quiet) ) {
            Write-Warning "$HostComputer is not online. Please enter another computer name."
            continue
            $ConfirmHost = $null
        }
    
        $ConfirmHost = Read-Host -Prompt "The entered computer name was:`t$HostComputer`r`nIs this correct? (y/n)"
    }
    Clear-Host

    while ( $ConfirmDest -ne 'y' ) {
        $DestComputer = Read-Host -Prompt 'Enter the computer to copy to'

        if ( -not ( Test-Connection -ComputerName $DestComputer -Count 2 -Quiet ) ) {
            Write-Warning "$DestComputer is not online. Please enter another computer name."
            continue
            $ConfirmDest = $null
        }

        $ConfirmDest = Read-Host -Prompt "The entered computer name was:`t$DestComputer`r`nIs this correct? (y/n)"
    }
    Clear-Host

    while ( $ConfirmUser -ne 'y' ) {
        Write-Host -ForegroundColor Yellow "Username is currently set as $Username"

        if ( -not ( Test-Path -Path "\\$HostComputer\c$\Users\$Username" -PathType Container ) ) {
            Write-Warning "$Username could not be found on $HostComputer. Please enter another user profile."
            $Username = Read-Host -Prompt "Enter user to be copied"
            continue
        }

        $ConfirmUser = Read-Host -Prompt "Is this correct? (y/n)"
    }
    Clear-Host

    # Begin copying profile data from host machine to the destination. Verify profile path on the host machine
    # exists before initiating the copy process. If it does not, notify the user and break the loop.
    Write-Host -ForegroundColor Yellow "Beginning profile transfer of $Username from $HostComputer to $DestComputer"
    Write-Host "___________________________________________________________________________"
    Write-Host ""

    $SourceRoot = "\\$HostComputer\c$\Users\$Username"
    $DestinationRoot = "\\$DestComputer\c$\Users\$Username-old"

    foreach ( $Folder in $FoldersToCopy ) {
        $Source = Join-Path -Path $SourceRoot -ChildPath $Folder
        $Destination = Join-Path -Path $DestinationRoot -ChildPath $Folder

        if ( -not (Test-Path -Path $Source -PathType Container) ) {
            Write-Warning "Could not find path`t$Source. Is this the correct profile folder location?"
            Write-Warning "Check $SourceRoot to verify the folder structure, then try again."
            Write-Warning "Exiting..."
            Write-Host ""
            $SourcePathFail = $true
            Break
        }

        Robocopy.exe $Source $Destination /w:1 /r:1 /E /IS /NP /NFL
    }

    # Variables for the scheduled task to be created on the destination machine
    # Change the domain information for `-User` in `$Trigger` to match your environment if needed
    if ($SourcePathFail -ne $true) {
        $Trigger = New-ScheduledTaskTrigger -AtLogOn -User "$Username"
        $User = "NT AUTHORITY\SYSTEM"
        $Actions = (New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "Robocopy.exe C:\Users\$Username-old C:\Users\$Username /w:1 /r:1 /E /IS /NP /NFL"),
                   (New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "Unregister-ScheduledTask -TaskName CopyProfile -Confirm:`$false")
        $ScriptBlockTask = {Register-ScheduledTask -TaskName "CopyProfile" -Trigger $Using:Trigger -User $Using:User -Action $Using:Actions -RunLevel Highest -Force}

        # Create the task on the destination computer to copy the old profile data into the newly created profile
        Write-Host -ForegroundColor Yellow "Creating task on $DestComputer to finalize the transfer"
        Invoke-Command -ScriptBlock $ScriptBlockTask -ComputerName $DestComputer -Credential $Creds
        Write-Host -ForegroundColor Green "User-specific logon task has been created on $DestComputer"

        # Finalize
        Write-Host ""
        Write-Host ""
        Write-Host -ForegroundColor Green "Initial profile staging is finished. Follow the instructions below to complete the process."
        Write-Host ""
        Write-Host -ForegroundColor Cyan "* Log onto the destination computer as the user"
        Write-Host -ForegroundColor Cyan "* Their profile will start to migrate after logging in as them"
        Write-Host ""
        Write-Host ""
    }

    # Prompt user to restart the process. If 'n', exit the script. If 'y', go back to the beginning.
    $repeat = Read-Host -Prompt "Go again? (y/n)"

    If ($repeat -eq "n") {
        $Loop = $false
    }
}

#Stop logging
Stop-Transcript