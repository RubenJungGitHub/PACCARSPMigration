BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
}
BeforeAll {
    $dir = Get-MtHGitDirectory
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    }
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
}
AfterAll {
    Stop-MtHLocalPowerShell
}
Describe 'ConvertTo-MtHHttpRelPath.tests.ps1: Converting URLs to the correct format' -Tag 'Unit'  {

    Context '1: Check relative urls  for <_>'  -ForEach $($settings.EnvironmentDetails.Name){
        BeforeAll {
            Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -environment $_
            }
        It '1: should shorten the URL relative to site...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                    $result = ConvertTo-MtHHttpRelPath -Source $SourceURL  -path $path
                    $result | Should -Be 'library/file.txt'
                }
            }
        }
        It '1a: should shorten the URL relative to site with starting slash...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                    $result = ConvertTo-MtHHttpRelPath -sourceurl $SourceURL  -path $path -startingslash
                    $result | Should -Be '/library/file.txt'
                }
            }
        }
        It '1b: should shorten the URL relative to site with starting slash...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example/library"
                    $result = ConvertTo-MtHHttpRelPath -sourceurl $SourceURL  -path $path -startingslash
                    $result | Should -Be '/library'
                }
            }
        }

        It '1c: should shorten the URL relative to site with starting slash...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://247.plaza.buzaservices.nl/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/PSDemo/Demo"
                    $result = ConvertTo-MtHHttpRelPath -sourceurl $SourceURL  -path $path -startingslash
                    $result | Should -Be '/Demo'
                }
            }
        }

        It '2: should shorten the URL relative to webapp...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                    $result = ConvertTo-MtHHttpRelPath -sourceurl $SourceURL -path $path -webapp -startingslash
                    $result | Should -Be "/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                }
            }
        }
        It '3: should shorten the URL relative to webapp, without Slash...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                    $result = ConvertTo-MtHHttpRelPath -sourceUrl $SourceURL -path $path -webapp
                    $result | Should -Be "$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example/library/file.txt"
                }
            }
        }
        It '4: should shorten the URL relative to site, also for the main sitecollection...' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://$($Settings.Current.MigrationURLS[$i].SourceTenantDomain)/library/file.txt"
                    $result = ConvertTo-MtHHttpRelPath -sourceUrl $SourceURL -path $path
                    $result | Should -Be 'library/file.txt'
                }
            }
        }
        It '5: Should replace space in url with %20' {
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example with space/library/file.txt"
                    $result = ConvertTo-MtHHttpRelPath -sourceUrl $SourceURL -path $path -webapp
                    $result | Should -Be "$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example%20with%20space/library/file.txt"
                }
            }
        }
        It '6: Should also work with a relative URL as input' { # starting / is then required
            $MigrationURLCounter = $Settings.Current.MigrationURLS.Length-1
            #Because for O365 only one tenant availeable only test first entry
            If($Settings.Current.Name -eq "o365"){$MigrationURLCounter = 0}
            for($i=0;$i -le  $MigrationURLCounter; $i++)
            {
                $ManagedPathCounter = $Settings.Current.MigrationURLS[$i].ManagedPath.Length-1
                for( $mp=0;$mp -le  $ManagedPathCounter; $mp++)
                {
                    $SourceURL = "https://$($settings.current.MigrationURLS[$i].SourceTenantDomain)"
                    $path = "/$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example with space/library/file.txt"
                    $result = ConvertTo-MtHHttpRelPath -sourceUrl $SourceURL -path $path -webapp
                    $result | Should -Be "$($settings.current.MigrationURLS[$i].ManagedPath[$mp])/example%20with%20space/library/file.txt"
                }
            }
        }
    }
}