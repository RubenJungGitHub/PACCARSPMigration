
$tests = Import-Csv 'D:\Beheer\ShareGateReports\Production\PerfTestOrchestration2021-11-25 18.12.csv'

$filename = Get-ChildItem 'D:\Beheer\sharegatereports\production\MR*.csv' | Sort-Object { $_.BaseName } | Select-Object -Last 1

$migruns = Import-Csv $filename -Delimiter ','
$index = 0
foreach ($migrun in $migruns) {
    do {
        try {
            $migrunstarttime = [Datetime]::ParseExact($migrun.StartTime, 'yyyy-MM-dd HH:mm:ss', $null)
            $ScenarioStartTime = [Datetime]::ParseExact($tests[$index].StartDateTime, 'M/d/yyyy h:mm:ss tt', $null)
            if (($index+1) -lt $tests.count) {
                $ScenarioEndTime = [Datetime]::ParseExact($tests[$index + 1].StartDateTime, 'M/d/yyyy h:mm:ss tt', $null)
            }
            else {
                $ScenarioEndTime = [datetime]::MaxValue
            }
            $stop = $false
            if ($migrunstarttime -ge $ScenarioStartTime) {
                if ($migrunstarttime -lt $ScenarioEndTime) {
                    $migrun | Add-Member -MemberType NoteProperty -Name TestNr -Value $tests[$index].TestNr -Force
                    $stop = $true
                }
                else {
                    $index++
                }
            }  
            else {
                $migrun | Add-Member -MemberType NoteProperty -Name TestNr -Value 0 -Force
                $stop = $true
            } 
        }
        catch {
            Write-Host 'wait'
        }   
    }
    while (!$stop)
}
$migruns | Export-Csv $filename -NoTypeInformation
