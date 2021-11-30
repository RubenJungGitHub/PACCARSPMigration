using module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test
    #Double check execution 
    $script:skip = !$Settings.Current.MUSourceItemsDeleteSync -OR ($Settings.Current.ExecuteTestOnDB -eq 'None') -OR ($Settings.Current.ExecuteTestOnDB -eq '$null') -OR (!$settings.SQLdetails) -OR (!$settings.SQLdetails.DeleteDB)
    #Comment a for test porting solution to AEF
    # skip testing if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment' 
    }
}
BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test
    Initialize-MtHSharePoint 
    $dir = Get-MtHGitDirectory
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    } 
    #Determine Source URL's
    $script:DemoList = $Settings.Current.MigrationURLS[0].DemoList
    $SourceSiteName = -join (($settings.current.MigrationURLS[0].DemoSite[0].Split('/'))[($settings.current.MigrationURLS[0].DemoSite[0].Split('/')).Count - 1])
    $script:AbsSourceDemoSiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -path $settings.current.MigrationURLS[0].DemoSite[0]
    $script:RelSourceDemoListUrl = $settings.current.MigrationURLS[0].DemoSite[0] + '/' + $DemoList
    $script:AbsSourceDemoListUrl = ConvertTo-MtHHttpAbsPath  -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -path $RelSourceDemoListUrl

    #Determine Target URL's
    $script:AbsTargetDemoSiteUrl = ConvertTo-MtHDestinationUrl -SourceUrl $AbsSourceDemoSiteUrl
    $script:RelTargetDemoListUrl = $RelSourceDemoListUrl -replace $SourceSiteName, $TargetSiteName
    $script:AbsTargetDemoListUrl = -Join ($script:AbsTargetDemoSiteUrl, '/', $DemoList)
    

    #Define boudaries
    $script:MinRandomFileCount = 10 
    $script:MaxRandomFileCount = 20
    $script:MinRandomFileSize = 1024  #1kb
    $script:MaxRandomFileSize = 102400  #100kb

    $Script:SourceListItems = New-Object System.Collections.Generic.List[PSCustomObject]
    $Script:TargetListItems = New-Object System.Collections.Generic.List[PSCustomObject]
    
    #Randomfiles
    $script:RandomFileCount = Get-Random -Minimum $script:MinRandomFileCount -Maximum $script:MaxRandomFileCount
    New-MtHTestData -Number $script:RandomFileCount -MaxFileSize 200000 -RandomSize
    $Script:randomuploadfiles = Get-ChildItem $settings.FilePath.TempDocs | Where-Object { $_.Length -ge $script:MinRandomFileSize -and $_.Length -le $script:MaxRandomFileSize } | Get-Random -Count $RandomFileCount 
    $script:RandomFileCount = $randomuploadfiles.Length

    if (!$Skip) {
        Remove-MtHSQLDatabase
        # Create testdata 
        New-MtHTestData -MaxFileSize 25000 -Number 10 -RandomSize
    }
}

AfterAll {
    Stop-MtHLocalPowershell -test
}

Describe 'Migrationitems deleted source items sync-cycle ' -Skip:$skip {

    Context '1: (Re)create database, source and target demolists, add random items'  -Skip:$skip {

        It '1.0: Empties the database, database should have 0 entries' {
            New-MtHSQLDatabase
            $result = Get-MtHSQLMigUnits
            $result | Should -BeNullOrEmpty
        }

        It '1.1: Initial Source-demolist removal' {
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            Remove-PnPList -Identity $DemoList -Force 
            $List = Get-PnPList -Identity $DemoList
            $List | Should -Be $Null
        }
      
        It '1.2: Initial upload random files to the Source Demo List' {

            { 
                Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null 
                Write-Verbose "Random files = $($randomuploadfiles)"
                Send-MtHFiles  -SourceURL $script:AbsSourceDemoSiteUrl  -Library $AbsTargetDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomuploadfiles)
            } | Should -Not -Throw         
        }
        
        It '1.3: Check all files uploaded to Source lib and collect for sync comparison' {
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null 
            $List = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            $Script:SourceListItems = Get-PnPFolderItem -FolderSiteRelativeUrl $List.Title -ItemType File 
            $List.ItemCount | Should -Be $script:RandomFileCount
        }

        It '1.4: Initial Target-demolist removal' {
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            Remove-PnPList -Identity $DemoList -Force 
            $List = Get-PnPList -Identity $DemoList
            $List | Should -Be $Null
        }

        It '1.5: Initial upload random files to the target Demo List' {
            { 
                Connect-MtHSharePoint -URL $AbstargetDemoSiteUrl | Out-Null 
                Write-Verbose "Random files = $($randomuploadfiles)"
                Send-MtHFiles  -SourceURL $script:AbsTargetDemoSiteUrl  -Library $AbsTargetDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomuploadfiles)
            } | Should -Not -Throw         
        }
        
        It '1.6: Check all files uploaded to Target lib and collect for sync comparison' {
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null 
            $List = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            $Script:TargetListItems = Get-PnPFolderItem -FolderSiteRelativeUrl $List.Title -ItemType File 
            $List.ItemCount | Should -Be $script:RandomFileCount
        }
               
        It '1.7: Registers 1 site, Database Should have at at least 2 rows of input1 URL' {
            # and run 1 registration cycle to look if the database gets the expected status
            Register-MtHAllSitesLists -filter $settings.current.MigrationURLS[0].DemoSite[0]
            $script:result = Get-MtHSQLMigUnits -Url  $settings.current.MigrationURLS[0].DemoSite[0] -all
            $result.count | Should -BeGreaterOrEqual 2
        }

        It '1.8: ensure source and target are fully in sync!' {
            $Differences = Compare-Object -ReferenceObject $Script:SourceListItems -DifferenceObject $Script:TargetListItems -Property Name, Length
            $Differences | Should -Be $null      
        }
    }

    Context '2: Delete items from source and verify  source demolist itemcount' {
        It '2.00 : Get demo list ID' {    
            $Script:DemoListID =  (Get-MtHSQLMigUnits -URL $AbsSourceDemoSiteUrl | where-Object {$_.ListUrl  -eq  $RelSourceDemoListUrl } | Select-Object -Property  ListID).ListID    
            $DemoListID.Length | Should -BeExactly 36
        }
        #Delete cycle 
        It '2.01 : Run delete Cycle : No sync should take place because source and target should be in sync' {    
            Mock -CommandName Invoke-MtHSQLquery -MockWith {
                Return (
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $AbsSourceDemoSiteUrl
                        DestinationUrl  = $AbsTargetDemoSiteUrl
                        ListUrl         = $RelSourceDemoListUrl
                        ListTitle       = $DemoList
                        MigUnitId       = '2'
                        MUStatus        = 'active'
                        NextAction      = 'delta'
                        ListId          = $DemoListID
                        Scope           = 'list'
                        ItemCount       = 1
                    }
                )
            }
            $MigRuns = Get-MtHSQLMigRuns -all
            Start-RJDeletionCycle -TestDemoList
            $Result = Get-MtHSQLMigRuns -all
            If($Result -ne $null  -and $MigRuns -ne $Null){$Differences = Compare-Object -ReferenceObject $Result  -DifferenceObject $Migruns}
            $Differences |  Should -Be $Null
        }
        It '2.1 : Delete random set of files from source ' {    
            $script:RandomFileCountDelete = Get-Random -Minimum 1 -Maximum ($script:MinRandomFileCount - 1)
            $Script:randomuploadfilesdelete = $Script:RandomUploadFiles | Select-Object -First $script:RandomFileCountDelete 
            #Delete  items 
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null 
            foreach ($listitem in $Script:randomuploadfilesdelete) {
                $File = -join ($RelSourceDemoListUrl, '/', $ListItem.Name)
                Remove-PnPFile -ServerRelativeUrl $File -Force
            }
            $List = Get-PnPList -Identity $settings.Current.MigrationURLS[0].DemoList
            $expectedResult = $Script:RandomUploadFiles.Length - $script:randomuploadfilesdelete.Count
            $List.ItemCount | Should -BeExactly $Expectedresult
        }

        #rename files      
        It '2.2 : Rename remaining other files ' {
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null 
            $Files = Get-PnPListItem -List $DemoList -PageSize 1000 | Where-Object { $_['FileLeafRef'] -like '*.*' }
            #Loop through each File and rename
            ForEach ($File in $Files) { 
                #Rename File
                Rename-PnPFile -ServerRelativeUrl $File['FileRef'] -TargetFileName "$($File['FileLeafRef'])-RenamedInSource" -OverwriteIfAlreadyExists -Force
            }
        }

        #Delta Migrate to check if files are  added after rename
        It '2.3 : Delta Migrate and verify itemcount renamed files added and collect target content' {    
            $DemoItem = Get-MtHSQLMigUnits -all |   where-object {$_.ListUrl  -eq  $RelSourceDemoListUrl}
            $DemoItem.MUStatus='active'
            $DemoItem.NextAction = 'delta'
            Update-MtHSQLMigUnitStatus -Item $DemoItem
            Start-MtHExecutionCycle 
            #Wait for the complete migration to complete. Trial and error led to the conclusion if the list is consulted to soon the itemcount is invalid
            Start-sleep -seconds 60
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            $TargetList = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            $ExpectedResult = ($script:randomuploadfiles.Count*2) - $Script:randomuploadfilesdelete.Count
            $TargetList.ItemCount | Should -BeExactly $ExpectedResult
        }

        #Delete cycle 
        It '2.4 : Delete cycle, compare content in source and target and ensure they are fully synced' {   
            $DemoItem = Get-MtHSQLMigUnits -all |   where-object {$_.ListUrl  -eq  $RelSourceDemoListUrl}
            $DemoItem.MUStatus='active'
            $DemoItem.NextAction = 'delta'
            Update-MtHSQLMigUnitStatus -Item $DemoItem 
            Start-RJDeletionCycle -TestDemoList
            Connect-MtHSharePoint -URL $AbsSourceDemoSiteUrl | Out-Null
            $List = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            $SourceItems = Get-PnPFolderItem -FolderSiteRelativeUrl $List.Title -ItemType File 
            Connect-MtHSharePoint -URL $AbsTargetDemoSiteUrl | Out-Null
            $List = Get-PnPList -Identity $Settings.Current.MigrationURLS[0].demolist
            $TargetItems = Get-PnPFolderItem -FolderSiteRelativeUrl $List.Title -ItemType File 
            $Differences = Compare-Object -ReferenceObject $SourceItems -DifferenceObject $TargetItems  -Property Name, Length
            $Differences | Should -Be $null
        }
    }
}