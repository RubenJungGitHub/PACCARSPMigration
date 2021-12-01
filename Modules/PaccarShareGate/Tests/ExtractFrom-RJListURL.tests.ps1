BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json"
}
BeforeAll {
    $dir = Get-MtHGitDirectory
    (Get-Command -Module PaccarShareGate).name | ForEach-Object {
        . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
    }
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json"
}
AfterAll {
    Stop-MtHLocalPowerShell
}
Describe 'ConvertTo-RJListURL.tests.ps1: Extract List URLs from the source urls' -Tag 'Unit'  {

    Context '1: Check list urls '{
        It '1: should extract list URL ...' {
            
            $TestFile = -join ($settings.FilePath.MUInput,'\MigrationPlan_QualitySitesQMS.csv')
            $CSVItems = Import-Csv -Path $TestFile -Delimiter ';' 
            $Items = Resolve-RJCSVItems $CSVItems 
            Register-MtHAllSitesLists -MUsINSP $Items
        }
    }
}