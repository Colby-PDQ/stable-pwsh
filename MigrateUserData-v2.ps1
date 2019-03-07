# Logging
Start-Transcript -Path C:\MigrateLogs.txt -Force -NoClobber -Append | Out-Null

# Get domain credentials. Customize `-Username $CUser` to match your environment if you
# have a specific naming scheme for domain admin accounts vs regular users
$Creds = $null
$validCreds = $null
Clear-Host

#Test User Credentials
while (!$validCreds) {
    $cred = Get-Credential -Message "Please input credentials for "
    try {
        $validCreds = Get-ADDomain -Server alpha -Credential $cred
    }
    catch {Write-Host ForegroundColor Red "Incorrect username or password. Try again."}
}

Clear-Host

# Loop until the $false flag is set
$Loop = $true

while ($Loop) {
    # Set variables for use later
    $Username = $null 

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
    $ConfirmEntry = $null
    
    Clear-Host
    
    # Gather host, destination, and profile username variables and confirm each one before moving on
    while ( $ConfirmEntry -ne 'y' ) {
        
        $HostComputer = Read-Host -Prompt 'Enter the HOST name'

        if ( -not (Test-Connection -ComputerName $HostComputer -Count 1 -Quiet) ) {
            do {
                Write-Warning "$HostComputer is not online. Please enter another computer name."
                $HostComputer = Read-Host -Prompt 'Enter the HOST name'
            } until (Test-Connection -ComputerName $HostComputer -Count 1 -Quiet)
        }
        Clear-Host

        $DestComputer = Read-Host -Prompt 'Enter the DESTINATION name'

        if ( -not ( Test-Connection -ComputerName $DestComputer -Count 1 -Quiet ) ) {
            do {
                Write-Warning "$DestComputer is not online. Please enter another computer name."
                $DestComputer = Read-Host -Prompt 'Enter the DESTINATION name'
            } until (Test-Connection -ComputerName $DestComputer -Count 1 -Quiet)
        }
        Clear-Host

        $Username = Read-Host -Prompt "Enter the profile (User) name"
        
        if ( -not ( Test-Path -Path "\\$HostComputer\c$\Users\$Username" -PathType Container ) ) {
            do {
                Write-Warning "$Username could not be found on $HostComputer. Please enter another user profile."
                $Username = Read-Host -Prompt "Enter the profile (User) name"
            } until (Test-Path -Path "\\$HostComputer\c$\Users\$Username" -PathType Container)
        }
        Clear-Host

        Write-Host -ForegroundColor Green "User profile to copy is: $Username"
        Write-Host -ForegroundColor Green "HOST computer name is: $HostComputer"
        Write-Host -ForegroundColor Green "DESTINATION computer name is: $DestComputer"
        Write-Host ""
        
        while ( $ConfirmEntry -ne 'y' -and $ConfirmEntry -ne "n") {
            Write-Host -ForegroundColor Yellow "Warning - Verify that user - $Username - is logged off before continuing"
            Write-Host -ForegroundColor Yellow "Failure to do so will likely result in files being skipped due to being in-use"
            $ConfirmEntry = Read-Host -Prompt "Is this information correct? (y/n)"
        }
    }
    Clear-Host

    # Begin copying profile data from host machine to the destination. Verify profile path on the host machine
    # exists before initiating the copy process. If it does not, notify the user and break the loop.
    Write-Host -ForegroundColor Green "User profile to copy is: $Username"
    Write-Host -ForegroundColor Green "HOST computer name is: $HostComputer"
    Write-Host -ForegroundColor Green "DESTINATION computer name is: $DestComputer"
    Write-Host ""
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

        Robocopy.exe $Source $Destination /w:1 /r:1 /E /IS /NFL /ETA >> "robocopy-$HostComputer.txt"
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
        Write-Host ""
        Write-Host ""
        Write-Host -ForegroundColor Green "User-specific logon task has been created on $DestComputer"

        # Finalize
        Write-Host ""
        Write-Host ""
        Write-Host -ForegroundColor Green "Initial profile staging is finished. Follow the instructions below to complete the process."
        Write-Host -ForegroundColor Cyan "* Log onto the destination computer as the user"
        Write-Host -ForegroundColor Cyan "* Their profile will start to migrate after logging in as them"
        Write-Host ""
        Read-Host "Press enter to continue"
        Clear-Host
    }

    # Rename the destination computer if needed
    $Rename = $null
    $Confirm = $null

    while ($null -eq $Rename) {
        Write-Host ""
        $Rename = Read-Host -prompt "Do you want to rename the destination computer now? (y/n)"
        Clear-Host

        if ($Rename -eq "y") {

            while ($Confirm -ne "y") {
                #Collect the new name for the computer.
                Write-Host ""
                $NewName = Read-Host -Prompt "Please enter the computer name you want to use "
    
                #Confirm the name change.
                Write-Host ""
                Write-host "Current computer name: " $DestComputer
                Write-host "New Computer Name: " $NewName
                Write-Host ""
                $Confirm = Read-Host -prompt "Are these names correct? (y/n)"
            }

            #Rename the destination computer
            Write-Host ""
            Write-Host ""
            Rename-Computer -ComputerName $DestComputer -NewName $NewName -DomainCredential  $Creds -Force
            Write-Host ""
        
            #Prompts for whether or not you want to restart the renamed computer immediately.
            Write-Host -ForegroundColor Yellow "A restart is required to finish renaming. Issues will occur if too much time passes without a restart."
            $Reboot = Read-host -Prompt "Do you want to restart the computer? (y/n)"
            Write-Host ""
        
            If ($Reboot -eq "y") {
                Restart-Computer -ComputerName $DestComputer -Credential $Creds -Force
            }
            else {
                Write-Host -ForegroundColor Yellow "Remember to restart the computer within the next 10-15 minutes to avoid possible communication issues!"
            }
        }
    }
 
    # Prompt user to restart the process. If 'n', exit the script. If 'y', go back to the beginning.
    $repeat = Read-Host -Prompt "Start new session? (y/n)"

    If ($repeat -eq "n") {
        $Loop = $false
    }
}

#Stop logging
Stop-Transcript
