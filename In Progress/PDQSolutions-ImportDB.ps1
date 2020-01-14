<#
.SYNOPSIS
    Simplify importing new databases into PDQ Inventory and/or Deploy
.DESCRIPTION
    Importing a database involves several manual steps - 
    | stop relevant product processes (PDQDeployConsole and PDQInventoryConsole) and services (PDQDeploy and PDQInventory)
    | rename existing DB
    | copy new DB from file share to current machine
    | rename new DB
    | restart relevant product processes and services

    This attempts to automate all the above, as well as offering the option to revert back to the original DB when done testing the new DB.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    Nothing fancy about this yet. Maybe eventually
#>

# Logging
Start-Transcript -Path "$env:USERPROFILE\Desktop\ImportDB.txt" -Force -NoClobber -Append | Out-Null

# Loop until the $false flag is set
$Loop = $true

# Set variables
$DeployProcess = "PDQDeployConsole"
$DeployService = "PDQDeploy"
$InventoryProcess = "PDQInventoryConsole"
$InventoryService = "PDQInventory"

$StandardDBName = "database.db"
$DBLocationRoot = "\\fs01\Support\"
$DeployDB = "PDQDeploy\"
$InventoryDB = "PDQInventory\"

while ($Loop) {
    # Set variables for use later
    $ticketNum = $null
    $ProductList = $null
    $ticketPath = $null

    # Empty variables for first run
    $ConfirmEntry = $null
    Clear-Host
        
    # Gather input for variables and confirm each one before moving on
    while ( $ConfirmEntry -ne 'y' ) {
            
        $ticketNum = Read-Host -Prompt 'Enter a ticket number'
        $ticketPath = Join-Path -Path $DBLocationRoot -ChildPath $ticketNum
    
        if ( -not (Test-Path "$ticketPath" -PathType Container) ) {
            do {
                Write-Warning "A directory for ticket $ticketNum was not found in $DBLocationRoot. Verify the database has been uploaded and the directory created."
                $ticketNum = Read-Host -Prompt 'Enter a ticket number'
            } until (Test-Path "$ticketPath" -PathType Container)
        }
        Clear-Host
    
        Write-Host -ForegroundColor Green "Ticket number is: $ticketNum"

        $ProductList = Get-ChildItem -Path "$ticketPath"
        
        foreach ($Folder in $ProductList){
            Get-ChildItem ($Folder).PSPath -Filter "Database.db" -Recurse
        }
        

        if ( (($ProductList).count -eq 2)) {
            do {
                Write-Host "================ Both Deploy and Inventory databases available ================"
                Write-Host " Press '1' for Deploy."
                Write-Host " Press '2' for Inventory."
                Write-Host " Press '3' for Both."

                $PickProduct = Read-Host -Prompt 'Choose an option'

                switch ($PickProduct)
     {
           '1' {
                cls
                Write-Host "Importing Deploy database from $ticketPath"
           } '2' {
                cls
                'You chose option #2'
           } '3' {
                cls
                'You chose option #3'
           } 'q' {
                return
           }
     }
     pause
}
until ($input -eq 'q')
            } until (Test-Path "$ticketPath" -PathType Container)
        }
            
        Write-Host -ForegroundColor Green "Database to import: $HostComputer"
        Write-Host -ForegroundColor Green "DESTINATION computer name is: $DestComputer"
        Write-Host ""
            
        while ( $ConfirmEntry -ne 'y' -and $ConfirmEntry -ne "n") {
            Write-Host -ForegroundColor Yellow "Warning - Verify that user - $Username - is logged off before continuing"
            Write-Host -ForegroundColor Yellow "Failure to do so will likely result in files being skipped due to being in-use"
            $ConfirmEntry = Read-Host -Prompt "Is this information correct? (y/n)"
        }
    }
    Clear-Host
    
    # Begin copying databases
            
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
}
     
# Prompt user to restart the process. If 'n', exit the script. If 'y', go back to the beginning.
$repeat = Read-Host -Prompt "Start new session? (y/n)"
    
If ($repeat -eq "n") {
    $Loop = $false
}
    
#Stop logging
Stop-Transcript