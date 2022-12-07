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
    $action = ('++++++++++++++++++++++++++++++++++++++++++++++++++++++', 'Create DataBase', 'Remove DataBase', '************************************' , 'Update DB Rootsource', 'Deactivate Set of Sites and Lists in DB', '************************************' ,
        'Register Set of Sites and Lists for first migration', 'Register Set of Sites and Lists for delta migration', '************************************' , 'Reset runs after truncation', 'Gather lookuplist information' , 'Verify SP connections (prior to migrate)', 'Verify lists to migrate in source',
        'Migrate Real', 'Verify lists migrated in target (Verify in source FIRST)', 'Inherit premissions from source (Migrate FIRST!)', 
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
        'Gather lookuplist information' {
            $MUsForValidation = Select-RJMusForProcessing -Action 'LookupListInfo'
            $ResultList = [System.Collections.Generic.List[PSObject]]::new()
            foreach ($MUURL in $MUsForValidation) {
                $SourceRoot = $MUURL.SubItems[2].Text
                $DestinationURL = $MUURL.SubItems[3].Text
                $SQL = @"
                SELECT   *
                FROM [PACCARSQLO365].[dbo].[MigrationUnits]
                Where SourceRoot = '$($SourceRoot)'  And DestinationURL = '$($DestinationURL)'
                Order By DestinationURL
"@
                FOR ($SiteLoop = 1; $SiteLoop -le 2; $SiteLoop++) {
                    if ($SiteLoop -eq 1) {
                        #Scan Destination
                        $MUSforValidation = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql | Group-Object -Property DestinationURL 
                    }
                    else {
                        #Scan Source
                        $MUSforValidation = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql | Group-Object -Property SourceURL 
                    }
                    ForEach ($MUSource  in  $MUSforValidation) {
                        $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
                        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserNameSP2010, $securePwd
                        #Connect-MtHSharePoint -URL $MuSource.Name
                        if ($SiteLoop -eq 1) { 
                            $scrconn = Connect-MtHSharePoint -URL $MUSource.Name -returnconnection -ErrorAction Stop 
                        }
                        else { 
                            Connect-PnPOnline -URL $MUSource.Name -Credentials $cred -ErrorAction SilentlyContinue 
                        }
    
                        Write-Host "Connected to : $($MUSource.Name)" -BackgroundColor green
                        ForEach ($MUGroup  in  $MUSource.Group) {
                            $List = Get-PnPList -Identity $MUGroup.ListTitle
                            $ListFields = Get-PnPField -List $List | Where-Object { $_.Title -notin $Settings.LookuplijstIgnoreFields }
                            Write-Host "Analyzing list : $($List.Title) " -f Yellow
                            foreach ($Field in $ListFields) {
                                $FieldHidden = $Field | Select-Object -property 'Hidden'
                                if ($false -eq $FieldHidden.Hidden) {
                                    [xml]$schemaXml = $field.SchemaXml
                                    If ($null -ne $schemaXml.Field.Attributes["List"].Value) {
                                        Write-Host "Detected lookupfield  : $($Field.Title)" -f green
                                        #Write-Host "Field Schema XML  : $($Schema)" -f Magenta
                                        Write-Host "Field Schema Lookuplist ID  : $($schemaXml.Field.Attributes["List"].Value)" -f Magenta
                                        Write-Host "Field Schema Lookuplist Name   : $( $schemaXml.Field.Attributes["Name"].Value)" -f Magenta
                                        Write-Host "Field Schema LookupField  : $($schemaXml.Field.Attributes["ShowField"].Value)" -f Magenta
                                        $LookupField = New-Object PSObject
                                        $LookupField | Add-Member NoteProperty SourceURL($MUSource.Name)
                                        $LookupField | Add-Member NoteProperty ParentListID($List.ID)
                                        $LookupField | Add-Member NoteProperty ParentListTitle($MUGroup.ListTitle)
                                        $LookupField | Add-Member NoteProperty ParentListLookUpListFieldName($Field.Title)
                                        $LookupField | Add-Member NoteProperty ParentListLookUpListInternalFieldName($Field.InternalName)
                                        $LookupField | Add-Member NoteProperty LookUpListID($schemaXml.Field.Attributes["List"].Value)
                                        $LookupField | Add-Member NoteProperty LookUpListName($schemaXml.Field.Attributes["Name"].Value)
                                        $LookupField | Add-Member NoteProperty LookUpListFieldName($schemaXml.Field.Attributes["ShowField"].Value)
                                        $ResultList.Add($LookupField)
                                    }  
                                }
                            }
                        }
                    }
                }
            }
            $LookUpFieldsExportFileName = -Join ($Settings.FilePath.Logging, '/LookUpFieldsAnalysisExport' , (Get-Date -Format "ddmmyyyy"), '.csv')
            $ResultList | Export-CSV -Path $LookUpFieldsExportFileName -NoTypeInformation
            Write-Host "Lookup column gathering completed!" -f Cyan
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
                    #Connect-MtHSharePoint -URL $MuSource.Name
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
            $ListsWithIssues = [System.Collections.Generic.List[PSCustomObject]]::new()
            $MUsForValidation = Select-RJMusForProcessing -Action 'Verify'
            foreach ($MUURL in $MUsForValidation) {
                $SourceRoot = $MUURL.SubItems[2].Text
                $DestinationURL = $MUURL.SubItems[3].Text
                #GetUniqueLists for target
                $sql = @"
            SELECT SourceURL,  DestinationURL, ListTitle, ListTitleWithPrefix, ListURL, LISTID, MergeMUS, SUM(ItemCount) As ItemCount
            FROM [MigrationUnits] 
            Where DestinationURL = '$($DestinationURL)' and SourceRoot = '$($SourceRoot)'
            Group by SourceURL, DestinationURL, ListTitle, ListID, MergeMUs, ListTitleWithPrefix, ListURL
            Order By ListTitle
"@      
                $UniqueMUS = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql 
                $scrconn = Connect-MtHSharePoint -URL $DestinationURL -returnconnection -ErrorAction Stop
                Write-Host "Connected to $($DestinationURL) : Detected $($UniqueMUS.Count) Migration units in DB for connected destination" -b green
                foreach ($MuforValidation in $UniqueMUS) {
                    try {
                        $List = Get-PnPList -Connection $scrconn[1]   -Identity $MuforValidation.ListID -ErrorAction Stop
                        if ($Null -ne $List) {
                            if ($MuForValidation.ListTitle -ne $List.Title -and $MuForValidation.ListTitleWithPrefix -ne $List.Title) {
                                Write-Host "Double check this MU. The name in the DB is $($MuforValidation.ListTitle) but based on the ListID $($List.RootFolder.ServerRelativeUrl) the target site returns $($List.Title) " -BackgroundColor Red
                            }

                            $ItemCountMatch = $List.ItemCount -eq $MuforValidation.ItemCount
                            Write-Host "$($List.Title) ID $($List.ID) detected in $($List.RootFolder.ServerRelativeUrl)" -f green
                            if ($ItemCountMatch) {
                                Write-Host "Source itemcount : $($MuforValidation.ItemCount) - Target itemcount $($List.ItemCount) -> match : $($ItemCountMatch) MUsMerged : $($MuforValidation.MergeMUS)" -f green 
                            }
                            else {
                                #Double check
                                #Find differences
                             #   $Fields = Get-PnPField -List $List -Identity 'FileLeafRef' -ErrorAction SilentlyContinue
                             #   try {
                             #       $DestinationFiles = (Get-PnPListItem -List $List -Fields $Fields).FieldValues 
                             #   }
                             #   catch {
                             #       $a=1
                             #   }
                                $SourceFiles = Compare-RJSourceAndTarget -ScrSite $MUForValidation.SourceURL -scrListTitle $MuforValidation.ListTitle  
                                $DestinationFiles = Compare-RJSourceAndTarget -ScrSite $MUForValidation.DestinationURL -scrListTitle $MuforValidation.ListTitle  -UseWebLogin

                                #$Diff = Compare-Object -ReferenceObject $SourceFiles -DifferenceObject $DestinationFiles  -Property FileLeafRef -ErrorAction SilentlyContinue | Select-Object -Property FileLeafRef
                                $Diff = $SourceFiles.FileLeafRef | Where-Object {$_ -NotIN $DestinationFiles.FileLeafRef}
                                if ($null -ne $diff) {
                                    $ListsWithIssues.Add( -Join ('Source list ', $MuForValidation.ListTitle, " " , $MuForValidation.ListURL , ' | Target list ', $List.Title, " " , $List.RootFolder.ServerRelativeUrl , ' ', ' Itemcount mismatch  ->  SOurceItemCount : ' , $MUForValidation.ItemCount, '- TargetItemCount : ' , $List.ItemCount, ' Merged : ', $MUForValidation.MergeMUS))   
                                    Write-Host "Source itemcount : $($MuforValidation.ItemCount) - Target itemcount $($List.ItemCount) -> match : $($ItemCountMatch) MUsMerged : $($MuforValidation.MergeMUS)" -f yellow 
                                    Write-Host "$($Diff)" -f yellow 
                                }
                                else {
                                    Write-Host "Source itemcount : $($SourceFiles.Count) - Target itemcount $($DestinationFiles.Count) -> match : $($ItemCountMatch) MUsMerged : $($MuforValidation.MergeMUS)" -f green    
                                }
                            }
                        }            
                    }
                    catch {
                        $ListsWithIssues.Add( -join ($MuforValidation.ListTitle, ' / ' , $MuforValidation.ListTitleWithPrefix , ' -> NOT detected in target!'))
                        Write-Host "$($MuforValidation.ListTitle) / $($MuforValidation.ListTitleWithPrefix) NOT detected in target!" -f red

                    }
                }
                $ListsWithIssues | ForEach-Object { Write-Host "Checklist $($_)" -f Yellow }
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