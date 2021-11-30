
$testfilenames = Get-ChildItem 'D:\Beheer\sharegatereports\acceptance\PerfTestOrchestration*.csv' | Sort-Object { $_.BaseName } 

$tests = [System.Collections.Generic.list[PSCustomObject]]::new()
$itembias = 0
foreach ($filename in $testfilenames) {
    $testsloop = Import-Csv $filename -Delimiter ','
    $testsloop | ForEach-Object { 
        [int]$_.TestNr += $itembias 
        $tests.add($_)
    }
    $itembias += $testsloop.count
}

$tests | Export-Csv 'D:\Beheer\sharegatereports\acceptance\TotalPerfTestOrchestration.csv' -NoTypeInformation
