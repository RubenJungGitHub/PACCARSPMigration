# add the testscenario numbers to the performance test files

#de Orchestration file waar alle testnummer en start en stop tijden in staan
$tests = Import-Csv 'D:\Beheer\sharegatereports\acceptance\TotalPerfTestOrchestration.csv'

#alle files met de counter info
$filenames = Get-ChildItem 'D:\Beheer\sharegatereports\acceptance\counters\*.csv' | Sort-Object { $_.BaseName }

#lees de counterdata in die je uit de files wil filteren
[string]$counterdatastring = Get-Content -Raw -Path "$(Get-MtHGitDirectory)\Deploy\counters.json"
[PSCustomObject]$Global:counterdata = $counterdatastring | ConvertFrom-Json


$id = 0 
foreach ($filename in $filenames) {
    $id++
    Write-Progress -Activity "Counter Update" -Status "$id of $($filenames.count) Processing" -PercentComplete ($id/$filenames.count) -CurrentOperation OuterLoop
    
    # check if file is not already enriched
    $content = Get-Content -Path $filename
    if ($content[0] -notlike '*"Time"*' ) {

        # replace the properties in the csv header
        foreach ($prop in $counterdata.psobject.properties.name) {
            foreach ($elem in $counterdata.$prop) {
                $content[0] = $content[0].replace($elem.old, $elem.new)
            }
        }
        $content[0] = $content[0].replace('(PDH-CSV 4.0) (W. Europe Standard Time)(-60)', 'Time') 
   
    
        $content | Set-Content -Path $filename -Force

        # assemble the properties to keep
        [string[]]$properties = @()

        foreach ($preprop in $counterdata.namesdisk) {
            foreach ($prop in $counterdata.disk) {
                $properties += $preprop.new + $prop.new
            }
        }
        foreach ($preprop in $counterdata.namesnetwork) {
            foreach ($prop in $counterdata.network) {
                $properties += $preprop.new + $prop.new
            }
        }
        foreach ($prop in $counterdata.memory) {
            $properties += $prop.new
        }
        foreach ($prop in $counterdata.processor) {
            $properties += $prop.new
        }
        $properties += 'Time'

        # load the counters with these properties
        $counters = Import-Csv $filename -Delimiter ',' | Select-Object -Property $properties
    
        # add the TestNr and the server name to each counter
        $index = 0
        $totalcounters = $counters.count
        $i = 0
        $relevantcounters = [System.Collections.Generic.List[PSObject]]::new() 
        :CounterLoop foreach ($counter in $counters) {
            if (($i % 500) -eq 1) {
                Write-Progress -Id $id -Activity "Counter Update: $($filename.BaseName)" -Status "$i of $totalcounters Complete" -PercentComplete $($i * 100 / $totalcounters) -CurrentOperation InnerLoop
            }
            $i++
            try {
                $counterstarttime = [Datetime]::ParseExact($counter.Time, 'M/d/yyyy HH:mm:ss.fff', $null)
            }
            catch {
                Write-Error "FileName: $filename    Time: $($counter.Time)"
            }
            do {
                try {
                    $ScenarioStartTime = [Datetime]::ParseExact($tests[$index].StartDateTime, 'M/d/yyyy h:mm:ss tt', $null)
                }
                catch {
                    Write-Error "Time: $($tests[$index].StartDateTime)"
                }

                if (($index + 1) -lt $tests.count) {
                    $ScenarioEndTime = [Datetime]::ParseExact($tests[$index + 1].StartDateTime, 'M/d/yyyy h:mm:ss tt', $null)
                }
                else {
                    $ScenarioEndTime = $ScenarioStartTime.addminutes(15)
                }
                $stop = $false
                if ($counterstarttime -ge $ScenarioStartTime) {
                    if ($counterstarttime -lt $ScenarioEndTime) {
                        $counter | Add-Member -MemberType NoteProperty -Name ServerName -Value $filename.BaseName.Substring(0, 11) -Force
                        $counter | Add-Member -MemberType NoteProperty -Name TestNr -Value $tests[$index].TestNr -Force
                        $relevantcounters.add($counter)
                        $stop = $true
                    }
                    else {
                        if ($index -lt $tests.count - 1) {
                            $index++
                        }
                        else {
                            Write-Host 'Counters After Last Test'
                            Break CounterLoop
                        }
                    }
                }  
                else {
                    # weggooien
                    $stop = $true
                }  
            }
            while (!$stop)
        }
        Write-Progress -Activity "Counter Update: $($filename.BaseName)"  -Status 'Ready' -Completed
        if ($relevantcounters.count -gt 0) { 
        $relevantcounters | Export-Csv $filename -NoTypeInformation
        }
        else {
            Remove-Item $filename
        }
    }
}
