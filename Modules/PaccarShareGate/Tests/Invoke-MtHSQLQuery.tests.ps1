using module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB

    # skip if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.'
    }
}

Describe 'UnitTests for DataBase Interaction (Invoke-MtHSQLQuery.tests.ps1)' -Tag 'Unit' -Skip:$skip {
    BeforeAll {
        Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
        $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB
        $dir = Get-MtHGitDirectory
        (Get-Command -Module PaccarShareGate).name | ForEach-Object {
            . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
        } 
        if (!$Skip) {
            # Despite flag not to delete DB records were added to the database. This would also happen in prod. Therefore $Skip check added.
            # Striclty speaking the problem only occured during "invoke-MTHSQLQuery" but filterred any DB Action depending on $skip flag
            Remove-MtHSQLDatabase
            New-MtHSQLDatabase
            Invoke-MtHSQLquery -QueryName 'T-FillDBforTest'
        }
        $script:MUCprops = ([MigrationUnitClass]::new().PSObject.properties.name)
    }
    AfterAll {  
        Stop-MtHLocalPowershell -test
    }
    Context '1: UnitTests for Get-MtHSQLMigUnits' {
        It '1.1: UnitTest for Get-MtHSQLMigUnits -all' {
            $result = Get-MtHSQLMigUnits -all
            $result.count | Should -Be 5
        }
        It '1.2: UnitTest for Get-MtHSQLMigUnits -Url' {
            $result = Get-MtHSQLMigUnits -Url 'https://mock.sharepoint.com/sites/input1'
            $result.count | Should -Be 4
        }
        It '1.3: UnitTest for Get-MtHSQLMigUnits -Url' {
            $result = Get-MtHSQLMigUnits -Url 'https://mock.sharepoint.com/sites/input2'
            $result.count | Should -Be 1
        }
        It '1.4: UnitTest for Get-MtHSQLMigUnits -MigUnitId' {
            $result = Get-MtHSQLMigUnits -MigUnitId 4
            $result.count | Should -Be 1
        }
        It '1.5: UnitTest for Get-MtHSQLMigUnits Exact return' {
            $result = Get-MtHSQLMigUnits -MigUnitId 4
            $ExpectedResult = [MigrationUnitClass]@{
                EnvironmentName       = 'o365'
                SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
                DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
                ListUrl               = '/sites/input1/shared docs3'
                Sharegatecopysettings = ''
                Scope                 = 'list'
                MUStatus              = 'active'
                NextAction            = 'none'
                MigUnitId             = 4
                LastStartTime         = [datetime]::MinValue
                NodeId                = $settings.NodeId
            }
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $ExpectedResult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
    }
    Context '2: UnitTests for Invoke-MtHSQLQuery.ps1' {
        It '2.1: One Item returned for Detect ALL query' {
            $result = Invoke-MtHSQLquery -QueryName 'D-ALL'
            $result.count | Should -Be 2
        }
        It '2.2: This Item Should be the following object' {
            $result = Invoke-MtHSQLquery -QueryName 'D-ALL'
            $ExpectedResult = @([MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
                    DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
                    ListUrl               = '/sites/input1/shared docs3'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'active'
                    NextAction            = 'none'
                    MigUnitId             = 4
                    LastStartTime         = [datetime]::MinValue
                    NodeId                = $settings.NodeId
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = 'https://mock.sharepoint.com/sites/input2'
                    DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input2'
                    ListUrl               = '/sites/input2/shared docs3'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'fake'
                    NextAction            = 'none'
                    MigUnitId             = 5
                    LastStartTime         = [datetime]::MinValue
                    NodeId                = $settings.NodeId
                })
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $ExpectedResult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
        It '2.3: One Item returned for Execute ALL query' {
            $result = Invoke-MtHSQLquery -QueryName 'E-ALL'
            $result.count | Should -Be 1
        }
        It '2.4: This Item Should be' {
            #Running this individual test works fine after Invoke-pester. However, running invoke-pester from the root an exception is thrown
            $result = Invoke-MtHSQLquery -QueryName 'E-ALL'
            $ExpectedResult = [MigrationUnitClass]@{
                EnvironmentName       = 'o365'
                SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
                DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
                ListUrl               = '/sites/input1/shared docs2'
                Sharegatecopysettings = ''
                Scope                 = 'list'
                MUStatus              = 'active'
                NextAction            = 'first'
                MigUnitId             = 3
                LastStartTime         = [datetime]::MinValue
                NodeId                = $settings.NodeId
            }
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $ExpectedResult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
    } 
    Context '3: changes' {
        It '3.1: change UnitId 1 from new to fake' {
            $change = [PSCustomObject]@{
                MigUnitId       = 1
                CurrentMUStatus = 'new'
                NewMUStatus     = 'fake'
            }
            $update = [PSCustomObject]@{
                MigUnitId  = 1
                MUStatus   = 'fake'
                NextAction = 'first'
                NodeId     = 1
            }
            $start = Get-MtHSQLMigUnits -all
            Submit-MtHScopedSitesLists -ChangeItems $change
            $end = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $start -DifferenceObject $end -Property $MUCprops
            Compare-MtHdiff -Differences $Differences -Idprop 'MigUnitId' -expectedUpdate $update | Should -Be $false
        }
    }

}