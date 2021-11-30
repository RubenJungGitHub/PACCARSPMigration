Using Module MigrationClasses
function Test-MtHSPMigUnitModified {
    [CmdletBinding()]
    [OutputType([DateTime])]
    param(
        [parameter(Mandatory = $true)][MigrationUnitClass]$item
    )
    if ($item.Scope -eq 'list') {
        try {
            $list = Get-PnPList -Identity $item.ListTitle
        }
        catch {
            $ErrorMessage = $_ | Out-String
            $ErrorMessage += 'Error occured on following object:'
            $ErrorMessage += $Item | Format-List | Out-String
            Write-Error $ErrorMessage
            return $null
        }
        $LastItemModified = $list.LastItemModifiedDate
    }
    else {
        $LastItemModified = (Get-PnPWeb -Includes LastItemModifiedDate).LastItemModifiedDate
    }
    if ($null -eq $lastItemModified) {
        $ErrorMessage += 'LastItemModified = $null Error occured on following object:'
        $ErrorMessage += $Item | select-object -property ListTitle, ListUrl, SiteUrl, MigUnitId | Out-String
        Write-Error $ErrorMessage
        return $null
    }
    return [System.TimeZoneInfo]::ConvertTime($LastItemModified, [System.TimeZoneInfo]::local)
}
