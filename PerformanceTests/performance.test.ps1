BeforeDiscovery {
    $script:sizes = @(50, 250, 1000, 3500, 8000)
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB -or !$settings.startup.realmigration

    # skip testing if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment'
    }
}

BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test -initsp
    # Get-SqlDatabase -ServerInstance $Settings.SQLDetails.Instance
    Remove-MtHSQLDatabase
    
    # open the demo site and fill the Demo Library
    $TestMigrationURL = $Settings.Current.MigrationURLS | Select-Object -first 1
    $script:AbsDemoSiteUrl = ConvertTo-MtHHttpAbsPath -path $TestMigrationURL.DemoSite
    $script:RelDemoListUrl = $TestMigrationURL.DemoSite + '/' + $settings.current.DemoList
    $script:AbsDemoListUrl = ConvertTo-MtHHttpAbsPath -path $RelDemoListUrl
    
    # Create testdata : check if the SP demo library (locally stored) is already filled, if not fill it
    New-MtHTestData -Number ($sizes | Measure-Object -Maximum).Maximum
    
    $files = (Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 -File)
    $script:randomfile = $files[(Get-Random -Maximum $files.count)]

    Write-Verbose "NodeID = $($settings.NodeId)"
    Write-Verbose "Used Database = $($Settings.SQLDetails.Database)"

    New-MtHSQLDatabase
}
AfterAll {
    # Remove ALL uploaded files in Demo Library'
    Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
    $items = Get-PnPFolderItem -FolderSiteRelativeUrl $settings.current.DemoList -ItemType File
    Write-Verbose "removing $($items.count - 1) items. Keep 1 so the library will be detected"
    $items | Select-Object -First ($items.count - 1) |  ForEach-Object {
        Remove-PnPFile -ServerRelativeUrl $_.ServerRelativeUrl -Force # Delete them all
        Write-Verbose "remove file: $($_.ServerRelativeUrl)"
    }
    Remove-MtHSQLDatabase
    Write-Verbose 'Database Removed.....'
    Stop-MtHLocalPowershell
}

Describe 'Testing SharePoint Migration' -Skip:$skip {
    Context '1: connecting to database and register demo site' {
        It '1.2: Register demo Sites and Lists' {
            Register-MtHAllSitesLists -filter $TestMigrationURL.DemoSite
            $result = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl 
            $script:DemoMigUnitId = ($result | Where-Object { $_.ListUrl -eq $RelDemoListUrl }).MigUnitId
            $result.count | Should -BeGreaterOrEqual 2
        }
        It '2.1: Activate Demo List for Real Migration (node 1)' {
            # get the demolist and select it
            $listMU = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl | Where-Object { $_.ListTitle -eq $settings.current.DemoList }
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
    }
    Context '2: Start a real migration' -Skip:(!$settings.startup.realmigration) {
        It '2.1: Activate Demo List for Real Migration (node 1)' {
            # get the demolist and select it
            $listMU = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl | Where-Object { $_.ListTitle -eq $settings.current.DemoList }
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
            Start-MtHExecutionCycle -Fake  
            $Items = Get-MtHSQLMigRuns -MigUnitId $DemoMigUnitId 
            $items.count | Should -Be 2 
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
                Send-MtHFiles -Library $AbsDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomfile) 
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