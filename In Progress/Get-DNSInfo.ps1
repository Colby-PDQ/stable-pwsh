Import-Module ActiveDirectory

#List of DNS servers to search through
$DNSServers = @('','','')
$HostName = Read-Host "Name of computer"

ForEach ($server in $DNSServers){
    Get-DnsServerResourceRecord -ZoneName "msd.k12.or.us" -ComputerName $server  -Name $HostName
}

Read-Host "Press 'Enter' to exit."