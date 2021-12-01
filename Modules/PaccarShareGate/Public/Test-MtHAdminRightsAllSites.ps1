function Test-MtHAdminRightsAllSites {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $True)][PSCustomObject[]]$SiteCollections, 
        [switch]$check
    )
    ### get all sites in the corresponding webapp complying to Sourcevalidation ###

    #$SiteCollections = @(Get-MtHPnPTenantSite)

    $totalsites = $SiteCollections.Count
    $i = 0 
    $adminrightsites = [System.Collections.Generic.List[String]]::new()

    foreach ($SiteCollection in $SiteCollections) {
        if ($check) {            
            # connect to each site and grant Admin rights (if not received yet)
            Write-Progress -Activity 'Site Access Check' -Status "$i of $totalsites Complete" -PercentComplete $($i * 100 / $totalsites)
            try {                
                $i++
                Connect-MtHSharePoint -URL $SiteCollection.Name | Out-Null
                $Users = Get-PnPSiteCollectionAdmin -ErrorAction Stop
                Write-Verbose "The following users have admin right on $($sitecollection.URL) : $($Users.Title)"
                $adminrightsites.add($SiteCollection.Name)       
            }
            catch {
                Write-Verbose "No SiteCollection Admin rights on $($sitecollection.URL)"
                return $null
            }
        }
        else {
            $adminrightsites.add($SiteCollection.Name)           
        }
    }
    Write-Progress -Activity 'Site Access Check' -Status 'Ready' -Completed
    return $adminrightsites
}
