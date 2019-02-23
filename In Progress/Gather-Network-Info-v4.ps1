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
        $localDNSTarget = Read-Host -Prompt "LAN target for DNS test"
        Clear-Host
    } 

    #Gather info based on the target - choice 2 below is identical, except being wrapped in Invoke-Commands
    if ($choice -eq "1") {
        $compname = "localhost"

        # Filter out any NIC that is not active or physical - only tested in a heavily Dell environment
        $activeNIC = Get-NetAdapter | Where-Object {$_.HardwareInterface -eq $True -and $_.Status -eq "Up"} | Select-Object -ExpandProperty InterfaceDescription

        # Pull current network information from the NIC found above, selecting only the information we care about
        $lNICinfo = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {$_.Description -eq "$activeNIC"} | Select-Object @(
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
        Test-NetConnection $localDNSTarget -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
            @{
                Name       = 'Testing Address (DNS)'; 
                Expression = {[string]::join(" | ", ($_.ResolvedAddresses))}
            }
            @{
                Name       = 'Ping Success?'; 
                Expression = {($_.PingSucceeded)}
            }
        )
        Write-Progress -Activity "TraceRoute" -Completed
        
        Write-Host -ForegroundColor Green "Testing internet connection..."
        Write-Host ""
        Test-NetConnection google.com -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
            @{
                Name       = 'Domain used to test'; 
                Expression = {[string]::join(" | ", ($_.ComputerName))}
            } 
            @{
                Name       = 'Resolved IP'; 
                Expression = {($_.RemoteAddress)}
            } 
            @{
                Name       = 'Ping status'; 
                Expression = {[string]::join(" | ", ($_.PingSucceeded))}
            }
            @{
                Name       = 'Traceroute Result'; 
                Expression = {[string]::join(", ", ($_.Traceroute -Join ' --> '))}
            }
        )
        Write-Progress -Activity "TraceRoute" -Completed

        if ($isWireless -eq "y") {
            $netshPatterns = @(
                "Description",
                "Physical",
                "State",
                "SSID",
                "Radio",
                "Connection",
                "Channel",
                "Receive",
                "Transmit",
                "Signal",
                "Profile"
            )
            # This service is required for netsh - sometimes it isn't running, so start it
            Get-Service -Name dot3svc -ErrorAction SilentlyContinue | Restart-Service

            # Gather stats from the currently-connected wireless device
            netsh wlan show interfaces | Select-String -Pattern $netshPatterns | Select-Object -Expand Line
            
            Write-Host "Generating detailed report..."
            netsh wlan show wlanreport | Out-Null

            # Open the generated report
            Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
        }
        $choice = $null
    }

    elseif ($choice = "2") {
        $compname = Read-Host "Enter the remote computer name "
        Clear-Host

        # Filter out any NIC that is not active or physical - only tested in a heavily Dell environment
        $activeNIC = Invoke-Command -ComputerName $compname -Credential $creds {
            Get-NetAdapter | Where-Object {$_.HardwareInterface -eq $True -and $_.Status -eq "Up"} | Select-Object -ExpandProperty InterfaceDescription
        }

        $rNICinfo = Invoke-Command -ComputerName $compname -Credential $creds {
            Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {$_.Description -eq "$Using:activeNIC"} | Select-Object @(
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
            Write-Host -ForegroundColor Green "Testing DNS resolution"
            Write-Host ""
            Test-NetConnection $Using:localDNSTarget -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
                @{
                    Name       = 'Testing Address (DNS)'; 
                    Expression = {[string]::join(" | ", ($_.ResolvedAddresses))}
                }
                @{
                    Name       = 'Ping Success?'; 
                    Expression = {($_.PingSucceeded)}
                }
            )
            Write-Progress -Activity "Internal TraceRoute" -Completed

            Test-NetConnection google.com -TraceRoute -Hops 5 -WarningAction SilentlyContinue | Select-Object @(
                @{
                    Name       = 'Domain used to test'; 
                    Expression = {[string]::join(" | ", ($_.ComputerName))}
                } 
                @{
                    Name       = 'Resolved IP'; 
                    Expression = {($_.RemoteAddress)}
                } 
                @{
                    Name       = 'Ping status'; 
                    Expression = {[string]::join(" | ", ($_.PingSucceeded))}
                }
                @{
                    Name       = 'Traceroute Result'; 
                    Expression = {[string]::join(", ", ($_.Traceroute -Join ' --> '))}
                }
            )
            Write-Progress -Activity "External TraceRoute" -Complete
        }
        Write-Host ""
        
        if ($isWireless -eq "y") {
            
            $netshPatterns = @(
                "Description",
                "Physical",
                "State",
                "SSID",
                "Radio",
                "Connection",
                "Channel",
                "Receive",
                "Transmit",
                "Signal",
                "Profile"
            )
            $HostReport = "C:\ProgramData\Microsoft\Windows\WlanReport"
            $DestReport = "$env:UserProfile\Desktop\$compname"

            Invoke-Command -ComputerName $compname -Credential $creds -ScriptBlock {

                # Create connection between host and remote computer to transfer the final netsh report back
                New-PSDrive -Name Source -PSProvider FileSystem -Root $Using:HostReport -Credential $Using:creds
                New-PSDrive -Name Destination -PSProvider FileSystem -Root $Using:DestReport -Credential $Using:creds

                # This service is required for netsh - sometimes it isn't running, so start it
                Get-Service -Name dot3svc -ErrorAction SilentlyContinue | Restart-Service

                # Gather stats from the currently-connected wireless device
                netsh wlan show interfaces | Select-String -Pattern $Using:netshPatterns | Select-Object -Expand Line
            
                Write-Host "Generating detailed report..."
                netsh wlan show wlanreport | Out-Null

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