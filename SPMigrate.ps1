[CmdletBinding()]
param()

#initialize
#Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -initsp -Verbose
Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -Verbose
# open the demo site and fill the Demo Library
$TestMigrationURL = $Settings.Current.MigrationURLS | Select-Object -First 1
$script:AbsDemoSiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $TestMigrationURL.SourceTenantDomain -path $TestMigrationURL.DemoSite[0]
$script:AbsDemoListUrl = $AbsDemoSiteUrl + '/' + $TestMigrationURL.DemoList

# Create testdata : check if the SP demo library (locally stored) is already filled, if not fill it
if ($settings.environment -ne 'production') {
    New-MtHTestData -Number 50 -MaxFileSize 130000
    $files = (Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 -File)
    $script:randomfile = $files[(Get-Random -Maximum $files.count)]
}
Write-Verbose "NodeID = $($settings.NodeId)"
Write-Verbose "Used Database = $($settings.SQLDetails.Name),$($settings.SQLDetails.Database)"
$ModulePath =  -Join($Settings.FilePath.LocalWorkSpaceModule,'Public')
#Set-Location -Path $ModulePath
do {
    $action = ('++++++++++++++++++++++++++++++++++++++++++++++++++++++', 'Create DataBase', 'Remove DataBase', 'Register All Sites and Lists', 'Migrate Fake', 'Migrate Real', 
        'Deactive All Test Lists', 'Activate CSV', 'Quit') | Out-GridView -Title 'Choose Activity (Only working on dev and test env)' -PassThru
    #Make sure the testprocedures only access Dev and test.
    switch ($action) {
        'Reinitialize' {
            #not included
            New-MtHSQLDatabase
            Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            Send-MtHFiles -Library $ListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomfile) 
            Register-MtHAllSitesLists 
            # get the demolist and select it
            $listMU = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl | Where-Object { $_.ListTitle -eq $settings.current.DemoList }
            $changeitem = [PSCUSTOMOBJECT]@{
                SourceUrl       = $listMU.SourceURL
                ListUrl         = $listMU.ListUrl
                MigUnitId       = $listMU.MigUnitId
                CurrentMUStatus = 'new'
                NewMUStatus     = 'active'
            }
            Submit-MtHScopedSitesLists -ChangeItems $changeitem
        }
        'Create DataBase' {
            ### create database and MigrationUnit and MigrationRuns tables. Check if target environment is OK
            New-MtHSQLDatabase
            Write-Host 'Database Created.....'
        }
        'Remove DataBase' {
            ### create database and MigrationUnit and MigrationRuns tables. Check if target environment is OK
            Remove-MtHSQLDatabase
            Write-Host 'Database Removed.....'
        }
        'Register All Sites and Lists' {
            Start-RJDBRegistrationCycle
            #Register-MtHAllSitesLists 
        }
        'Register Set of Sites and Lists' {
            #not included
            $setofsites = @('https://247.plaza.buzaservices.nl/subject/AB1156858')
            Register-MtHAllSitesLists -setofsites $setofsites
        }
        'Detect Changes' {
            Start-MtHDetectionCycle | Out-Null
        }
        'Create Destination Sites' {
            #not included
            $SiteCollections = Get-MtHPnPTenantSite
            Get-MtHSQLMigUnits -all | 
                Where-Object { ($_.MUStatus -eq 'Active') -and $_.DestinationUrl -notin $SiteCollections.Url } |
                Select-Object -Property DestinationUrl -Unique | ForEach-Object {
                    New-PnPSite -Type TeamSite -Title $_. -Alias $_.DestinationUrl.split('/')[-1]
                }
        }
        'Migrate Fake' {
            Start-MtHExecutionCycle -Fake    
        }
        'Migrate Real' {
            Start-MtHExecutionCycle 
        }
        'Activate Demo List for Real Migration (node 1)' {
            # get the demolist and select it
            $listMU = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl | Where-Object { $_.ListTitle -eq $settings.current.DemoList }
            $changeitem = [PSCUSTOMOBJECT]@{
                MigUnitId       = $listMU.MigUnitId
                CurrentMUStatus = 'new'
                NewMUStatus     = 'active'
                NodeId          = 1
            }
            Submit-MtHScopedSitesLists -ChangeItems $changeitem
        }
        'Activate All Lists for Real Migration (node 1)' {
            $changeitems = [System.Collections.Generic.List[PSObject]]::new()
            Get-MtHSQLMigUnits -all | Where-Object { $_.Scope -eq 'List' -and ($_.MUStatus -eq 'new' -or $_.MUStatus -eq 'fake') } | Sort-Object -Property MigUnitId | ForEach-Object {
                $changeitem = [PSCUSTOMOBJECT]@{
                    MigUnitId       = $_.MigUnitId
                    NodeId          = 1
                    CurrentMUStatus = 'fake'
                    NewMUStatus     = 'active'
                }
                $changeitems.add($changeitem)
            }
            if ($changeitems) {
                Submit-MtHScopedSitesLists -ChangeItems $changeitems
            }
            else {
                Write-Host 'No new lists to activate'
            }
        }
        'Deactive All Test Lists' {
            $TestSourceURLS = [System.Collections.Generic.List[PSCustomObject]]::new()
            foreach ($MigUnitURL in $Settings.Current.MigrationURLS) {
                foreach ($DemoSite  in $MigUnitURL.DemoSite) {
                    $TestURL = ConvertTo-MtHHttpAbsPath -SourceURL $MigUnitURL.SourceTenantDomain -path $DemoSite
                    $TestSourceURLS.Add($TestURL)
                }
            }
            $dbitems = $TestSourceURLS | ForEach-Object { Get-MtHSQLMigUnits -Url $_ }
            $items = $dbitems | Where-Object { ($_.NextAction -ne 'none') }
            $items | ForEach-Object {
                $Item = [PSCustomObject]@{
                    MUStatus   = $_.MUStatus 
                    NextAction = 'none' 
                    NodeId     = $_.NodeId
                    MigUnitId  = $_.MigUnitId
                }
                Update-MtHSQLMigUnitStatus -Item $Item
            }
        }
        'Activate All Lists for Fake Migration (node 1)' {
            $changeitems = [System.Collections.Generic.List[PSObject]]::new()
            Get-MtHSQLMigUnits -all | Where-Object { $_.Scope -eq 'List' -and $_.MUStatus -eq 'new' } | Sort-Object -Property MigUnitId | ForEach-Object {
                $changeitem = [PSCUSTOMOBJECT]@{
                    MigUnitId       = $_.MigUnitId
                    NodeId          = 1
                    CurrentMUStatus = 'new'
                    NewMUStatus     = 'fake'
                }
                $changeitems.add($changeitem)
            }
            if ($changeitems) {
                Submit-MtHScopedSitesLists -ChangeItems $changeitems
            }
            else {
                Write-Host 'No new lists to activate'
            }
        }
        'Activate CSV' {
            $items = Get-MtHCsvFile
            if ($null -ne $Items ) {
                Submit-MtHScopedSitesLists -ChangeItems $items
            }
        }
        'Distribute Site collections over nodes' {
            Distribute-RJSiteCollectionsOverNodes
        }
        'Upload Random File' {
            $script:randomfile = $files[(Get-Random -Maximum $files.count)]
            # Upload New Updated File to source demolist
            #Add-Content $randomfile "`nNew Version"
            Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            #Send-MtHFiles -Library $ListTitle -FilePath $settings.FilePath.TempDocs -Files @($randomfile) 
            Send-MtHFiles -Library $AbsDemoListUrl -FilePath $settings.FilePath.TempDocs -Files @($randomfile)
        }
        'Remove Last Uploaded Random File' {
            # Remove Uploaded File from source demolist
            #Add-Content $randomfile "`nNew Version"
            Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            if ($randomfile) {
                $item = Get-PnPFolderItem -FolderSiteRelativeUrl $ListTitle -ItemType File -ItemName $randomfile.Name           
                if ($item) {
                    Remove-PnPFile -ServerRelativeUrl $item.ServerRelativeUrl -Force # Delete the first one
                    $randomfile = $null
                }
                else {
                    Write-Host 'Last Uploaded random file not found'
                }
            }
            else {
                Write-Host 'No random file uploaded '
            }      
        }
        'Remove ALL uploaded files in Demo Library' {
            Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            $items = Get-PnPFolderItem -FolderSiteRelativeUrl $ListTitle -ItemType File
            Write-Host "removing $($items.count) items"
            $items | ForEach-Object {
                Remove-PnPFile -ServerRelativeUrl $_.ServerRelativeUrl -Force # Delete them all
            }
        }
        'Remove DEMO source library directly' {
            #not included 
            # Remove Uploaded File from source demolist
            #Add-Content $randomfile "`nNew Version"
            Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            # $item = Get-MtHSQLMigUnits -All | Where-Object { $_.ListTitle -eq $settings.current.DemoList } |  Resolve-MtHMUClass -Source SQL
            $item = Get-MtHSQLMigUnits -all | Where-Object { $_.ListTitle -eq $settings.current.DemoList } 
            Remove-RJLibraryMU -MigrationItem $item 
        }
        'Run delete cycle' {
            # Remove LisMUs to be deleted from MU regisstration loop
            # Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
            #Start-RJDeletionCycle -TestDemoList
            Start-RJDeletionCycle 
        }
        'Collect DEMO List items from SQL for deletion check and process' {
            #not included
            $listMU = Get-MtHSQLMigUnits -Url $AbsDemoSiteUrl | Where-Object { $_.ListTitle -eq $settings.current.DemoList }
            $SQLMUItems = Get-RJSQLMUItems -MigUnitID $listMU.MigUnitId -ItemStatus 'existsinsource'
            Write-Host $SQLMUItems
        }
    }
} while (($action -ne 'Quit') -and ($null -ne $action))

Stop-MtHLocalPowershell