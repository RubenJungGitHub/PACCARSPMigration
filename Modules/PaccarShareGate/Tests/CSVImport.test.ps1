using module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = (!$settings.SQLdetails) -or !$settings.SQLdetails.DeleteDB

    # skip if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment, because there is no SQL test database defined.'
    }
}

BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test -initsp
    # load all PaccarShareGate commands in the local scope, so they can be mocked
    Get-Module PaccarShareGate | Remove-Module -Force
    $dir = Get-MtHGitDirectory
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    } 
    $script:TestSourceUrl = 'https://' + $Settings.Current.SourceTenantDomain + '/sites/input1'
    $script:TestListUrl = 'https://' + $Settings.Current.SourceTenantDomain + '/sites/input1' + '/' + 'shared%20docs'
    $script:TestDestUrl = ConvertTo-MtHDestinationUrl -SourceUrl $TestSourceUrl
    Remove-MtHSQLDatabase

}  
AfterAll {
    Stop-MtHLocalPowershell -test
}

# Pester runs twice: Discovery and Real testing.
#Transaction tests are only run against the test database when there is a test database in the environment 
Describe 'Mocked CSVImport and state transitions : Testing of the databaseMU transitions based on CSVImport values' -Skip:$skip {
    Context '1: Filling database with Register-MtHAllSitesLists' {
        BeforeEach { 
            Mock -CommandName Get-MtHOneSPSiteLists -MockWith {
                Return [System.Collections.Generic.List[MigrationUnitClass]]@(
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        Scope           = 'site'
                    },
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        ListUrl         = $TestListUrl
                        ListTitle       = 'shared docs'
                        ListId          = '1234'
                        Scope           = 'list'
                    }
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        ListUrl         = $TestListUrl
                        ListTitle       = 'shared docs2'
                        ListId          = '12345'
                        Scope           = 'list'
                    }
                )
            }
            $script:expectedresult = [System.Collections.Generic.List[MigrationUnitClass]] @(
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    Sharegatecopysettings = ''
                    Scope                 = 'site'
                    MUStatus              = 'new'
                    NextAction            = 'none'
                    MigUnitId             = 1
                    NodeId                = 1
                },
                
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs'
                    ListTitle             = 'shared docs'
                    ListId                = '1234'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'new'
                    NextAction            = 'none'
                    MigUnitId             = 2
                    NodeId                = 1
                }
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'new'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
        }

        It '1.1: Empties the database, database should have 0 entries' {
            New-MtHSQLDatabase
            $result = Get-MtHSQLMigUnits
            $result | Should -BeNullOrEmpty
        }
        It '1.2: Registers 1 site, Database Should have 3 rows of input1 URL' {
            # and run 1 registration cycle to look if the database gets the expected status
            Register-MtHAllSitesLists
            $script:result = Get-MtHSQLMigUnits -Url $TestSourceUrl
            $result.count | Should -Be 3
        }
        It '1.3: Database Should have 3 rows Overall' {
            $script:result = Get-MtHSQLMigUnits -all
            $result.count | Should -Be 3
        }
    }

    <#
    Context '2: Import  mocked CSVitems and verify denied and allowed state transitions' {
        It '2.1: State transitions should be OK' {
        $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
            [PSCustomObject]@{
                MigUnitId       = 1
                CurrentMUStatus = 'New'
                NewMUStatus     = 'Active'
                NodeId          = 1
            },
            [PSCustomObject]@{
                MigUnitId       = 2
                CurrentMUStatus = 'Active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            },
            [PSCustomObject]@{
                MigUnitId       = 3
                CurrentMUStatus = 'Active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            }
        )
        $script:expectedresult = [System.Collections.Generic.List[MigrationUnitClass]] @(
            [MigrationUnitClass]@{
                EnvironmentName       = 'o365'
                SourceUrl             = $TestSourceUrl
                DestinationUrl        = $TestDestUrl
                ListUrl               = ''
                Sharegatecopysettings = ''
                Scope                 = 'site'
                MUStatus              = 'new'
                NextAction            = 'none'
                MigUnitId             = 1
                NodeId                = 1
            },
            [MigrationUnitClass]@{
                EnvironmentName       = 'o365'
                SourceUrl             = $TestSourceUrl
                DestinationUrl        = $TestDestUrl
                ListUrl               = '/sites/input1/shared%20docs'
                ListTitle             = 'shared docs'
                ListId                = '1234'
                Sharegatecopysettings = ''
                Scope                 = 'list'
                MUStatus              = 'new'
                NextAction            = 'none'
                MigUnitId             = 2
                NodeId                = 1
            }
        )


            Submit-MtHScopedSitesLists -ChangeItems $CSVItems
            $script:result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'CurrentMUStatus'
            $Differences | Should -BeNullOrEmpty
        }
    }#>
}