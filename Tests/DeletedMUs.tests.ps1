BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test
    $script:skip = !$Settings.Current.DeleteNotFoundMUS -OR ($Settings.Current.ExecuteTestOnDB -eq 'None') -OR ($Settings.Current.ExecuteTestOnDB -eq '$null') -OR (!$settings.SQLdetails) -OR (!$settings.SQLdetails.DeleteDB)
    #Comment added for test porting solution to AEF
    # skip testing if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment' 
    }
}
BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test
    $dir = Get-MtHGitDirectory

 
    
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    }
    #Determine Source URL's
    $script:DemoList = $Settings.Current.MigrationURLS[0].DemoList
   # $SourceSiteName = -join (($settings.current.MigrationURLS[0].DemoSite[0].Split('/'))[($settings.current.MigrationURLS[0].DemoSite[0].Split('/')).Count - 1])
    $script:AbsSourceDemoSiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -path $settings.current.MigrationURLS[0].DemoSite[0]
    $script:RelSourceDemoListUrl = $settings.current.MigrationURLS[0].DemoSite[0] + '/' + $settings.current.MigrationURLS[0].DemoList
    $script:AbsSourceDemoListUrl = ConvertTo-MtHHttpAbsPath  -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -path $RelSourceDemoListUrl
    $script:SourceDemoListItemCount = 0

    #Determine Target URL's
    $script:AbsTargetDemoSiteUrl = ConvertTo-MtHDestinationUrl -SourceUrl $AbsSourceDemoSiteUrl
    $script:RelTargetDemoListUrl = $RelSourceDemoListUrl -replace $SourceSiteName, $TargetSiteName
    $script:AbsTargetDemoListUrl = -Join ($script:AbsTargetDemoSiteUrl, '/', $settings.current.MigrationURLS[0].DemoList)
    $script:TargetDemoListItemCount = 0

    # Get-SqlDatabase -ServerInstance $Settings.SQLDetails.Instance
    if (!$Skip) {
        Remove-MtHSQLDatabase
    }

    # Create testdata 
    New-MtHTestData -MaxFileSize 25000 -Number 10 -RandomSize
    #Clear lists 
    Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
    $List = Get-PnPList -Identity $settings.Current.MigrationURLS[0].DemoList
    If ($List -ne $null) {
        $List | Get-PnPListItem -PageSize 100 -Scriptblock { Param($items) $items.Context.ExecuteQuery() } | ForEach-Object { $_.DeleteObject() }
    }
       
       
    Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
    $List = Get-PnPList -Identity $settings.Current.MigrationURLS[0].DemoList
    If ($List -ne $null) {
        $List | Get-PnPListItem -PageSize 100 -Scriptblock { Param($items) $items.Context.ExecuteQuery() } | ForEach-Object { $_.DeleteObject() }
    }
}

AfterAll {
    # Remove ALL uploaded files in Demo Library'
    Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
    $List = Get-PnPList -Identity $settings.Current.MigrationURLS[0].DemoList
    If ($List -ne $null) {
        $List | Get-PnPListItem -PageSize 100 -Scriptblock { Param($items) $items.Context.ExecuteQuery() } | ForEach-Object { $_.DeleteObject() }
    }
    
    
    Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
    $List = Get-PnPList -Identity $settings.Current.MigrationURLS[0].DemoList
    If ($List -ne $null) {
        $List | Get-PnPListItem -PageSize 100 -Scriptblock { Param($items) $items.Context.ExecuteQuery() } | ForEach-Object { $_.DeleteObject() }
    }
    
    Write-Verbose 'Source and target libraries cleared .....'
    Stop-MtHLocalPowershell -test
}

Describe 'MigrationUNit Deletion-cycle tests.ps1: ' -Skip:$skip {
    Context '1: Recreate DB, Create source and target demolists and register demo site' -Skip:$skip {

        It '1.0: Empties the database, database should have 0 entries' {
            New-MtHSQLDatabase
            $result = Get-MtHSQLMigUnits
            $result | Should -BeNullOrEmpty
        }

        It '1.1: Get initial Sourcedemolist itemcount ' {
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            $List = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            If ($List -ne $null) {
                $script:SourceDemoListItemCount = $List.itemcount
            }
            $script:SourceDemoListItemCount | Should -BeGreaterOrEqual 0
        }

        It '1.2: Upload Random File to the source Demo List' {
            $Script:randomuploadfiles = Get-ChildItem $settings.FilePath.TempDocs | Get-Random -Count 1
            Write-Verbose "Random file = $($Script:randomfile.fullname)"
            { 
                Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null 
                Send-MtHFiles  -SourceURL $script:AbsSourceDemoSiteUrl   -Library $AbsSourceDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomuploadfiles)
            } | Should -Not -Throw         
        }

        It '1.3: Doublecheck if files are uploaded to source demo list' {
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            $list = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            $ExpectedResult = $script:SourceDemoListItemCount + 1
            $list.ItemCount | Should -Be $ExpectedResult
        }
   
        It '1.4: Create Destination demo list if non existant' {
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            $list = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            If ($List -eq $null) {
                $List = New-PnPList -Title $Settings.Current.MigrationURLS[0].demolist -Template DocumentLibrary
            } 
            $script:TargetDemoListItemCount = $List.itemcount
            $List | Should -Not -Be $null    
        }

        It '1.5: Upload Random File to the destination Demo List' {
            Write-Verbose "Random file = $($Script:randomfile.fullname)"
            { 
                Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null 
                Send-MtHFiles  -SourceURL $script:AbsTargetDemoSiteUrl   -Library $AbsTargetDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($Script:randomuploadfiles)
            } | Should -Not -Throw         
        }

        It '1.6: Doublecheck if files are uploaded to target demo list' {
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            $list = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            $ExpectedResult = $script:TargetDemoListItemCount + 1
            $list.ItemCount | Should -Be $ExpectedResult
        }

        It '1.7: Register Source demo Sites and Lists' {
            Register-MtHAllSitesLists -filter $AbsSourceDemoSiteUrl
            $result = Get-MtHSQLMigUnits -Url $AbsSourceDemoSiteUrl 
            $result.count | Should -BeGreaterOrEqual 2
        }
    }

    Context '2: Activate Demolist, remove sourcelist and register sites again '-Skip:$skip {
        It '2.0 : Because source still exists the target must remain after MU deletion cycle!' {
            Mock -CommandName Invoke-MtHSQLquery -MockWith {
                Return (
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $AbsSourceDemoSiteUrl
                        DestinationUrl  = $AbsTargetDemoSiteUrl
                        ListUrl         = $RelSourceDemoListUrl
                        ListTitle       = $DemoList
                        MigUnitId       = '2'
                        MUStatus        = 'notfound'
                        NextAction      = 'delete'
                        ListId          = '1234'
                        Scope           = 'list'
                        ItemCount       = 1
                    }
                )
            }
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            #First get all lists in source site prior to deletion
            $SourceListsNamesPriorToDeletion = Get-PnPList 
            
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            #First get all lists in target site prior to deletion
            $TargetListsNamesPriorToDeletion = Get-PnPList 
            
            #Start deletion cycle
            Start-RJDeletionCycle -TestDemoList

            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            #Then get all lists in source site after to deletion
            $SourceListsNamesAfterDeletion = Get-PnPList 
            
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            #And get all lists in target site after deletion
            $TargetListsNamesAfterDeletion = Get-PnPList 

            $DifferencesSource = Compare-Object -ReferenceObject $SourceListsNamesPriorToDeletion -DifferenceObject $SourceListsNamesAfterDeletion -Property Title
            $DifferencesTarget = Compare-Object -ReferenceObject $TargetListsNamesPriorToDeletion -DifferenceObject $TargetListsNamesAfterDeletion -Property Title

            $DifferencesSource | Should -BeExactly $null
            $DifferencesTarget | Should -BeExactly $null
        }

        It '2.1: Remove source demolist' {
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            #First get all lists in source site prior to deletion
            $SourceListsNamesPriorToDeletion = Get-PnPList 
            
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            #First get all lists in target site prior to deletion
            $TargetListsNamesPriorToDeletion = Get-PnPList 
            
            #Remove demo list from source
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            Remove-PnPList -Identity $Settings.Current.MigrationURLS[0].DemoList -Force
            #Get all lists in source site after deletion
            $SourceListsNamesAfterDeletion = Get-PnPList 
         
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            #And get all lists in target site after deletion
            $TargetListsNamesAfterDeletion = Get-PnPList 

            $DifferencesSource = Compare-Object -ReferenceObject $SourceListsNamesPriorToDeletion -DifferenceObject $SourceListsNamesAfterDeletion -Property Title
            $DifferencesTarget = Compare-Object -ReferenceObject $TargetListsNamesPriorToDeletion -DifferenceObject $TargetListsNamesAfterDeletion -Property Title

            $DifferencesSource.Title | Should -BeExactly  $DemoList
            $DifferencesSource.SideIndicator | Should -BeExactly '<='
            $DifferencesTarget | Should -Be $null
        }
        
        It '2.2: Register Source demo Sites and Lists and check changes(Nextaction to be "delete")' {
            Register-MtHAllSitesLists -filter $AbsSourceDemoSiteUrl
            $result = Get-MtHSQLMigUnits -Url $AbsSourceDemoSiteUrl | Where-Object { $_.ListUrl -eq $RelSourceDemoListUrl }
            $Result.NextAction | Should -BeExactly 'delete'
        }

        It '2.3: Delete MU from target and check differences' {
            
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            #First get all lists in source site prior to deletion
            $SourceListsNamesPriorToDeletion = Get-PnPList 
            
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            #First get all lists in target site prior to deletion
            $TargetListsNamesPriorToDeletion = Get-PnPList 
                        
            #Start deletion cycle
            Start-RJDeletionCycle -TestDemoList

            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            #Then get all lists in source site after to deletion
            $SourceListsNamesAfterDeletion = Get-PnPList 
            
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            #And get all lists in target site after deletion
            $TargetListsNamesAfterDeletion = Get-PnPList  

            $DifferencesSource = Compare-Object -ReferenceObject $SourceListsNamesPriorToDeletion -DifferenceObject $SourceListsNamesAfterDeletion -Property Title
            $DifferencesTarget = Compare-Object -ReferenceObject $TargetListsNamesPriorToDeletion -DifferenceObject $TargetListsNamesAfterDeletion -Property Title

            $DifferencesTarget.Title | Should -BeExactly $DemoList
            $DifferencesTarget.SideIndicator | Should -BeExactly '<='
            $DifferencesSource | Should -Be $null
        }

        It '2.4: Check MU State is reset to none after deletion to prevent deletion chain (Nextaction should be "None")' {
            $result = Get-MtHSQLMigUnits -Url $AbsSourceDemoSiteUrl | Where-Object { $_.ListUrl -eq $RelSourceDemoListUrl }
            $result.NextAction | Should -BeExactly 'none'
        }
        
        It '2.5: Register Source demo Sites again  and Lists and check changes (Nextaction should remain "None")' {
            Register-MtHAllSitesLists -filter $AbsSourceDemoSiteUrl
            $result = Get-MtHSQLMigUnits -Url $AbsSourceDemoSiteUrl |  Where-Object { $_.ListUrl -eq $RelSourceDemoListUrl }
            $result.NextAction | Should -BeExactly 'none'
        }

        It '2.6: Check MIgrunId status' {
            $MIgUNit = Get-MtHSQLMigUnits -Url $AbsSourceDemoSiteUrl |  Where-Object { $_.ListUrl -eq $RelSourceDemoListUrl }
            $result = Get-MtHSQLMigRuns -MigUnitId $MIgUNit.MigUnitId
            $result.result | Should -BeExactly 'Deleted'
        }
        It '2.7: Check Lists are removed from both environments ' {

            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            #Then get all lists in source site 
            $SourceListsNames = Get-MtHOneSPSiteLists -Url $AbsSourceDemoSiteUrl  #Get-PnPList (Also returns HIdden lists like Shared-Links)
            
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            #And get all lists in target site
            $TargetListsNames = Get-MtHOneSPSiteLists -Url $AbsSourceDemoSiteUrl  #Get-PnPList (Also returns HIdden lists like Shared-Links)

            $Differences = Compare-Object -ReferenceObject $SourceListsNames -DifferenceObject $TargetListsNames -Property Title
            $Differences | Should -BeExactly $null
        }
    }
}