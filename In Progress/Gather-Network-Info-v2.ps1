$ErrorActionPreference = "SilentlyContinue"
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
Clear-Host

# Get domain credentials. Customize `-Username $CUser` to match your environment if you
# have a specific naming scheme for domain admin accounts vs regular users
$Creds = $null

# Set $CUser to the currently logged-on user
$CUser = [System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -ExpandProperty Name
Clear-Host

while ($null -eq $Creds) {
    Write-Warning "Domain credentials are required."

    if (([Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Domain Admins")) { 
        Write-Host "Currently logged in with a domain admin account"
        $Creds = Get-Credential -Username "$CUser" -Message "Enter Password for $CUser"
    }
    else {
        Write-Host "Currently logged in with a non-domain admin account"
        $Creds = Get-Credential -Username "DomainAdmin" -Message "Enter Password for DomainAdmin"
    }
}
Clear-Host

#Formatted Paragraph to present choices
$picker = @(
    ("Choose where to pull information from: "),
    ("(1) - Local machine."),
    ("(2) - Remote machine.")
)

#Default loop to true
$Loop = $true

#Start the loop. This loop will continue until the user chooses "N" or "n" when prompted
while ($Loop) {
    Clear-Host
    
    #Reset variables at each start of the loop
    $choice = $null
    $compname = $null
    $isWireless = $null
    $lNICinfo = $null
    $localDNSTarget = $null
    $rNICinfo = $null
    
    #Show choices
    while ($choice -ne "1" -and $choice -ne "2") {
        $picker
        Write-Host ""
        $choice = Read-Host "Choose an option from above"
        $isWireless = Read-Host -Prompt "Is this a wireless device? (y/n)"
        Clear-Host
    } 

    #Gather info based on the target
    if ($choice -eq "1") {
        $compname = "localhost"
        if ($isWireless -eq "y") {
            Get-Service -Name dot3svc -ErrorAction SilentlyContinue | Restart-Service
            netsh wlan show wlanreport
            Start-Process -FilePath "C:\PSOutput\WlanReport\wlan-report-latest.html"
        }

        $lNICinfo = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled} | Select-Object @(
            @{
                Name       = 'Name of the machine'
                Expression = {[string]::join(" | ", ($_.DNSHostName))}
            }
            @{
                Name       = 'Active NIC'
                Expression = {$_.Description}
            } 
            @{
                Name       = 'IP Addresses'
                Expression = {[string]::join(" | ", ($_.IPAddress))}
            }
            @{
                Name       = 'DHCP Server (Static IP if Empty)'
                Expression = {[string]::join("/", ($_.DHCPServer))}
            }
            @{
                Name       = 'DNS Servers'
                Expression = {[string]::join(", ", ($_.DNSServerSearchOrder -Join ' | '))}
            } 
            'MACAddress'
            @{
                Name       = 'Default Gateway'
                Expression = {[string]::join(";", ($_.DefaultIPGateway))}
            }
        )

        Write-Host ""
        Write-Host -ForegroundColor Green "Active NIC information"
        Write-Host "If any of the fields below are empty, there may be a problem"
        $lNICinfo
        Write-Host ""
        
        Write-Host -ForegroundColor Green "Testing LAN connection..."
        Write-Host ""
        $localDNSTarget = Read-Host -Prompt "Enter DNS resolution target name"
        Test-NetConnection $localDNSTarget -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
            @{
                Name = 'Testing Address (Alpha)'; Expression = {[string]::join(" | ", ($_.ResolvedAddresses))}
            }
            @{
                Name = 'Ping Success?'; Expression = {($_.PingSucceeded)}
            }
        )
        Write-Progress -Activity "TraceRoute" -Completed
        
        Write-Host -ForegroundColor Green "Testing internet connection..."
        Write-Host ""
        Test-NetConnection google.com -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
            @{
                Name = 'Domain used to test'; Expression = {[string]::join(" | ", ($_.ComputerName))}
            } 
            @{
                Name = 'Resolved IP'; Expression = {($_.RemoteAddress)}
            } 
            @{
                Name = 'Ping status'; Expression = {[string]::join(" | ", ($_.PingSucceeded))}
            }
            @{
                Name = 'Traceroute Result'; Expression = {[string]::join(", ", ($_.Traceroute -Join ' --> '))}
            }
        )
        Write-Progress -Activity "TraceRoute" -Completed
        $choice = $null
    }

    elseif ($choice = "2") {
        $compname = Read-Host "Enter the remote computer name "
        $HostReport = "C:\ProgramData\Microsoft\Windows\WlanReport"
        $DestReport = "$env:UserProfile\Desktop\$compname"
        Clear-Host

        Write-Host -ForegroundColor Green "Active NIC information"
        Write-Host "If any of the fields below are empty, there may be a problem"
        $rNICinfo = Invoke-Command -ComputerName $compname -Credential $creds {
            Get-CimInstance Win32_NetworkAdapterConfiguration -ComputerName $compname | Where-Object {$_.IPEnabled} | Select-Object @(
                @{
                    Name       = 'Name of the machine'
                    Expression = {[string]::join(" | ", ($_.DNSHostName))}
                }
                @{
                    Name       = 'Active NIC'
                    Expression = {$_.Description}
                } 
                @{
                    Name       = 'IP Addresses'
                    Expression = {[string]::join(" | ", ($_.IPAddress))}
                }
                @{
                    Name       = 'DHCP Server (Static IP if Empty)'
                    Expression = {[string]::join("/", ($_.DHCPServer))}
                }
                @{
                    Name       = 'DNS Servers'
                    Expression = {[string]::join(", ", ($_.DNSServerSearchOrder -Join ' | '))}
                } 
                'MACAddress'
                @{
                    Name       = 'Default Gateway'
                    Expression = {[string]::join(";", ($_.DefaultIPGateway))}
                }
            )
        }

        Write-Host ""
        Write-Host -ForegroundColor Green "Active NIC information"
        Write-Host "If any of the fields below are empty, there may be a problem"
        $rNICinfo

        Invoke-Command -ComputerName $compname -Credential $creds -ScriptBlock {
            Write-Host -ForegroundColor Green "Testing LAN connection..."
            Write-Host ""
            Test-NetConnection $localDNSTarget -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
                @{
                    Name = 'Testing Address (Alpha)'; Expression = {[string]::join(" | ", ($_.ResolvedAddresses))}
                }
                @{
                    Name = 'Ping Success?'; Expression = {($_.PingSucceeded)}
                }
            )
            Write-Progress -Activity "TraceRoute" -Completed

            Test-NetConnection google.com -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
                @{
                    Name = 'Domain used to test'; Expression = {[string]::join(" | ", ($_.ComputerName))}
                } 
                @{
                    Name = 'Resolved IP'; Expression = {($_.RemoteAddress)}
                } 
                @{
                    Name = 'Ping status'; Expression = {[string]::join(" | ", ($_.PingSucceeded))}
                }
                @{
                    Name = 'Traceroute Result'; Expression = {[string]::join(", ", ($_.Traceroute -Join ' --> '))}
                }
            )
            Write-Progress -Activity "TraceRoute" -Complete
        }
        
        if ($isWireless -eq "y") {
            Invoke-Command -ComputerName $compname -Credential $creds -ScriptBlock {
                New-PSDrive -Name Source -PSProvider FileSystem -Root $Using:HostReport -Credential $Using:creds
                New-PSDrive -Name Destination -PSProvider FileSystem -Root $Using:DestReport -Credential $Using:creds

                Get-Service -Name dot3svc -ErrorAction SilentlyContinue | Restart-Service
                netsh wlan show wlanreport

                Write-Host -ForegroundColor Green "Copying report to $Using:DestReport"
                Write-Host ""
                Robocopy.exe $Using:HostReport $Using:DestReport /NDL /NFL /NJH /NJS

                Remove-PSDrive -Name Source 
                Remove-PSDrive -Name Destination
            }
            Start-Process -FilePath "$DestReport\wlan-report-latest.html"
        }
    }

    #Prompt to repeat
    $Loop = Read-Host -Prompt "Go again? (y/n)"

    If ($Loop -eq "n") {
        $Loop = $false
        Read-Host "Review errors (if present). Press any key to exit"
    }
}