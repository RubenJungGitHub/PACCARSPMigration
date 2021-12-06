[CmdletBinding()]
param()

#initialize
#Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -initsp -Verbose
Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -Verbose -initsp
# open the demo site and fill the Demo Library
$TestMigrationURL = $Settings.Current.MigrationURLS | Select-Object -First 1
$script:AbsDemoSiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $TestMigrationURL.SourceTenantDomain -path $TestMigrationURL.DemoSite[0]
$script:AbsDemoListUrl = $AbsDemoSiteUrl + '/' + $TestMigrationURL.DemoList

# Create testdata : check if the SP demo library (locally stored) is already filled, if not fill it
if ($settings.environment -ne 'production') {
    # New-MtHTestData -Number 50 -MaxFileSize 130000
    $files = (Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 -File)
    $script:randomfile = $files[(Get-Random -Maximum $files.count)]
}
Write-Verbose "NodeID = $($settings.NodeId)"
Write-Verbose "Used Database = $($settings.SQLDetails.Name),$($settings.SQLDetails.Database)"
$ModulePath = -Join ($Settings.FilePath.LocalWorkSpaceModule, 'Public')
#Set-Location -Path $ModulePath
do {
    $action = ('++++++++++++++++++++++++++++++++++++++++++++++++++++++', 'Create DataBase', 'Remove DataBase', 'Register Set of Sites and Lists for first migration', 'Register Set of Sites and Lists for delta migration','Migrate Real', 
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
            Register-MtHAllSitesLists 
        }
        'Register Set of Sites and Lists for first migration' {
            #not included
            #$setofsites = @('https://247.plaza.buzaservices.nl/subject/AB1156858')
            #Register-MtHAllSitesLists -setofsites $setofsites
            $Items = Start-RJDBRegistrationCycle -NextAction "First"
            If ($Null -ne $Items) { Register-MtHAllSitesLists -MUsINSP $Items -NextAction "First" }
        }
        'Register Set of Sites and Lists for delta migration' {
            #not included
            #$setofsites = @('https://247.plaza.buzaservices.nl/subject/AB1156858')
            #Register-MtHAllSitesLists -setofsites $setofsites
            $Items = Start-RJDBRegistrationCycle  -NextAction "Delta"
            If ($Null -ne $Items) { Register-MtHAllSitesLists -MUsINSP $Items -NextAction "Delta" }
        }
        'Migrate Fake' {
            Start-MtHExecutionCycle -Fake    
        }
        'Migrate Real' {
            #Connect-MtHSharePoint
            Start-MtHExecutionCycle 
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
    }
} while (($action -ne 'Quit') -and ($null -ne $action))

Stop-MtHLocalPowershell