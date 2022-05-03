# general connect to sharepoint with login type and optional password defined in $global:settings, No test

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
$Params = @{
    Url = 'https://paccar.sharepoint.com/sites/DAF-MS-ASCOM-Site'
}
$params.Add('UseWebLogin', $true)
try {

    
    $connection = Connect-PnPOnline @Params -ErrorAction Stop -ReturnConnection    
    #Remove list if existant 
    $List = Get-PnPList -Identity 'Procedure PDF Library'
    $ListItems = Get-PnPListItem -List $List 
    #Remove-PNPListItem 
    Write-Host "Lists created " -ForegroundColor Green
}
catch [System.SystemException] {
    $ErrorMessage += $_.Exception.Message + 'on the following  URL:'
    $ErrorMessage += $Url
    Write-Error $ErrorMessage
}
