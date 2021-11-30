using Module MigrationClasses
BeforeAll {
    $dir = Get-MtHGitDirectory
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    } 
    # dit werkt wel, omdat de functie zo in de huidige (test) scope wordt geladen
    # Import-Module PaccarShareGate (dit werkt niet, omdat de module in een andere scope dan de test wordt geladen)
    Start-MtHLocalPowerShell -settingfile "$dir\Settings.json" -test
}
AfterAll {
    Stop-MtHLocalPowerShell
}

Describe 'UnitTests for Get-MtHOneSPSiteLists' -Tag 'Unit' {
    BeforeEach {
        Mock -CommandName Connect-MtHSharePoint -MockWith {return $true}
        Mock -CommandName get-PnPWeb -MockWith {} 
        Mock -CommandName Get-PnPList -MockWith {
            return [System.Collections.Generic.List[PSCustomObject]]@(
                [PSCustomObject]@{
                    EnvironmentName = 'o365'
                    hidden          = $false
                    Scope           = 'list'
                    EntityTypeName  = 'Shared Documents'
                    RootFolder      = [PSCustomObject]@{ServerRelativeUrl = '/sites/input1/shared documents' }
                }
            )
        }
        $script:result = Get-MtHOneSPSiteLists -Url (ConvertTo-MtHHttpAbsPath -SourceURL $Settings.Current.MigrationURLS[0] -path '/sites/input1')
    }

    It 'It should return 2 records'{        
        $result.count | Should -Be 2
    }
    It "It Should call function once : <_>" -ForEach @('get-PnPWeb', 'Get-PnPList', 'Connect-MtHSharePoint') {
        Should -Invoke $_ -Exactly 1
    }
    It 'Should answer with the following object'  {
        $ExpectedResult = [System.Collections.Generic.List[MigrationUnitClass]]@(
            [MigrationUnitClass]@{
                SourceUrl = 'https://' + $Settings.Current.MigrationURLS[0].SourceTenantDomain + '/sites/input1'
                Scope     = 'site'
            },
            [MigrationUnitClass]@{
                SourceUrl = 'https://' + $Settings.Current.MigrationURLS[0].SourceTenantDomain + '/sites/input1'
                ListUrl   = '/sites/input1/shared documents'
                Scope     = 'list'
            }
        )
        $script:Differences = Compare-Object -ReferenceObject $result -DifferenceObject $expectedresult -Property SourceUrl, ListUrl, Scope
        Show-MtHDiff -Differences $Differences -IdProp "MigUnitId"
        $Differences | Should -BeNullOrEmpty
    }
}
