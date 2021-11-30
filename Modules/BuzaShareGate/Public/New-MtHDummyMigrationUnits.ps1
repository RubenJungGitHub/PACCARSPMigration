# creates TestData in SharePoint in Buckets, No unit test
function New-MtHDummyMigrationUnits {
    [CmdletBinding()]
    param (
        [Parameter()][PSCustomObject]$Buckets
    )
    Write-Verbose 'creating testdata'
    New-MtHTestData -Number ($Buckets.FileCount | Measure-Object -Maximum).Maximum -MaxFileSize 130000
    $ReRegisterSites = $false
    Write-Verbose 'Connect to DemoSite'
    
    #Add loop for all Demo sites in MigrationURLCollection
    foreach ($MigrationURL in $Settings.Current.MigrationURLS) {    
        foreach ($DemoSite  in $MigrationURL.DemoSite) {
            $script:AbsDemoSiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $MigrationURL.SourceTenantDomain -path $DemoSite
            Write-Verbose "creating lists in site: $($AbsDemoSiteUrl)"
            Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            $Lists = Get-PnPList

            foreach ($MU in $Buckets) {
                if ($MU.Amount -gt 0) {
                    forEach ($BucketNr in 1..($MU.Amount)) {
                        $ListName = "Test_$($MU.Bucket)_$BucketNr"
                        if ($ListName -notin $Lists.Title) {
                            Write-Verbose "creating SharePoint2013 List : $ListName in $AbsDemoSiteUrl" 
                            $List = New-PnPList -Title $ListName -Template DocumentLibrary
                            $ReRegisterSites = $true
                        }
                        else {
                            Write-Verbose "SharePoint2013 List : $ListName already created in $AbsDemoSiteUrl"
                        }
                        $list = Get-PnPList -Identity $ListName

                        if ($list.ItemCount -lt $MU.FileCount) {
                            do {
                                Write-Verbose "Uploading $($MU.FileCount - $list.ItemCount) items to List : $ListName in $AbsDemoSiteUrl which needs  $($MU.FileCount) items"
                                $Uploadfiles = Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 | Sort-Object { Get-Random } | Select-Object -First ($MU.FileCount - $list.ItemCount)
                                $AbsDemoListUrl = ConvertTo-MtHHttpAbsPath -SourceURL $AbsDemoSiteUrl -path $list.RootFolder.ServerRelativeURL
                                Send-MtHFiles -SourceURL $AbsDemoSiteUrl  -Library $AbsDemoListUrl -FilePath $settings.FilePath.TempDocs -Files $uploadfiles
                                $list = Get-PnPList -Identity $ListName
                            }
                            while ($list.ItemCount -lt $MU.FileCount)
                        }
                        else {
                            Write-Verbose "SharePoint2013 List : $ListName in $AbsDemoSiteUrl already contains $($list.ItemCount) items"
                        }
                    }
                }
            }
        }
    }
    return $ReRegisterSites
}

