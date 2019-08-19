$Assets = Import-CSV D:\assets.csv
$TargetOU = "/OU"

foreach($asset in $Assets){
    C:\GAM\gam.exe update cros query:asset_id:$($asset.asset_id) action reenable
    C:\GAM\gam.exe update cros query:asset_id:$($asset.asset_id) ou "$TargetOU"
}