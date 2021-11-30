using Module MigrationClasses
BeforeAll {
    $dir = Get-MtHGitDirectory
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    } 
    Start-MtHLocalPowerShell -Settingfile "$dir\Settings.json" -Test
}
AfterAll {
    Stop-MtHLocalPowerShell
}
Describe "UnitTests for Test-MtHAdminRightsAllSites" -Tag "Unit" {
    BeforeEach {
        Mock -Commandname Get-MtHPnPTenantSite -MockWith {
            [PSCustomObject]@{
                Url = 'https://' + $Settings.Current.MigrationURLS[0].SourceTenantDomain + $Settings.Current.MigrationURLS[0].DemoSite[0]
            }
        }
        Mock -CommandName Connect-MtHSharePoint -MockWith {}
    }
    It "It should return Url when PnPSiteCollectionAdmin function succeeds" {  
        Mock -CommandName Get-PnPSiteCollectionAdmin -MockWith {}
        $result = Test-MtHAdminRightsAllSites -check
        $result.length | Should -Be ('https://' + $Settings.Current.MigrationURLS[0].SourceTenantDomain + $Settings.Current.MigrationURLS[0].DemoSite[0]).Length
    }
    It "It should return empty array when PnPSiteCollectionAdmin function fails" {  
        Mock -CommandName Get-PnPSiteCollectionAdmin -MockWith {
            throw "error occured"
        }
        $result = Test-MtHAdminRightsAllSites -check
        $result.length | Should -Be 0
    }
    It "It Should call function: <_> once" -ForEach @('Get-MtHPnPTenantSite', 'Get-PnPSiteCollectionAdmin', 'Connect-MtHSharePoint') {
        Mock -CommandName Get-PnPSiteCollectionAdmin -MockWith {}
        Test-MtHAdminRightsAllSites -check
        Should -Invoke $_ -Exactly 1
    }
}