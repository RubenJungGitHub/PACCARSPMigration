using module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = (!$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB)
    # skip if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.'
    }
}

# Pester runs twice: Discovery and Real testing.
#Transaction tests are only run against the test database when there is a test database in the environment 
Describe 'Mocked CSVImport and state transitions : Testing of the databaseMU transitions based on CSVImport values' -Skip:$skip {
    BeforeAll {
        Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
        # load all PaccarShareGate commands in the local scope, so they can be mocked
        Get-Module PaccarShareGate | Remove-Module -Force
        $dir = Get-MtHGitDirectory
        (Get-Command -Module PaccarShareGate).name | ForEach-Object {
            . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
        } 
        $script:CSVImportLogfile = $settings.ActivateMUCsv
        $TestMigrationURL = $Settings.Current.MigrationURLS | Select-Object -first 1
        $script:TestSourceUrl = ConvertTo-MtHHttpAbsPath -SourceURL $TestMigrationURL.SourceTenantDomain -Path $TestMigrationURL.DemoSite[0]   #'https://' + $TestMigrationURL.SourceTenantDomain + '/sites/input1'
        $script:TestListUrl = ConvertTo-MtHHttpAbsPath -SourceURL $TestMigrationURL.SourceTenantDomain -path('/sites/input1/shared%20docs')
        $script:TestDestUrl = ConvertTo-MtHDestinationUrl -SourceUrl $TestSourceUrl
        #Reset when inidividual tests run succesfully
        if (!$Skip) {
            Initialize-MtHSharePoint
            Remove-MtHSQLDatabase
        }
        #Delete potential existing  activation logfile 
        $script:ActivateLog = $settings.ActivateMUCsv
        if (Test-Path $script:ActivateLog) 
            {Remove-Item -Path  $ActivateLog    }
    }  
    AfterAll {
        Stop-MtHLocalPowershell -test
    }
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
                        MUStatus        = 'notfound'
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
            Register-MtHAllSitesLists -filter $settings.current.MigrationURLS[0].DemoSite[0]
            $script:result = Get-MtHSQLMigUnits -Url $TestSourceUrl
            $result.count | Should -Be 3
        }
        It '1.3: Database Should have 3 rows Overall' {
            $script:result = Get-MtHSQLMigUnits -all
            $result.count | Should -Be 3
        }
    }

    Context '2: Import mocked CSVitems and verify denied and allowed state transitions' {
        It '2.0: State transitions should all be false for all items "Wrong current status from input csv file' {
            #Clear to make
            $CSVItems | ForEach-Object { $_.Remove }
            $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId       = 1
                    CurrentMUStatus = 'active'
                    NewMUStatus     = 'fake'
                    NodeId          = 1
                },
                [PSCustomObject]@{
                    MigUnitId       = 2
                    CurrentMUStatus = 'active'
                    NewMUStatus     = 'fake'
                    NodeId          = 1
                },
                [PSCustomObject]@{
                    MigUnitId       = 3
                    CurrentMUStatus = 'active'
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
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            Submit-MtHScopedSitesLists -ChangeItems $CSVItems
            $script:result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MUStatus'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            $Differences | Should -BeNullOrEmpty
        }
        It '2.1: Check CSV Import logfile based on 2.1 "Wrong current status from input csv file' {
            $script:expectedresult | ForEach-Object { $_.Remove }
            $script:expectedresult = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId   = 1
                    Information = 'Warning: Active state deviation. Item 1 has not the status active but status new. Item 1 will be skipped.'
                },
                [PSCustomObject]@{
                    MigUnitId   = 2
                    Information = 'Warning: Active state deviation. Item 2 has not the status active but status new. Item 2 will be skipped.'
                },
                [PSCustomObject]@{
                    MigUnitId   = 3
                    Information = 'Warning: Item 3 has the status notfound, so is not available in the source'
                }
            )
            $result = Import-Csv -Path  $script:CSVImportLogfile  -Delimiter ';'
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'Information'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'Information'
            $Differences | Should -BeNullOrEmpty
        }

        It '2.2: Change status of MU2 to fake, check state and  logfile entries' {
            $CSVItems | ForEach-Object { $_.Remove }
            $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId       = 2
                    CurrentMUStatus = 'new'
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
                    MUStatus              = 'fake'
                    NextAction            = 'first'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            Submit-MtHScopedSitesLists -ChangeItems $CSVItems 
            #Determine MigUNitIDState
            $result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'MUStatus'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            #recover logfile content 
            $result = Import-Csv -Path  $script:CSVImportLogfile  -Delimiter ';'
            $Differences | Should -BeNullOrEmpty 
            $result  | Should -BeNullOrEmpty 
        }

        It '2.3: Change status of MU1 to fake, check state and logfile entries' {
            $CSVItems | ForEach-Object { $_.Remove }
            $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId       = 1
                    CurrentMUStatus = 'new'
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
                    MUStatus              = 'fake'
                    NextAction            = 'first'
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
                    MUStatus              = 'fake'
                    NextAction            = 'first'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            Submit-MtHScopedSitesLists -ChangeItems $CSVItems 
            #Determine MigUNitIDState
            $result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'MUStatus'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            #recover logfile content 
            $result = Import-Csv -Path  $script:CSVImportLogfile  -Delimiter ';'
            $Differences | Should -BeNullOrEmpty 
            $result  | Should -BeNullOrEmpty 
        }

        It '2.4: Try reset status  to new for MU1 and 2, this should be denied and throw exception' {
            $CSVItems | ForEach-Object { $_.Remove }
            $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId       = 1
                    CurrentMUStatus = 'fake'
                    NewMUStatus     = 'new'
                    NodeId          = 1
                },
                [PSCustomObject]@{
                    MigUnitId       = 2
                    CurrentMUStatus = 'fake'
                    NewMUStatus     = 'new'
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
                    MUStatus              = 'fake'
                    NextAction            = 'first'
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
                    MUStatus              = 'fake'
                    NextAction            = 'first'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            { Submit-MtHScopedSitesLists -ChangeItems $CSVItems } | Should -Throw  
        }


        It '2.5: Verify the Mu state did not change in step 2.4 ' {
            $script:expectedresult = [System.Collections.Generic.List[MigrationUnitClass]] @(
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = ''
                    Sharegatecopysettings = ''
                    Scope                 = 'site'
                    MUStatus              = 'fake'
                    NextAction            = 'first'
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
                    MUStatus              = 'fake'
                    NextAction            = 'first'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            $result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'MUStatus', 'NextAction'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            #recover logfile content 
            $Differences | Should -BeNullOrEmpty 
        }

        It '2.6: Activate  MU1 and 2, this should be ok' {
            $CSVItems | ForEach-Object { $_.Remove }
            $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId       = 1
                    CurrentMUStatus = 'fake'
                    NewMUStatus     = 'active'
                    NodeId          = 1
                },
                [PSCustomObject]@{
                    MigUnitId       = 2
                    CurrentMUStatus = 'fake'
                    NewMUStatus     = 'active'
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
                    MUStatus              = 'active'
                    NextAction            = 'first'
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
                    MUStatus              = 'active'
                    NextAction            = 'first'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            Submit-MtHScopedSitesLists -ChangeItems $CSVItems
            #Determine MigUNitIDState
            $result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'MUStatus'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            #recover logfile content 
            $result = Import-Csv -Path  $script:CSVImportLogfile  -Delimiter ';'
            $Differences | Should -BeNullOrEmpty 
            $result  | Should -BeNullOrEmpty 
        }

        It '2.6: Reverse status of MU1 and MU2 from active to fake, this should be denied . check state and logfile entries' {
            $CSVItems | ForEach-Object { $_.Remove }
            $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId       = 1
                    CurrentMUStatus = 'active'
                    NewMUStatus     = 'fake'
                    NodeId          = 1
                },
                [PSCustomObject]@{
                    MigUnitId       = 2
                    CurrentMUStatus = 'active'
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
                    MUStatus              = 'active'
                    NextAction            = 'first'
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
                    MUStatus              = 'active'
                    NextAction            = 'first'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            $script:expectedlogresult | ForEach-Object { $_.Remove }
            $script:expectedlogresult = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId   = 1
                    Information = 'Warning: Reversed status action : Item 1 current status is active and should become fake :Reversal of status transitions is prohibited . Item 1 will be skipped.'
                },
                [PSCustomObject]@{
                    MigUnitId   = 2
                    Information = 'Warning: Reversed status action : Item 2 current status is active and should become fake :Reversal of status transitions is prohibited . Item 2 will be skipped.'
                }
            )
            Submit-MtHScopedSitesLists -ChangeItems $CSVItems
            #Determine MigUNitIDState
            $result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'MUStatus'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            #recover logfile content 
            $result = Import-Csv -Path  $script:CSVImportLogfile  -Delimiter ';'
            $script:LogDifferences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedLogresult -Property 'MigUnitID', 'MUStatus'
            $Differences | Should -BeNullOrEmpty 
            $LogDifferences  | Should -BeNullOrEmpty 
        }

        It '2.7: Reset status to initial value and change MU Status from new to active driectly : This should be ok' {
            #Reset status 
            $ResetMUItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId  = 1
                    MUStatus   = 'new'
                    Nextaction = 'none'
                    NodeId     = 1
                    ItemCount  = 0
                },
                [PSCustomObject]@{
                    MigUnitId  = 2
                    MUStatus   = 'new'
                    Nextaction = 'none'
                    NodeId     = 1
                    ItemCount  = 0
                }
            )
            Update-MtHSQLMigUnitStatus -Item $ResetMUItems[0]
            Update-MtHSQLMigUnitStatus -Item $ResetMUItems[1]

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
                    ItemCount             = 0
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
                    ItemCount             = 0
                    MUStatus              = 'new'
                    NextAction            = 'none'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    ItemCount             = 0
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            #Determine MigUNitIDState
            $result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'MUStatus'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            #recover logfile content 
            $Differences | Should -BeNullOrEmpty 
        }
        
        It '2.8: Change MU Status from new to active directly : This should be ok' {
            $CSVItems | ForEach-Object { $_.Remove }
            $CSVItems = [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    MigUnitId       = 1
                    CurrentMUStatus = 'new'
                    NewMUStatus     = 'active'
                    NodeId          = 1
                },
                [PSCustomObject]@{
                    MigUnitId       = 2
                    CurrentMUStatus = 'new'
                    NewMUStatus     = 'active'
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
                    MUStatus              = 'active'
                    NextAction            = 'first'
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
                    MUStatus              = 'active'
                    NextAction            = 'first'
                    MigUnitId             = 2
                    NodeId                = 1
                },
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = '/sites/input1/shared%20docs2'
                    ListTitle             = 'shared docs2'
                    ListId                = '12345'
                    Sharegatecopysettings = ''
                    Scope                 = 'list'
                    MUStatus              = 'notfound'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )

            Submit-MtHScopedSitesLists -ChangeItems $CSVItems
            #Determine MigUNitIDState
            $result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property 'MigUnitID', 'MUStatus'
            Show-MtHdiff -Differences $Differences -IdProp 'MIgUnitID'
            Show-MtHdiff -Differences $Differences -IdProp 'MUStatus'
            #recover logfile content 
            $result = Import-Csv -Path  $script:CSVImportLogfile  -Delimiter ';'
            $Differences | Should -BeNullOrEmpty 
            $result  | Should -BeNullOrEmpty 
        }
    }
}