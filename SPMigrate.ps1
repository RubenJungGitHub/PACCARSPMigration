[CmdletBinding()]
param()

#initialize
start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -Verbose  -InitSP
# open the demo site and fill the Demo Library
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
# Create testdata : check if the SP demo library (locally stored) is already filled, if not fill it
if ($settings.environment -ne 'production') {
    # New-MtHTestData -Number 50 -MaxFileSize 130000
    $files = (Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 -File)
    $script:randomfile = $files[(Get-Random -Maximum $files.count)]
}
Write-Verbose "NodeID = $($settings.NodeId)"
Write-Verbose "Used Database = $($settings.SQLDetails.Name),$($settings.SQLDetails.Database)"
#Set-Location -Path $ModulePath
do {
    $action = ('++++++++++++++++++++++++++++++++++++++++++++++++++++++', 'Create DataBase', 'Remove DataBase', '************************************' , 'Update DB Rootsource', 'Deactivate Set of Sites and Lists in DB', '************************************' , 'Register Set of Sites and Lists for first migration', 'Register Set of Sites and Lists for delta migration', '************************************' , 'Reset runs after truncation', 'Verify SP connections (prior to migrate)', 'Verify lists to migrate in source', 'Migrate Real', 'Verify lists migrated in target (Verify in source FIRST)', 'Inherit premissions from source (Migrate FIRST!)', 
        'Delete MU-s from target', '************************************', 'Clear Navigation' , 'Create Navigation', '************************************', 'Quit') | Out-GridView -Title 'Choose Activity (Only working on dev and test env)' -PassThru
    #Make sure the testprocedures only access Dev and test.
    switch ($action) {
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
            Register-MtHAllSitesLists 
        }
        'Update DB Rootsource' {
            $sql = @"
            SELECT  * FROM [MigrationUnits] 
"@   
            $MUS = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql | Resolve-MtHMUClass
            foreach ($Mu in $MUS) {
                $MU.SourceRoot, $MU.SourceURL, $MU.ListURL , $MU.ListTitle = ExtractFrom-RJSourceURL -sourceurl  $Mu.CompleteSourceUrl
                $sql = @"
            Update MigrationUnits Set SourceRoot = '$($Mu.SourceRoot)' where MigUnitID = $($Mu.MigUnitId)
"@   
                Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql 
            }
        }

        'Deactivate Set of Sites and Lists in DB' {
            #not included
            $Items = Start-RJDBRegistrationCycle -NextAction "None"
            ForEach ($Item in $Items) {
                $sql = @"
                Update MigrationUnits SET NextAction ='none' where CompleteSourceURL = '$($Item.CompleteSourceURL)' and DestinationURL = '$($Item.DestinationUrl)' 
"@
                Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
            }
        }
        
        'Register Set of Sites and Lists for first migration' {
            #not included
            $Items = Start-RJDBRegistrationCycle -NextAction "First"
            If ($Null -ne $Items) { Register-MtHAllSitesLists -MUsINSP $Items -NextAction "First" }
        }
        'Register Set of Sites and Lists for delta migration' {
            #not included
            $Items = Start-RJDBRegistrationCycle  -NextAction "Delta"
            If ($Null -ne $Items) { Register-MtHAllSitesLists -MUsINSP $Items -NextAction "Delta" }
        }
        'Verify SP connections (prior to migrate)' {
            #Connect-MtHSharePoint
            Start-MtHExecutionCycle -TestSPConnections
        }
        'Reset runs after truncation' {
            $sql = @'
            Delete from MigrationRuns  Where Result = 'Started';
'@
            Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
        }
        'Migrate Fake' {
            Start-MtHExecutionCycle -Fake    
        }
        'Verify lists to migrate in source' {
            $MUsForValidation = Select-RJMusForProcessing -Action 'Verify'
            foreach ($MUURL in $MUsForValidation) {
                $SourceRoot = $MUURL.SubItems[2].Text
                $DestinationURL = $MUURL.SubItems[3].Text
                $SQL = @"
                SELECT   *
                FROM [PACCARSQLO365].[dbo].[MigrationUnits]
                Where SourceRoot = '$($SourceRoot)'  And DestinationURL = '$($DestinationURL)'
                Order By DestinationURL
"@
                $MUSforValidation = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql | Group-Object -Property SourceURL
                ForEach ($MUSource  in  $MUSforValidation) {
                    $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
                    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserNameSP2010, $securePwd
                    Connect-PnPOnline -URL $MUSource.Name -Credentials $cred -ErrorAction SilentlyContinue
                    ForEach ($MUGroup  in  $MUSource.Group) {
                        try {
                            $List = Get-PnPList -Identity $MUGroup.ListTitle
                            if ($Null -ne $List) {
                                Write-Host "$($List.Title) detected in $($MuSource.name)" -f green
                                $SQL = @"
                                UPDATE MigrationUnits Set Itemcount = $($List.ItemCount) where ListURL = '$($list.RootFolder.ServerRelativeUrl)'
"@
                                Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql

                            }
                            else {
                                Write-Host "$($MUGroup.ListTitle) NOT detected in source $($MUGroup.SourceURL). DB Message : $($MU.ListID) " -f red
                            }                        
                        }
                        catch {
                            Write-Host "$($MUGroup.ListTitle) NOT detected in source  $($MUGroup.SourceURL)" -f red
                        }
                    }
                }
                Write-Host "Verification completed!" 
            }
        }
        'Migrate Real' {
            Start-MtHExecutionCycle 
            Write-Host "Migration completed!" -b Green 
        }
        'Verify lists migrated in target (Verify in source FIRST)' {
            $MUsForValidation = Select-RJMusForProcessing -Action 'Verify'
            foreach ($MUURL in $MUsForValidation) {
                $SourceRoot = $MUURL.SubItems[2].Text
                $DestinationURL = $MUURL.SubItems[3].Text
                #GetUniqueLists for target
                $sql = @"
            SELECT   ListTitle, ListTitleWithPrefix, LISTID, MergeMUS, SUM(ItemCount) As ItemCount
            FROM [MigrationUnits] 
            Where DestinationURL = '$($DestinationURL)' and SourceRoot = '$($SourceRoot)'
            Group by ListTitle, ListID, MergeMUs, ListTitleWithPrefix
            Order By ListTitle
"@      
                $UniqueMUS = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql 
                Connect-MtHSharePoint -URL $DestinationURL | out-null
                Write-Host "Detected $($UniqueMUS.Count) Migration units for connected destination site $($URL)" -b green
                foreach ($MuforValidation in $UniqueMUS) {

                    try {
                        $List = Get-PnPList -Identity $MuforValidation.ListID -ErrorAction Stop
                        if ($Null -ne $List) {
                            if ($MuForValidation.ListTitle -ne $List.Title) {
                                Write-Host "Double check this MU. The name in the DB is $($MuforValidation.ListTitle) but based on the ListID $($List.RootFolder.ServerRelativeUrl) the target site returns $($List.Title) " -BackgroundColor Red
                            }

                            $ItemCountMatch = $List.ItemCount -eq $MuforValidation.ItemCount
                            Write-Host "$($List.Title) ID $($List.ID) detected in $($List.RootFolder.ServerRelativeUrl)" -f green
                            if ($ItemCountMatch) {
                                Write-Host "Source itemcount : $($MuforValidation.ItemCount) - Target itemcount $($List.ItemCount) -> match : $($ItemCountMatch) MUsMerged : $($MuforValidation.MergeMUS)" -f green 
                            }
                            else {
                                Write-Host "Source itemcount : $($MuforValidation.ItemCount) - Target itemcount $($List.ItemCount) -> match : $($ItemCountMatch) MUsMerged : $($MuforValidation.MergeMUS)" -f yellow 
                            }
                        }            
                    }
                    catch {
                        Write-Host "$($MuforValidation.ListTitle) / $($MuforValidation.ListTitleWithPrefix) NOT detected in target!" -f red
                    }
                }
                Write-Host "Verification completed!" 
            }
        }

        'Inherit premissions from source (Migrate FIRST!)' {
            $MUsForInheritance = Select-RJMusForProcessing -Action 'Inherit'
            #Get all MUs from DB
            
            foreach ($MUURL in $MUsForInheritance) {
                $SourceRoot = $MUURL.SubItems[2].Text
                $DestinationURL = $MUURL.SubItems[3].Text
                #GetUniqueLists for target
                $sql = @"
                SELECT   ListTitle,  ListID, SourceUrl, DestinationUrl, MergeMUS, SUM(ItemCount) As ItemCount, InheritFromSource
            FROM [MigrationUnits] 
            Where DestinationURL = '$($DestinationURL)' and SourceRoot = '$($SourceRoot)' AND InheritFromSource = 1
            Group by  ListTitle,  ListID,  SourceUrl, DestinationUrl, MergeMUS, ItemCount, InheritFromSource
            Order By ListTitle
"@      
                $MUS = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql 
                $MUS | ForEach-Object { Inherit_RJPermissionsFromSource -scrSite $_.SourceURL -dstSite $_.DestinationURL  -scrListTitle $_.ListTitle -dstListID $_.ListID }
            }
            Write-Host "Inheritance permission process completed!" 
        }

        'Delete MU-s from target' {
            $MUsForDeletion = Select-RJMusForProcessing -Action 'Delete'
            If ($MUsForDeletion) { Start-RJDeletionCycle $MUsForDeletion }
            Write-Host "Deletion cycle completed" -ForegroundColor Cyan
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
        'Clear Navigation' {
            Start-RJNavigation
            Write-Host "Navigation cleared" -b Green
        }
        'Create Navigation' {
            Start-RJNavigation -Create
            Write-Host "Navigation re-created" -b Green
        }
    }
} while (($action -ne 'Quit') -and ($null -ne $action))

Stop-MtHLocalPowershell