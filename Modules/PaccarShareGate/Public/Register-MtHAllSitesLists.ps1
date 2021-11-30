#Get all MUs from SharePoint and update the SQL Database accordingly
function Register-MtHAllSitesLists {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)][string]$filter, 
        [parameter(Mandatory = $false)][String[]]$setofsites
    )
    $i = 0

    # get the sites where Admin rights are granted
    if (!$filter) {
        if (!$setofsites) {
            $adminrightsites = Test-MtHAdminRightsAllSites
        }
        else {
            $adminrightsites = Test-MtHAdminRightsAllSites | Where-Object { $_ -in $setofsites }   
        }
    }
    else {
        $adminrightsites = Test-MtHAdminRightsAllSites | Where-Object { $_ -like "*$filter" } 
    }
    
    $totalsites = $adminrightsites.Count
    Write-Verbose "Total amount of sites to register: $totalsites"

    foreach ($SiteCollection in $adminrightsites) {
        Write-Progress -Activity 'Site Scan' -Status "$i of $totalsites Complete" -PercentComplete $($i * 100 / $totalsites)
        
        # Get all possible Migration Units of the SiteCollection and put them in a List
        try {
            $MUsinSP = Get-MtHOneSPSiteLists -Url $siteCollection
            $MUsinSP | ForEach-Object { $_.validate() }
            
            # Get all registered Migration Units of a sitecollection from the SQL database, MU List
            $MUsinSQL = Get-MtHSQLMigUnits -Url $SiteCollection
            
            # is the MU in SharePoint new?
            if ($MUsinSQL.Count -eq 0) {
                foreach ($MU in $MUsinSP) {
                    New-MtHSQLMigUnit -Item $MU
                }
            }
            
            # no, are there any differences in site MUs?
            else {
                $Differences = Compare-Object -ReferenceObject $MUsinSQL -DifferenceObject $MUsinSP -Property SourceUrl, ListUrl
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

                # are there any differences in list itemcount?
                $DifferencesItemCount = Compare-Object -ReferenceObject $MUsinSQL -DifferenceObject $MUsinSP -Property SourceUrl, ListUrl, ItemCount
                foreach ($Diff in $DifferencesItemCount) {
                    if ($diff.SideIndicator -eq '=>' ) {

                        #Only get the item from SQL where itemcount deviates 
                        $MUinSQL = $MUsinSQL | Where-Object { ($_.SourceUrl -eq $diff.SourceUrl) -and ($_.ListUrl -eq $diff.ListUrl) -and ($_.ItemCount -ne $diff.ItemCount) }
                        
                        #Get the correct diffobject for update . This is required to prevent updates of itemcount for all newly added MUs in the section above
                        $SPObject = $MUsinSP | Where-Object { ($_.SourceURL -eq $MUinSQL.SourceUrl) -and ($_.ListURL -eq $MUinSQL.ListUrl) } 
                        if ($null -ne $SPObject) {
                            $SPObject.MigUnitId = $MUinSQL.MigUnitId
                            Update-MtHSQLMigUnitStatus -Item $SPObject -updateitemcount
                        }
                    }
                }
            } 
        }
        catch {
            # this occurs when the sitecollection does not exist anymore ???
            $ErrorMessage = $_ | Out-String
            $ErrorMessage += 'Error occured on following object:'
            $ErrorMessage += $siteCollection
            Write-Error $ErrorMessage
        }
        $i++
    }
    Write-Progress -Activity 'Site Scan' -Status 'Ready' -Completed
}
