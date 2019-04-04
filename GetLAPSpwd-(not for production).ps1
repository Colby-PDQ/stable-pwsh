#Start the loop off as true
$Loop = $true
Clear-Host

#Start the loop - run until $Loop is set to false
while ($Loop) {

    Write-Host -ForegroundColor Green "LAPS password query"
    Write-Host ""

    #Collect the name of the computer. 
    $TargetComp = Read-Host -Prompt "Computer name "
    Write-Host ""
    
    #Run the command to pull the password from AD and displays it on-screen.
    $getad = (([adsisearcher]"(&(objectCategory=Computer)(name=$TargetComp))").findall()).properties
    $LAPSpw = $getad."ms-mcs-admpwd"

    if (!($LAPSpw)) {
        Write-Warning -Message "LAPS password has not been set for $TargetComp"
        Write-Host ""
    }
    else {
        Write-Host "Current LAPS password for $TargetComp - "
        Write-Host ====================
        Write-Host -ForegroundColor Green "$LAPSpw"
        Write-Host ====================
        Write-Host ""
    }

    #Offer to re-run the above. Set $repeat to Y or N.
    $repeat = Read-Host -Prompt "Go again? (y/n)"

    Clear-Host
    #Exit the loop if $repeat is `n`.
    If ($repeat -eq "n") {
        $Loop = $false
    }
}