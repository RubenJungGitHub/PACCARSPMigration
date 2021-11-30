using module MigrationClasses
BeforeDiscovery {
    $script:MUCprops = ([MigrationUnitClass]::new().PSObject.properties.name)
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB

    # skip if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.'
     #   Write-host 'Resolve-MtHMUClass.tests -> No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.' -BackgroundColor red
    }
}
BeforeAll {
    . "$((Get-Item $PSScriptRoot).parent.fullName)\Public\Resolve-MtHMUClass.ps1"
    $script:MUCprops = ([MigrationUnitClass]::new().PSObject.properties.name)
}
Describe 'UnitTests for Resolve-MtHMUClass with empty object' -Tag 'Unit' -Skip:$skip{
    Context 'No Last StartTime' {
        BeforeEach {
            $script:InputObject = [PSCustomObject]@{
                EnvironmentName       = 'o365'
                SourceUrl             = 'https://mock.sharepoint.com/sites/input1'
                DestinationUrl        = 'https://mock.sharepoint.com/sites/M1-input1'
                ListUrl               = '/sites/input1/shared docs3'
                Sharegatecopysettings = ''
                Scope                 = 'list'
                MUStatus              = 'active'
                NextAction            = 'none'
                MigUnitId             = 4
            }
            $script:ExpectedResult = [MigrationUnitClass]@{
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
            }
        }
        It 'should resolve to the first powershell date' {
            $result = $InputObject | Resolve-MtHMUClass
            $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property $MUCprops
            Show-MtHDiff -Differences $Differences -IdProp "MigUnitId"
            $Differences | Should -BeNullOrEmpty
        }
        It 'should be an object of type MigrationUnitClass' {
            ($InputObject | Resolve-MtHMUClass).GetType().Name | Should -Be 'MigrationUnitClass'
        }
        It "should resolve to the first powershell date for property: <_>" -Foreach $MUCprops {
            $result = $InputObject | Resolve-MtHMUClass
            $result.$_ | Should -Be $ExpectedResult.$_
        }
        It "should not throw with an empty object" {
            { $null | Resolve-MtHMUClass } | Should -Not -Throw
        }

    }
}