[CmdletBinding()]
param()

#initialize
#Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -initsp -Verbose
#start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -Verbose -initsp
start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -Verbose  -InitSP
# open the demo site and fill the Demo Library

# Create testdata : check if the SP demo library (locally stored) is already filled, if not fill it
if ($settings.environment -ne 'production') {
    # New-MtHTestData -Number 50 -MaxFileSize 130000
    $files = (Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 -File)
    $script:randomfile = $files[(Get-Random -Maximum $files.count)]
}
Write-Verbose "NodeID = $($settings.NodeId)"
Write-Verbose "Used Database = $($settings.SQLDetails.Name),$($settings.SQLDetails.Database)"
#$ModulePath = -Join ($Settings.FilePath.LocalWorkSpaceModule, 'Public')
#Set-Location -Path $ModulePath
do {
    $action = ('++++++++++++++++++++++++++++++++++++++++++++++++++++++', 'Create DataBase', 'Remove DataBase', 'Deactivate Set of Sites and Lists in DB', 'Register Set of Sites and Lists for first migration', 'Register Set of Sites and Lists for delta migration', 'Test SP connections', 'Reset runs after truncation', 'Migrate Real', 
        'Delete MU-s from target', 'Create MenuItem', 'Quit') | Out-GridView -Title 'Choose Activity (Only working on dev and test env)' -PassThru
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
        'Deactivate Set of Sites and Lists in DB' {
            #not included
            $Items = Start-RJDBRegistrationCycle -NextAction "None"
            ForEach ($Item in $Items) {
                $sql = @"
                Update MigrationUnits SET NextAction ='none' where CompleteSourceURL = '$($Item.CompleteSourceURL)' 
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
        'Test SP connections' {
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
        'Migrate Real' {
            #Connect-MtHSharePoint
            Start-MtHExecutionCycle 
        }
        'Delete MU-s from target' {
            $MUsForDeletion = Select-RJMusForDeletion
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
        'Create menuItem' {
            $URL = "https://paccar.sharepoint.com/sites/DAF-MS-ASCOM-Site"
        }
    }
} while (($action -ne 'Quit') -and ($null -ne $action))

Stop-MtHLocalPowershell