#schedule the task to run Runtask.ps1 daily on 2 AM at night
#adding switch off: Do not store password.

$scriptblock = {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json"
    #Start-MtHLocalPowerShell -settingfile 'D:\Beheer\PaccarShareGate\settings.json'
    $script:username = $settings.current.username
    Get-ScheduledTask | Where-Object { $_.TaskName -eq 'SP Migration daily Task' } | ForEach-Object {
        Unregister-ScheduledTask -TaskName 'SP Migration daily Task' -Confirm:$false
    }
    # USE SINGLE QUOTES
    $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -File .\Deploy\RunTask.ps1' -WorkingDirectory 'D:\Beheer\PaccarShareGate' 
    $Trigger = New-ScheduledTaskTrigger -Daily -At 2AM
    $Settings = New-ScheduledTaskSettingsSet
    $Principal = New-ScheduledTaskPrincipal -UserId $username -LogonType S4U
    Register-ScheduledTask -TaskName 'SP Migration daily Task' -Trigger $Trigger -Action $Action -Principal $Principal 
    Pause
}

Start-Process powershell -ArgumentList "-command &{$ScriptBlock}" -Verb Runas -Wait
Write-Host 'show schedule'
Get-ScheduledTask | Where-Object { $_.TaskName -eq 'SP Migration daily Task' } | Format-Table -Property TaskPath, TaskName, State -AutoSize

# get username
# (Get-WMIObject -ClassName Win32_ComputerSystem).Username
# [System.Security.Principal.WindowsIdentity]::GetCurrent().Name