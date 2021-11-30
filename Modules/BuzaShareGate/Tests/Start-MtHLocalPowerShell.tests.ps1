BeforeAll {
    . "$((Get-Item $PSScriptRoot).parent.fullName)\Public\Start-MtHLocalPowerShell.ps1"
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json"
}

BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json"
}

AfterAll {
    Stop-MtHLocalPowershell
}

Describe 'UnitTests for Settingsfile' -Tag 'Unit' {
    It '1.0: Settings should have the following property: <_>' -ForEach @('FilePath', 'Current', 'Startup', 'Environment', 'DatabaseDetails', 'NodeId', 'MaxNodeId', 'EnvironmentDetails','DatabaseDetails', 'Sharegate', 'TimeZone', 'SQLDetails') {
        ($_ -in $settings.psobject.properties.name) | Should -Be $true
    }
    It '1.1: Settings.FilePath should have the following property: <_>' -ForEach @('SettingsFile', 'Logging', 'MUInput', 'Script', 'TempDocs', 'Mappings', 'WordsFile') {
        ($_ -in $settings.FilePath.psobject.properties.name) | Should -Be $true
    }
    It "1.2: Settings.Current should have the following property: <_>" -ForEach @('MigrationURLS', 'Database', 'ExecuteTestOnDB', 'UserName', 'LoginType', 'SPVersion','DeleteNotFoundMUS','MUSourceItemsDeleteSync' ) {
        ($_ -in $settings.current.psobject.properties.name) | Should -Be $true
    }
    It '1.3: Settings.Current should have the following property: <_>' -ForEach @('SourceTenantDomain', 'DestinationTenantDomain', 'ManagedPath', 'SitePrefix' ) {
        foreach ($url in $settings.current.MigrationURLS) {
            ($_ -in $url.psobject.properties.name) | Should -Be $true
        }
    }
    It '1.4: Settings.Current should have the following property: <_>' -ForEach @('DemoSite', 'DemoList') {
        ($_ -in $settings.current.MigrationURLS[0].psobject.properties.name) | Should -Be $true
    }

    It '1.5: Settings.Current.MigrationURL should have managed path entries' -ForEach $($settings.Current.MigrationURLS) {
        $_.managedPath.count| Should -BeGreaterOrEqual 1
    }
}
