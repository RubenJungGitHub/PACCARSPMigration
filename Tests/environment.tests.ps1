# this script checks if the settingsfile is correct. 
# Test are Like: paths exist, correct versions, environment variables 
# The existence of specific properties is already checked in: Start-MtHLocalPowerShell.tests.ps1

BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json"
    # if there is no SettingSchema File, the related test will be skipped
    try {
        $script:NoSettingsSchema = !(Test-Path $settings.FilePath.SettingSchemaFile)
    }
    catch {
        $script:NoSettingsSchema = $true  
    }
}
BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json"
}
AfterAll {
    Stop-MtHLocalPowershell
}
Describe 'Environment.tests.ps1: Validate the configuration' -Tag 'Integration' {
    Context '1: Check the settingsfile against the setting schema' {
        It  '1.1: Settingsschema passes' -Skip:$NoSettingsSchema {
            [string]$schema = Get-Content -Raw -Path $settings.FilePath.SettingSchemaFile
            $result = $settingstring | Test-Json -schema $schema {
                $result | Should -Be $true
            }  
        } 
    }
    # static part of the settingsfile is tested in startMtHLocalPowershell.tests.ps1
    Context '2: Dynamic parts of settingfile' {
        It '2.1: Environment settings should be defined correctly' {
            $script:currentserversettings = @($settings.EnvironmentDetails | Where-Object { $_.Name -eq $settings.Environment })
            $currentserversettings.count | Should -Be 1
        }
        It '2.2: Database settings should be defined' {
            $currentdbsettings = @($settings.DatabaseDetails | Where-Object { $_.Name -eq $currentserversettings.Database })
            $currentdbsettings.count | Should -Be 1
        }
        It '2.3: FilePath: <_> should exist' -ForEach $settings.FilePath.psobject.properties.name {
            $result = Test-Path $settings.FilePath.$_
            $result | Should -Be $true
        }
    }
    Context '3: Check The environment' {
        It '3.1: Check Powershell Version' {
            "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)" | Should -Be $settings.StartUp.PSVersion
        }
        It "3.2: Run in 64-bit modus Should be $($settings.StartUp.Needs64bit)" {
            [Environment]::Is64BitProcess | Should -Be $settings.StartUp.Needs64bit
        } 
        It "3.3: elevated rights should be: $($settings.StartUp.Elevated)" {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal $identity
            $elevated = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
            $elevated | Should -Be $settings.StartUp.Elevated
        }
        It '3.4: Module Directory should be in ModulePath' {
            $ModulePath = $env:PSModulePath.split(';')
            "$(Get-MtHGitDirectory)\Modules" | Should -BeIn $ModulePath
        }
        It '3.5: Powershell Modules should be installed' {
            $Modules = 'BuzaShareGate', 'Pester', 'ShareGate'
            {
                Import-Module -Name $Modules -Verbose:$false
            } | Should -Not -Throw
        }
        It "3.6: Pester Should have version $($settings.StartUp.PesterVersion)" {
            $result = Get-Module Pester | Sort-Object -Property version -Descending | Select-Object -First 1 
            $result.version.ToString() | Should -Be $settings.StartUp.PesterVersion
        }
    }
}