# This function returns all registerred Library items to check deleted
# Declared obsolete Ruben Jung 16-09-2021. (to be removed)
function Compare-RJSourceAndTarget {
    [CmdletBinding()]
    Param(        
        [parameter(mandatory = $true)] [String]$scrSite,
        [parameter(mandatory = $true)] [String]$scrListTitle
    )
    #QUick and dirty. The sourceRoot has to many slashes. To be fixed properly
    $scrSite = $scrSite.Replace('////', '//')
    $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserNameSP2010, $securePwd
    Connect-PnPOnline -URL $scrSite -Credentials $cred -ErrorAction Stop 
    Write-Host "Double check Source : Connected to sourcesite  $($scrSite)" -b yellow
    $SourceList = Get-PnPList -Identity $scrListTitle
    $Fields = Get-PnPField -List $SourceList -Identity 'FileLeafRef' -ErrorAction SilentlyContinue
    try {
        $SourceFiles = (Get-PnPListItem -List $SourceList -Fields $Fields).FieldValues
    }
    catch {}
    return $SourceFiles
}