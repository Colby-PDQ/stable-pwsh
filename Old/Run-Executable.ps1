#Set ExecutionPolicy for the duration of the script
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

#Logging
#Start-Transcript -Path C:\Logs\Run-Executable.txt -Force -NoClobber -Append

#Set $initialDirectory to mapped drive
$root = (Get-PSDrive 'T').Root

#Function to bring up the "Choose file" dialogue.
Function Get-FileName($initialDirectory)
{  
 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
 Out-Null

 $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $OpenFileDialog.initialDirectory = $initialDirectory
 $OpenFileDialog.filter = "All files (*.*)| *.*"
 $OpenFileDialog.ShowDialog() | Out-Null
 $OpenFileDialog.filename
} #end function Get-FileName 

#Executable file name and path
$EXEname = Get-FileName -initialDirectory "$root"
#Any arguments needed for transforms or silent installation
$arguments = Read-Host "Additional arguments needed (/S, /s, --unattended, etc) - "

if ([string]::IsNullOrEmpty($arguments)) 
    {
    Start-Process -FilePath "$EXEname"
    }
else 
    {
    Start-Process -FilePath "$EXEname" -ArgumentList "$arguments"
    }

#Stop logging
#Stop-Transcript
