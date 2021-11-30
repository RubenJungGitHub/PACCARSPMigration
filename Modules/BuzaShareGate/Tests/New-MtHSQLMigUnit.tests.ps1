# to be able to work with Unicode characters. the file should be saved as UTF-8 with BOM. Otherwise Powershell doesn't recognize
# this file as a UTF8 file are decoded as Windows-1252. 

using module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB

    # skip if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.'
       # Write-host 'New-MtHSQLMigUnit.tests -> No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.' -BackgroundColor red

    }
}
BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB
       if (!$skip) {
        Remove-MtHSQLDatabase
        New-MtHSQLDatabase
    }
    $script:MUCprops = [MigrationUnitClass]::new().PSObject.properties.name
}
AfterAll {
    Stop-MtHLocalPowershell -test
}

# succeeds only when all tests are run, because the MigUnitId is set by the order of running the tests 
describe "New-MtHSQLMigUnit: testing new entries" -skip:$skip {
    It "1: Check if I can Enter a MU" {
        $Item1 = [MigrationUnitClass]@{
            EnvironmentName       = 'o365'
            SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
            DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
            ListUrl               = '/sites/input1/shared docs3'
            ListTitle             = 'documents3'
#            ItemCount             = 100
#            ListTemplate          = 100
#            Sharegatecopysettings = ''
            Scope                 = 'list'
            MUStatus              = 'active'
            NextAction            = 'none'
            MigUnitId             = 1
            LastStartTime         = [datetime]::MinValue
            NodeId                = 1
        }
        New-MtHSQLMigUnit -Item $item1
        $result1 = Get-MtHSQLMigUnits -MigUnitId 1
        $script:Differences = Compare-Object -ReferenceObject $item1 -DifferenceObject $result1 -Property $MUCprops
        Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
        $Differences | Should -BeNullOrEmpty
    }
    It "2: Check if I can enter a MU with special characters" {
        $Item2 = [MigrationUnitClass]@{
            EnvironmentName       = 'o365'
            SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
            DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
            ListUrl               = '/sites/input1/shared docs3'
            ListTitle             = "special characters !@$%^&*()~/?\[]{}|- escaped characters: `` `# escaped quotes `' `" "
#            ItemCount             = 200
#            ListTemplate          = 100
#            Sharegatecopysettings = ''
            Scope                 = 'list'
            MUStatus              = 'active'
            NextAction            = 'none'
            MigUnitId             = 2
            LastStartTime         = [datetime]::MinValue
            NodeId                = 1
        }
        New-MtHSQLMigUnit -Item $item2
        $result2 = Get-MtHSQLMigUnits -MigUnitId 2
        $script:Differences = Compare-Object -ReferenceObject $item2 -DifferenceObject $result2 -Property $MUCprops
        Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
        $Differences | Should -BeNullOrEmpty
    }
    It '3: Check if I can enter a MU with chinese and arabic characters' {
        $Item3 = [MigrationUnitClass]@{
            EnvironmentName       = 'o365'
            SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
            DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
            ListUrl               = '/sites/input1/shared docs3'
            ListTitle             = 'foreign characters: ÀÂÖ×ëñóąû»ʸʌɸɏɚΰ and even right to left אּﮈﯧﻎﻄﺒ'
#            ItemCount             = 300
#            ListTemplate          = 100
#            ListId                = 'abc'
#            Sharegatecopysettings = ''
            Scope                 = 'list'
            MUStatus              = 'active'
            NextAction            = 'none'
            MigUnitId             = 3
            LastStartTime         = [datetime]::MinValue
            NodeId                = 1
        }
        New-MtHSQLMigUnit -Item $item3
        $Result3 = Get-MtHSQLMigUnits -MigUnitId 3
        $script:Differences = Compare-Object -ReferenceObject $Item3 -DifferenceObject $Result3 -Property $MUCprops 
        Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
        $Differences | Should -BeNullOrEmpty
    }
    It "4: Check if I can enter a MU with a - hyphen\dash" {
        $Item4 = [MigrationUnitClass]@{
            EnvironmentName       = 'o365'
            SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
            DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
            ListUrl               = '/sites/input1/shared docs3'
            ListTitle             = 'hyphen - test'
            Scope                 = 'list'
            MUStatus              = 'active'
            NextAction            = 'none'
            MigUnitId             = 4
            LastStartTime         = [datetime]::MinValue
            NodeId                = 1
        }
        New-MtHSQLMigUnit -Item $item4
        $result4 = Get-MtHSQLMigUnits -MigUnitId 4
        $script:Differences = Compare-Object -ReferenceObject $item4 -DifferenceObject $result4 -Property $MUCprops
        Show-MtHdiff -Differences $Differences -IdProp 'MigUnitId'
        $Differences | Should -BeNullOrEmpty
    }
}
