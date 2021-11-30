BeforeAll {
    $dir = Get-MtHGitDirectory
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    } 
    Start-MtHLocalPowerShell -settingfile "$dir\Settings.json" -test
}
AfterAll {
    Stop-MtHLocalPowerShell
}
Describe 'Test-MtHMUChange.tests.ps1 : Testing the validation of a change in Migration Units' {
    Context '1:  The first tests' {
        It '1.1 : A correct item should not throw' {
            $item = [PSCustomObject]@{
                MigUnitId       = 1
                CurrentMUStatus = 'active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            }
            { Test-MtHMUChange -Item $item }  | Should -Not -Throw
        }
        It '1.2 : Should return the original item' {
            $item = [PSCustomObject]@{
                MigUnitId       = 1
                CurrentMUStatus = 'active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            }
            $result = Test-MtHMUChange -Item $item
            ($result | ConvertTo-Json) | Should -Be ($item | ConvertTo-Json)
        }
        It '1.3 : An incorrect property in the item should throw' {
            $item = [PSCustomObject]@{
                MigUnitId       = 1
                CurrentMUStatus = 'active'
                NewMUStatus     = 'fake'
                NodeId          = 1
                wrongproperty   = 1
            }
            { Test-MtHMUChange -Item $item }  | Should -Throw
        }
        It '1.4 : missing MigUnitId should throw' {
            $item = [PSCustomObject]@{
                CurrentMUStatus = 'active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            }
            { Test-MtHMUChange -Item $item } | Should -Throw
        }
        It '1.4 : incorrect new status should throw' {
            $item = [PSCustomObject]@{
                CurrentMUStatus = 'active'
                NewMUStatus     = 'new'
                NodeId          = 1
            }
            { Test-MtHMUChange -Item $item } | Should -Throw
        }
        It '1.5 : incorrect current status should throw' {
            $item = [PSCustomObject]@{
                CurrentMUStatus = 'actve'
                NewMUStatus     = 'active'
                NodeId          = 1
            }
            { Test-MtHMUChange -Item $item } | Should -Throw
        }
        It '1.5 : No status change should throw' {
            $item = [PSCustomObject]@{
                CurrentMUStatus = 'active'
                NewMUStatus     = 'active'
                NodeId          = 1
            }
            { Test-MtHMUChange -Item $item } | Should -Throw
        }
        It '1.6 : Wrong NodeId should throw' { 
            $item = [PSCustomObject]@{
                CurrentMUStatus = 'active'
                NewMUStatus     = 'active'
                NodeId          = $settings.MaxNodeId + 1
            }    
            { Test-MtHMUChange -Item $item } | Should -Throw   
        }

        It '1.7: Should return the original item after validation, also when using pipeline' {
            $randomitem = [PSCustomObject]@{
                MigUnitId       = 1
                CurrentMUStatus = 'active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            }
            $result = $randomitem | Test-MtHMUChange
            ($result | ConvertTo-Json) | Should -Be ($randomitem | ConvertTo-Json)
        }
        It '1.8: Should return the original 2 items after validation, also when using pipeline' {
            $randomitem = @([PSCustomObject]@{
                MigUnitId       = 1
                CurrentMUStatus = 'active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            },
            [PSCustomObject]@{
                MigUnitId       = 2
                CurrentMUStatus = 'active'
                NewMUStatus     = 'fake'
                NodeId          = 1
            })

            $result = $randomitem | Test-MtHMUChange
            ($result | ConvertTo-Json) | Should -Be ($randomitem | ConvertTo-Json)
        }
    }
}