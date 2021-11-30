BeforeAll {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $dir = Get-MtHGitDirectory
    (Get-Command -Module BuZaShareGate).name | ForEach-Object {
        . "$dir\Modules\BuzaShareGate\Public\$_.ps1" 
    } 
    #Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json"
}

BeforeDiscovery{
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
}

AfterAll {
    Stop-MtHLocalPowerShell
}
Describe 'ConvertTo-MtHHttpAbsPath.tests.ps1: Converting URLs to the correct format' -Tag 'Unit' {
    
    Context '1: Check if environment name is allowed'  -ForEach $($settings.EnvironmentDetails.Name) {
        it 'Testing name validation for <_>'  {
            $_ | Should -BeIn @("o365","aef","acceptance","production")
        }
    }
    Context '2: Testing target URL calculation for <_>' -ForEach $($settings.EnvironmentDetails.Name) {
        BeforeAll {
            Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -environment $_
            }

            It '1: should create the full URL of a relative to site...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                   #write-host"Environment $($Settings.Current.Name), SourceTenantDomain $($Settings.Current.MigrationURLS[$i].SourceTenantDomain), managedpath : $($Settings.Current.MigrationURLS[$i].ManagedPath[$mp]),  i : $($i), mp : $($mp)"
                    $path = '/' + $($settings.Current.MigrationURLS[$i].ManagedPath[$mp]) + '/example/library/file.txt'
                    $expectedResult = "https://$($Settings.Current.MigrationURLS[$i].SourceTenantDomain)/$($Settings.Current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                    $result = ConvertTo-MtHHttpAbsPath -SourceURL  $settings.Current.MigrationURLS[$i].SourceTenantDomain -path $path
                    $result | Should -Be $expectedResult
                }
            }
        }
        It '2: should create the full URL of a domain + relative url to site... for' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                   #write-host"Environment $($Settings.Current.Name), SourceTenantDomain $($Settings.Current.MigrationURLS[$i].SourceTenantDomain), managedpath : $($Settings.Current.MigrationURLS[$i].ManagedPath[$mp]),  i : $($i), mp : $($mp)"
                    $path = $Settings.Current.MigrationURLS[$i].SourceTenantDomain + '/' + $Settings.Current.MigrationURLS[$i].ManagedPath[$mp] + '/example/library/file.txt'
                    $expectedResult = "https://$($Settings.Current.MigrationURLS[$i].SourceTenantDomain)/$($Settings.Current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                    $result = ConvertTo-MtHHttpAbsPath -SourceURL $Settings.Current.MigrationURLS[$i].SourceTenantDomain  -path $path
                    $result | Should -Be $expectedResult
                }
            }
        }
    }
}