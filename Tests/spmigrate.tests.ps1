BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB

    # skip testing if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment'
    }
}
BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB
    if (!$skip) {
        # initialize sharepoint and remove the database
        Initialize-MtHSharePoint
        Remove-MtHSQLDatabase
        
        #For testing the first entry is used
        $script:AbsDemoSiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain  -path $settings.current.MigrationURLS[0].DemoSite[0]
        $script:RelDemoListUrl = $settings.current.MigrationURLS[0].DemoSite[0] + '/' + $settings.current.MigrationURLS[0].DemoList
        $script:AbsDemoListUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -path $RelDemoListUrl
    
        # Create testdata : check if the SP demo library (locally stored) is already filled, if not fill it with 3 items
        New-MtHTestData -Number 3 -MaxFileSize 25000 -RandomSize
        $script:files = (Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 -File)
        $script:randomfile = $files[1 + (Get-Random -Maximum ($files.count - 1))]

        #upload files[0] to the demo library
        Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
        Send-MtHFiles -SourceURL  $settings.current.MigrationURLS[0].SourceTenantDomain -Library $AbsDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($files[0])

        Write-Verbose "NodeID = $($settings.NodeId)"
        Write-Verbose "Used Database = $($Settings.SQLDetails.Database)"
    }
}
AfterAll {
    if (!$skip) {
        Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
        $items = Get-PnPFolderItem -FolderSiteRelativeUrl $settings.current.MigrationURLS[0].DemoList -ItemType File
        
        Write-Verbose "removing items. Keep `$files[0] so the library will be detected"
        $items | Where-Object { $_.name -ne $files[0].name } |  ForEach-Object {
            Remove-PnPFile -ServerRelativeUrl $_.ServerRelativeUrl -Force
            Write-Verbose "remove file: $($_.ServerRelativeUrl)"
        }
    }
}

Describe 'SPMigrate.tests.ps1: Testing SharePoint Migration' -Skip:$skip {
    Context '1: connecting to database and start fake migration' {
        It '1.1: New Database' {
            New-MtHSQLDatabase | Should -Be $true
        }

        It '1.1: Upload Random File to the Demo List to ensure it will be registerred' {
            Write-Verbose "Random file = $($randomfile.fullname)"
            { 
                Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null 
                Send-MtHFiles -SourceURL  $settings.current.MigrationURLS[0].SourceTenantDomain -Library $AbsDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomfile)
            } | Should -Not -Throw         
        }
        It '1.2: Register demo Sites and Lists' {
            Register-MtHAllSitesLists -filter $settings.current.MigrationURLS[0].DemoSite[0]
            $result = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl 
            $script:DemoMigUnitId = ($result | Where-Object { $_.ListUrl -eq $RelDemoListUrl }).MigUnitId
            $result.count | Should -BeGreaterOrEqual 2
        }
        It '1.3: Detect Changes. should not detect anything, because all status = NEW' {
            $itemcount = Start-MtHDetectionCycle
            $itemcount | Should -Be 0
        }
        It '1.4: Migrate Fake, should not migrate anything, because all nextaction = NONE' {
            Start-MtHExecutionCycle   
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 0
        }
        It '1.5: Activate Demo List for Fake Migration (node 1)' {
            # get the demolist and select it
            $listMU = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl | Where-Object { $_.ListTitle -eq $settings.current.MigrationURLS[0].DemoList }
            $changeitem = [PSCUSTOMOBJECT]@{
                MigUnitId       = $listMU.MigUnitId
                CurrentMUStatus = 'new'
                NewMUStatus     = 'fake'
                NodeId          = 1
            }
            Submit-MtHScopedSitesLists -ChangeItems $changeitem
            $result = Get-MtHSQLMigUnits -MigUnitId $DemoMigUnitId 
            $result.MUStatus = 'fake' 
        }
        It '1.6: Migrate Fake, the demolist should have a first migration run' {
            Start-MtHExecutionCycle 
            Start-Sleep -Seconds 1 
            Write-Verbose 'wait 1 second after the execution cycle to prevent you upload an update in the same second'
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 1 
        }
        It '1.7: Migrate Fake (second time), no changes detected on demolist, so no new migrations yet' {
            Start-MtHExecutionCycle 
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId
            $items.count | Should -Be 1 
        }
        It '1.8: Upload Random File to the Demo List' {
            $script:randomfile = $files[ 1 + (Get-Random -Maximum ($files.count - 1))] # not file 0, because that should be there
            Write-Verbose "Random file = $($randomfile.fullname)"
            Add-Content -Path $randomfile.fullname "`nNew Version $(Get-Date)"
            { 
                Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null 
                $Script:InitialItemCount = Get-PnPList -Identity $settings.current.MigrationURLS[0].demolist | Select-Object -Property ItemCount  
                Send-MtHFiles -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain   -Library $AbsDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomfile)
            } | Should -Not -Throw         
        }
        It '1.8a: doublecheck if file is uploaded' {
            Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            $list = Get-PnPList -Identity $settings.current.MigrationURLS[0].demolist
            $ExpectedCount = $Script:InitialItemCount.ItemCount + 1
            $list.ItemCount | Should -Be $ExpectedCount
        }
        It '1.9: Migrate Fake (third time), No new migration yet, because the detect cycle did not run' {
            Start-MtHExecutionCycle 
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 1 
        }
        It '1.10: Detect Changes. Detect cycle run and should have detected the change in the Demo List' {
            $itemcount = Start-MtHDetectionCycle
            $itemcount | Should -Be 1
        }
        It '1.10a : But the Delta Run is not executed yet' {
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 1 
        }
        It '1.11: Migrate Fake (forth time), Now the delta run should be recorded in the database' {
            Start-MtHExecutionCycle 
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 2 
        }
    }
    Context '2: Start a real migration' -Skip:(!$settings.startup.realmigration) {
        It '2.1: Activate Demo List for Real Migration (node 1)' {
            # get the demolist and select it
            $listMU = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl | Where-Object { $_.ListTitle -eq $settings.current.MigrationURLS[0].DemoList }
            $changeitem = [PSCUSTOMOBJECT]@{
                MigUnitId       = $listMU.MigUnitId
                CurrentMUStatus = 'fake'
                NewMUStatus     = 'active'
                NodeId          = 1
            }
            Submit-MtHScopedSitesLists -ChangeItems $changeitem
            $result = Get-MtHSQLMigUnits -MigUnitId $DemoMigUnitId 
            $result.MUStatus | Should -Be 'active' 
        }
        It '2.2: Migrate Fake (fifth time), fake should not run, because MUStatus is now ACTIVE' {
            Start-MtHExecutionCycle 
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 3 
        }
        It '2.3: Migrate Real (first time), should run' {
            Start-MtHExecutionCycle 
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 3
        }
        It '2.3a: real migration should not fail' {
            $items | Where-Object { $_.result -eq 'failed' } | Should -BeNullOrEmpty 
        }
        It '2.4: Upload Random File, should go OK' {
            $script:randomfile = $files[(Get-Random -Maximum $files.count)]          
            # Upload New Updated File to source demolist
            Add-Content -Path $randomfile.fullname "`nNew Version"
            { 
                Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
                Send-MtHFiles -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -Library $AbsDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomfile) 
            } | Should -Not -Throw 
        }
        It '2.5: Detect Changes should detect a changed demolist' {
            Start-MtHDetectionCycle 
            $result = Get-MtHSQLMigUnits -MigUnitId $DemoMigUnitId 
            $result.NextAction | Should -Be 'delta' 
        }
        It '2.6 Migrate Real (second time). This should be a delta migration' {
            Start-MtHExecutionCycle  
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 4
        }
    }
}