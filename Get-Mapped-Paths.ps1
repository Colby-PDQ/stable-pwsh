#Displays paths for all network drives that are connected to the current user.

&{
$(
    (get-psdrive -PSProvider FileSystem).
        Where{$_.DisplayRoot -or $_.Root.StartsWith('\\')}.
        ForEach{ '{0} - {1}' -f $_.Name, ($_.DisplayRoot, $_.Root)[!$_.DisplayRoot] } -join "`n"
) 
$PSCommandPath
}
Read-Host = ":"