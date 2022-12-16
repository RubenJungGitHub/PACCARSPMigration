# This function returns all registerred Library items to check deleted
# Declared obsolete Ruben Jung 16-09-2021. (to be removed)
function Compare-RJSourceAndTarget {
    [CmdletBinding()]
    Param(        
        [parameter(mandatory = $true)] [PSCustomObject]$MuforValidation,
        [switch]$UseWebLogin
    )

    $BatchSize = 1000
    #QUick and dirty. The sourceRoot has to many slashes. To be fixed properly
    $Query = New-Object Microsoft.SharePoint.Client.CamlQuery
    $Query.ViewXml = "<View Scope='Recursive'><Query><OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy></Query><RowLimit Paged='TRUE'>$BatchSize</RowLimit></View>"
    #$Query.ViewXml = "<View Scope='Recursive'><Query><OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy></Query><RowLimit Paged='TRUE'>$BatchSize</RowLimit></View>"
    $ReturnSet = [System.Collections.Generic.List[PSObject]]::new()

    #Read more: https://www.sharepointdiary.com/2017/10/sharepoint-online-fix-attempted-operation-is-prohibited-because-it-exceeds-list-view-threshold.html#ixzz7nYM6xChX

    $scrSite = $MuforValidation.SourceURL.Replace('////', '//')
    $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserNameSP2010, $securePwd
    if ($UseWebLogin.IsPresent) {
        $scrSite = $MuforValidation.DestinationURL.Replace('////', '//')
        Connect-PnPOnline -URL $scrSite -UseWebLogin -ErrorAction Stop 
    }
    else {
        Write-Host "Double check Source : Connected to sourcesite  $($scrSite)" -b yellow
        $scrSite = $MuforValidation.SourceURL.Replace('////', '//')
        Connect-PnPOnline -URL $scrSite -Credentials $cred -ErrorAction Stop 
    }

    $SourceList = Get-PnPList -Identity $MUForValidation.ListTitleWithPrefix -ErrorAction SilentlyContinue
    if ($null -eq $SourceList) {
        $SourceList = Get-PnPList -Identity $MUForValidation.ListTitle -ErrorAction SilentlyContinue
    }
    #$Fields = Get-PnPField -List $SourceList -Identity 'FileLeafRef' -ErrorAction SilentlyContinue
    try {
        #  $SourceFiles = (Get-PnPListItem -List $SourceList -Fields $Fields).FieldValues
        #$SourceFiles = Get-PnPListItem -List $SourceList -Query $Query.ViewXml  
        $SourceFiles = Get-PnPListItem -List $SourceList -Query $Query.ViewXml  -PageSize $BatchSize
    }
    catch {
        $a = 1
    }
    $SourceFiles  | ForEach-Object {
        $Result = [PSCustomObject]@{
            FileRef     = $_.FieldValues['FileRef']
            FileLeafRef = $_.FieldValues['FileLeafRef']
        }
        $ReturnSet.add($Result)
    }
        
    return $ReturnSet
}