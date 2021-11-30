BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
}

BeforeAll {
    . "$(Get-MtHGitDirectory)\Modules\PaccarShareGate\Public\COnvertTo-MtHDestinationUrl.ps1"
}
AfterAll {
    Stop-MtHLocalPowerShell
}

Describe 'ConvertTo-MtHDestinationUrl.tests.ps1: Testing the target URL calculation' {
    Context '1: Check if environment name is allowed' {
        it 'Testing name validation for <_>' -ForEach $($settings.EnvironmentDetails.Name) {
            $_ | Should -BeIn @("o365","aef","acceptance","production")
        }
    }
    Context '2: Testing target URL calculation for <_>' -ForEach $($settings.EnvironmentDetails.Name) {
        BeforeAll {
        Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -environment $_
        }
        it "1.1: convert main URL" {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            # Because for O365 only one tenant available only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                #write-host "Environment $($Settings.Current.Name), SourceTenantDomain $($Settings.Current.MigrationURLS[$i].SourceTenantDomain)"
                $SourceURL = "https://$($settings.Current.MigrationURLS[$i].SourceTenantDomain)"
                $DestinationUrl = ConvertTo-MtHDestinationUrl -SourceUrl $SourceURL
                $ExpectedResult = "https://$($settings.Current.MigrationURLS[$i].DestinationTenantDomain)/$($settings.Current.MigrationURLS[$i].ManagedPath[0])/$($settings.Current.MigrationURLS[$i].SitePrefix)root"
                $DestinationUrl | Should -Be $ExpectedResult
            }
        }     
        it "1.2: convert site URL" {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                #write-host "Environment $($Settings.Current.Name), SourceTenantDomain $($Settings.Current.MigrationURLS[$i].SourceTenantDomain)"
                $SourceURL = "https://$($settings.Current.MigrationURLS[$i].SourceTenantDomain)"
                $DestinationUrl = ConvertTo-MtHDestinationUrl -SourceUrl "$($SourceURL)/$($settings.Current.MigrationURLS[$i].ManagedPath[0])/name"
                $ExpectedResult = "https://$($settings.Current.MigrationURLS[$i].DestinationTenantDomain)/$($settings.Current.MigrationURLS[$i].ManagedPath[0])/$($settings.Current.MigrationURLS[$i].SitePrefix)name"
                $DestinationUrl | Should -Be $ExpectedResult
            }

        }
        it "1.3: convert subsite URL" {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                #write-host "Environment $($Settings.Current.Name), SourceTenantDomain $($Settings.Current.MigrationURLS[$i].SourceTenantDomain)"
                $SourceURL = "https://$($settings.Current.MigrationURLS[$i].SourceTenantDomain)"
                $DestinationUrl = ConvertTo-MtHDestinationUrl -SourceUrl "$($SourceURL)/$($settings.Current.MigrationURLS[$i].ManagedPath[0])/name/subsite"
                $ExpectedResult = "https://$($settings.Current.MigrationURLS[$i].DestinationTenantDomain)/$($settings.Current.MigrationURLS[$i].ManagedPath[0])/$($settings.Current.MigrationURLS[$i].SitePrefix)name/subsite"
                $DestinationUrl | Should -Be $ExpectedResult
            }
        }
    }
}