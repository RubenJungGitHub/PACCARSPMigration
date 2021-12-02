#Get all MUs from SharePoint and update the SQL Database accordingly
function Register-MtHAllSitesLists {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)][string]$filter, 
        [parameter(Mandatory = $True)][MigrationUnitClass[]]$MUsINSP, 
        [parameter(Mandatory = $false)][String[]]$setofsites
    )
    $i = 0

    $SiteCollections = $MUsINSP | Group-Object -Property DestinationURL | Select-Object -Property Name

    #To do group by  TargetURL ???
    # get the sites where Admin rights are granted
    if (!$filter) {
        if (!$setofsites) {
            $adminrightsites = Test-MtHAdminRightsAllSites -SiteCollections $SiteCollections
        }
        else {
            $adminrightsites = Test-MtHAdminRightsAllSites -SiteCollections $SiteCollections | Where-Object { $_ -in $setofsites }   
        }
    }
    else {
        $adminrightsites = Test-MtHAdminRightsAllSites -SiteCollections $SiteCollections | Where-Object { $_ -like "*$filter" } 
    }
    #Temp
    $totalsites = $MUsINSP.Count
    #First remove old entries 
    $SiteCollections | ForEach-Object {Invoke-MtHSQLquery -QueryName C-MUSC -SiteCollection $_.Name}



   Write-Verbose "Total amount of sites to register: $totalsites"
   $MUsINSP| ForEach-Object { $_.validate() }
    foreach ($MUinSP in $MUsINSP) {
        Write-Progress -Activity 'Site Scan' -Status "$i of $totalsites Complete" -PercentComplete $($i * 100 / $totalsites)
        
        # Get all possible Migration Units of the SiteCollection and put them in a List
        try {
            #$MUsinSP = Get-MtHOneSPSiteLists -Url $siteCollection
            
            # Get all registered Migration Units of a sitecollection from the SQL database, MU List
            $MUinSQL = Get-MtHSQLMigUnits -CompleteSourceUrl $MUinSP.CompleteSourceURL
            
            # is the MU in SharePoint new?
            if ($MUinSQL.Count -eq 0) {
                    New-MtHSQLMigUnit -Item $MUinSP
            }
            
            # no, are there any differences in site MUs?
            else {
                $Differences = Compare-Object -ReferenceObject $MUinSQL -DifferenceObject $MUinSP -Property DestinationURL
                foreach ($Diff in $Differences) {
                    
                    # add newly found objects in SP as MU in the database
                    if ($diff.SideIndicator -eq '=>') {
                        $SPObject = $MUsinSP | Where-Object { ($_.SourceUrl -eq $diff.SourceUrl) -and ($_.ListUrl -eq $diff.ListUrl) }
                        New-MtHSQLMigUnit -Item $SPObject
                    }

                    # update each not found MU in the SQL database with "not found" in this database (no deletion of records, for tracking reasons)
                    # Added logic to deleteMU's if Scope is List (ListURL is empty (Configurable in settings file)

                    if ($diff.SideIndicator -eq '<=' ) {
                        $SQLObject = $MUsinSQL | Where-Object { ($_.SourceUrl -eq $diff.SourceUrl) -and ($_.ListUrl -eq $diff.ListUrl) }
                        $SQLObject.MUStatus = 'notfound'
                        $script:NextAction = 'none'
                        if ($Settings.Current.DeleteNotFoundMUS -and ( $SQLObject.Scope -eq 'list')) {
                            $items = Invoke-MtHSQLquery -QueryName 'R-SINGLE' -ItemNr $SQLObject.MigUnitID
                            if ($Items.Count -eq 0) {
                                $script:NextAction = 'delete'
                            }
                        }
                        $SQLObject.NextAction = $script:NextAction
                        Update-MtHSQLMigUnitStatus -Item $SQLObject
                    }
                }
            } 
        }
        catch {
            # this occurs when the sitecollection does not exist anymore ???
            
            $ErrorMessage += 'Error occured on following object:'
            $ErrorMessage += $siteCollection
            Write-Error $ErrorMessage
        }
        $i++
    }
    #Update TargetNa,es if duplicate
    $Duplicates = Get-MtHSQLMigUnits -all | Group-Object -Property DestinationURL, ListTitle | Where-Object {$_.Count -gt 1}
    foreach($DPLTarget in $Duplicates.Group)
    {
        $DPLTarget.ListTitle = -Join($DPLTarget.DuplicateTargetLibPrefix,$DPLTarget.ListTitle)
        Update-MtHSQLMigUnitStatus -Item $DPLTarget -UpdateListTitle
    }
    #$Duplicates.Group | ForEach-Object ($_.ListTitle = -Join($_.TargetPrefix, $_.ListTitle))
    Write-Progress -Activity 'Site Scan' -Status 'Ready' -Completed
}
