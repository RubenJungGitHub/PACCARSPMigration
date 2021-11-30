using module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = (!$settings.SQLdetails) -or !$settings.SQLdetails.DeleteDB

    # skip if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.'
        #   Write-host 'Transactions.tests -> No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.' -BackgroundColor red
    }
}

BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    # load all buzasharegate commands in the local scope, so they can be mocked
    Get-Module BuzaShareGate | Remove-Module -Force
    $dir = Get-MtHGitDirectory
    (Get-Command -Module BuZaShareGate).name | ForEach-Object {
        . "$dir\Modules\BuzaShareGate\Public\$_.ps1" 
    } 
    $script:MUCprops = ([MigrationUnitClass]::new().PSObject.properties.name) -ne 'LastStartTime'
    $settings.current.MigrationURLS[0].ManagedPath[0] = 'sites' # this works only when managed path is sites.
    if (!$Skip) {
       Remove-MtHSQLDatabase
    }
    $script:TestSourceUrl = 'https://' + $Settings.Current.MigrationURLS[0].SourceTenantDomain + '/sites/input1'
    $script:TestListUrl = 'https://' + $Settings.Current.MigrationURLS[0].SourceTenantDomain + '/sites/input1' + '/' + 'shared%20docs'
    $script:TestDestUrl = ConvertTo-MtHDestinationUrl -SourceUrl $TestSourceUrl
    $script:MUCprops = [MigrationUnitClass]::new().PSObject.properties.name
    Mock -CommandName Connect-MtHSharePoint  -MockWith {return $true}
    Mock -CommandName Test-MtHAdminRightsAllSites  -MockWith {
        return @( $TestSourceUrl )
    }
}  
AfterAll {
    Stop-MtHLocalPowershell -test
}

# Pester runs twice: Discovery and Real testing.
#Transaction tests are only run against the test database when there is a test database in the environment 
Describe 'Transactions.tests.ps1: Testing of the database interaction with Mocked SharePoint. Only run the complete scenario' -Skip:$skip {
    Context '1: Filling database with Register-MtHAllSitesLists' {
        BeforeEach { 
            Mock -CommandName Get-MtHOneSPSiteLists -MockWith {
                Return [System.Collections.Generic.List[MigrationUnitClass]]@(
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        Scope           = 'site'
                        ItemCount       = 0
                    },
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        ListUrl         = $TestListUrl
                        ListTitle       = 'shared docs'
                        ListId          = '1234'
                        Scope           = 'list'
                        ItemCount       = 1
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
                    MUStatus              = 'new'
                    NextAction            = 'none'
                    ItemCount             = 1
                    MigUnitId             = 2
                    NodeId                = 1
                }
            )
        }

        It '1.1: Empties the database, database should have 0 entries' {
            New-MtHSQLDatabase
            $result = Get-MtHSQLMigUnits
            $result | Should -BeNullOrEmpty
        }
        It '1.2: Registers 1 site, Database Should have 2 rows of input1 URL' {
            # and run 1 registration cycle to look if the database gets the expected status
            Register-MtHAllSitesLists
            $script:result = Get-MtHSQLMigUnits -Url $TestSourceUrl
            $result.count | Should -Be 2
        }
        It '1.3: Database Should have 2 rows Overall' {
            $script:result = Get-MtHSQLMigUnits -all
            $result.count | Should -Be 2
        }
        It '1.4: Database output static input properties as expected, after 1 registration' {
            $script:result = Get-MtHSQLMigUnits -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property EnvironmentName, SourceUrl, ListUrl, Scope, ItemCount
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
        It '1.5: Database output completely as expected, after 1 registration' {
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
        It '1.6: Database should have still 2 records when registering the same Migration Units' {
            Register-MtHAllSitesLists
            $script:result = Get-MtHSQLMigUnits -Url  ( $TestSourceUrl)
            $result.count | Should -Be 2
        }
        It '1.7: Database output as expected, also after 2 registrations' {
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
    }
    Context '2: Check the Database fillup process, when a 3rd entry is added' {
        BeforeEach {
            Mock -CommandName Get-MtHOneSPSiteLists -MockWith {
                Return [System.Collections.Generic.List[MigrationUnitClass]]@(
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        Scope           = 'site'
                        ItemCount       = 0
                        MigUnitId       = 1
                        NodeId          = 1
                    },
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        ListUrl         = '/sites/input1/shared%20docs'
                        ListTitle       = 'shared docs'
                        ListId          = '1234'
                        Scope           = 'list'
                        ItemCount       = 2
                        MigUnitId       = 2
                        NodeId          = 1
                    }
                    [MigrationUnitClass]@{
                        EnvironmentName = 'o365'
                        SourceUrl       = $TestSourceUrl
                        ListUrl         = '/sites/input1/shared%20docs2'
                        ListTitle       = 'shared docs2'
                        ListId          = '12345'
                        Scope           = 'list'
                        ItemCount       = 1
                        MigUnitId       = 3
                        NodeId          = 1
                    }
                )
            }           
        }
        It '2.1: Database Should have 3 rows Overall' {
            # and run 1 registration cycle to look if the database gets the expected status
            Register-MtHAllSitesLists
            $script:result = Get-MtHSQLMigUnits -all
            $result.count | Should -Be 3
        }
        It '2.2: Database Should have 3 rows of input1 URL' {
            $script:result = Get-MtHSQLMigUnits -Url  ( $TestSourceUrl)
            $result.count | Should -Be 3
        }

        It '2.3: Database content as expected' {
            $script:expectedresult = [System.Collections.Generic.List[MigrationUnitClass]] @(
                [MigrationUnitClass]@{
                    EnvironmentName       = 'o365'
                    SourceUrl             = $TestSourceUrl
                    DestinationUrl        = $TestDestUrl
                    ListUrl               = ''
                    Sharegatecopysettings = ''
                    Scope                 = 'site'
                    MUStatus              = 'new'
                    ItemCount             = 0
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
                    ItemCount             = 2  
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
                    ItemCount             = 1  
                    NextAction            = 'none'
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
    }
    Context '3: Check the Database fillup process, when an entry is deleted' {
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
                        ListUrl         = '/sites/input1/shared%20docs2'
                        ListTitle       = 'shared docs2'
                        ListId          = '12345'
                        Scope           = 'list'
                        ItemCount       = 1 
                    }
                )
            }
            Register-MtHAllSitesLists
        }
        It '3.1: Database Should have 3 rows Overall' {
            $script:result = Get-MtHSQLMigUnits -all
            $result.count | Should -Be 3
        }
        It '3.2: Database Should have 3 rows of input1 URL' {
            $script:result = Get-MtHSQLMigUnits -Url ( $TestSourceUrl)
            $result.count | Should -Be 3
        }
        It '3.3: Database output as expected' {
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
                    MUStatus              = 'notfound'
                    NextAction            = if ($Settings.Current.DeleteNotFoundMUS) {
                        'delete'
                    }
                    else {
                        'none'
                    }
                    ItemCount             = 2  
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
                    ItemCount             = 1 
                    MigUnitId             = 3
                    NodeId                = 1
                }
            )
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
    }
    Context '4: Activate all lists for Migration' {
        It '4.1: New Lists should be activated for first run' {
            $changeitems = [System.Collections.Generic.List[PSObject]]::new()
            Get-MtHSQLMigUnits -all | Where-Object { $_.Scope -eq 'list' -and $_.MUStatus -eq 'new' } | Sort-Object -Property MigUnitId | ForEach-Object {
                $changeitem = [PSCUSTOMOBJECT]@{
                    MigUnitId       = $_.MigUnitId
                    NodeId          = $settings.NodeId
                    CurrentMUStatus = 'new'
                    NewMUStatus     = 'active'
                }
                $changeitems.add($changeitem)
            }
            Submit-MtHScopedSitesLists -ChangeItems $changeitems
            $script:result = Get-MtHSQLMigUnits -all
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
                    ItemCount             = 0
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
                    MUStatus              = 'notfound'
                    NextAction            = if ($Settings.Current.DeleteNotFoundMUS) {
                        'delete'
                    }
                    else {
                        'none'
                    }
                    ItemCount             = 2
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
                    MUStatus              = 'active'
                    NextAction            = 'first'
                    NodeId                = $settings.NodeId
                    ItemCount             = 1
                    MigUnitId             = 3
                }
            )
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
    }
    Context '5: Run First Execution Cycle (3 times)' {
        BeforeEach {
            Mock -CommandName Start-MtHSGMigration -MockWith {
                Start-Sleep -Milliseconds 10
                return [PSCustomObject]@{
                    Errors    = 0
                    SessionId = 'None'
                }
            }
            Start-MtHExecutionCycle 
         }
        It '5.1: Should have 1 record in MigRunTable' {
            $script:result = Get-MtHSQLMigRuns -all
            $result.count | Should -Be 1
        }
        It '5.2: Should have a succesful run in the MigRunTable' {
            $script:expectedresult = [MigrationRunClass]@{
                MigUnitId = 3
                Result    = 'success'
                MigRunId  = 1
            }
            $script:result = Get-MtHSQLMigRuns -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
        It '5.3: Should have put next action in MigRunTable to none' {   
            $script:result = Get-MtHSQLMigUnits -all
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
                    MUStatus              = 'notfound'
                    #NextAction            = 'none'
                    NextAction            = if ($Settings.Current.DeleteNotFoundMUS) {
                        'delete'
                    }
                    else {
                        'none'
                    }
                    ItemCount             = 2
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
                    MUStatus              = 'active'
                    NextAction            = 'none'
                    ItemCount             = 1
                    MigUnitId             = 3
                    NodeId                = $settings.NodeId
                }
            )
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty        
        }
    }
    
    Context '6: Run first and second detection cycle, with no changes detected and with change detected' {
        It  '6.1: MigRuns table will not change when returning time in the past' {
            Mock -CommandName Test-MtHSPMigUnitModified -MockWith {
                return [DateTime]::ParseExact('2021-01-02 12:00:00', 'yyyy-MM-dd hh:mm:ss', $null) # in the past
            }
            Start-MtHDetectionCycle
            $script:result = Get-MtHSQLMigRuns -all
            $result.count | Should -Be 1
        }
        It '6.2: Should have put next action in MigRunTable still to none' {   
            $script:result = Get-MtHSQLMigUnits -all
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
                    MUStatus              = 'notfound'
                    #                    NextAction            = 'none'
                    NextAction            = if ($Settings.Current.DeleteNotFoundMUS) {
                        'delete'
                    }
                    else {
                        'none'
                    }
                    ItemCount             = 2
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
                    MUStatus              = 'active'
                    NextAction            = 'none'
                    MigUnitId             = 3
                    ItemCount             = 1
                    NodeId                = $settings.NodeId
                }
            )
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty        
        }
        It '6.3: MigRuns table will not change when returning current time' {
            Mock -CommandName Test-MtHSPMigUnitModified -MockWith {
                return [DateTime]$(Get-Date) # now
            }
            Start-Sleep -Seconds 1 # wait 1 second to be sure the time is bigger then the previous time
            Start-MtHDetectionCycle
            $script:result = Get-MtHSQLMigRuns -all
            $result.count | Should -Be 1
        }
        It '6.4: Should have put next action in MigUnitTable to delta' {   
            $script:result = Get-MtHSQLMigUnits -all
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
                    MUStatus              = 'notfound'
                    #NextAction            = 'none'
                    NextAction            = if ($Settings.Current.DeleteNotFoundMUS) {
                        'delete'
                    }
                    else {
                        'none'
                    }
                    ItemCount             = 2
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
                    MUStatus              = 'active'
                    NextAction            = 'delta'
                    ItemCount             = 1
                    MigUnitId             = 3
                    NodeId                = $settings.NodeId
                }
            )
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty        
        }
    }
    Context '7: Run Second Execution Cycle (again 3 times)' {
        BeforeEach {
            Mock -CommandName Start-MtHSGMigration -MockWith {
                Start-Sleep -Milliseconds 10
                return @{
                    Errors    = 0
                    SessionId = 'None'
                }
            }
            Start-MtHExecutionCycle    
        }
        It '7.1: Should have 2 records in MigRunTable' {
            $script:result = Get-MtHSQLMigRuns -all
            $result.count | Should -Be 2
        }
        It '7.2: Should have a succesful run in the MigRunTable' {                
            $script:expectedresult = [System.Collections.Generic.List[MigrationRunClass]] @(
                [MigrationRunClass]@{
                    MigUnitId = 3
                    Result    = 'success'
                    MigRunId  = 1
                },
                [MigrationRunClass]@{
                    MigUnitId = 3
                    Result    = 'success'
                    MigRunId  = 2
                }
            )
            $script:result = Get-MtHSQLMigRuns -all
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty
        }
        It '7.3: Should have put next action in MigRunTable again to none' {   
            $script:result = Get-MtHSQLMigUnits -all
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
                    MUStatus              = 'notfound'
                    #NextAction            = 'none'
                    NextAction            = if ($Settings.Current.DeleteNotFoundMUS) {
                        'delete'
                    }
                    else {
                        'none'
                    }
                    ItemCount             = 2
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
                    MUStatus              = 'active'
                    NextAction            = 'none'
                    ItemCount             = 1
                    MigUnitId             = 3
                    NodeId                = $settings.NodeId
                }
            )
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
            $Differences | Should -BeNullOrEmpty        
        }
    }
}