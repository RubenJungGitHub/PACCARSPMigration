[CmdletBinding()]
param(  
    [string]$testfile = 'perftestAccOneItem.json'
) 

function WaitForFinish {
    $lastnum = 0
    do {
        $dbitems = $TestSourceURLS | ForEach-Object { Get-MtHSQLMigUnits -Url $_ }
        $items = $dbitems | Where-Object { ($_.NextAction -ne 'none') }
        if ($lastnum -ne $items.count) {
            Write-Verbose "No Of items not migrated: $($items.count)"
        }
        if ($items.count -ne 0) {
            Start-Sleep -Seconds 15
        } 
        $lastnum = $items.count  
    }
    while ($items.count -ne 0)
    Write-Verbose 'All items migrated'
}

# start and cleanup, wait for finish
Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -initsp
$TestSourceURLS = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($MigUnitURL in $Settings.Current.MigrationURLS) {
    foreach ($DemoSite  in $MigUnitURL.DemoSite) {
        $TestURL = ConvertTo-MtHHttpAbsPath -SourceURL $MigUnitURL.SourceTenantDomain -path $DemoSite
        $TestSourceURLS.Add($TestURL)
    }
}

Write-Verbose 'Finish running jobs first'
WaitForFinish

# load the JSON test file
[string]$perfteststring = Get-Content -Raw -Path "$($settings.FilePath.Script)\Performance\$testfile" # Raw makes it a string of one line
[PSCustomObject]$condensedperftests = $perfteststring | ConvertFrom-Json

# create testdata and register
$ReRegisterSites = New-MtHDummyMigrationUnits -Buckets $condensedperftests.testdata -v
if ($ReRegisterSites -eq $true) {
    Write-Verbose 'Registrating the newly created lists....'
    Register-MtHAllSitesLists -setofsites $TestSourceURLS
}

# expand $perftests (repeated tests)
Write-Verbose "Expanding Tests from File: $testfile"
$perftests = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($condensedperftest in $condensedperftests.tests) {
    $NumOfTests = 1
    if ($null -ne $condensedperftest.repeat) {
        $NumOfTests = $condensedperftest.repeat
    }
    foreach ($i in 1..$NumOfTests) {
        $newtest = [PSCustomObject]@{
            Name          = $condensedperftest.Name + ' Run: ' + $i
            group         = $condensedperftest.Name
            StartDateTime = $condensedperftest.StartDateTime
            NodeId        = $condensedperftest.NodeId
            NextAction    = $condensedperftest.NextAction
            Bucket        = $condensedperftest.Bucket
            AmountPerNode = $condensedperftest.AmountPerNode
            deletetarget  = $condensedperftest.deletetarget
        }
        $perftests.add($newtest)
    }
}

# adding a number and a Minvalue startdatetime and enddatetime to all performancetests
[int]$testNr = 1
foreach ($perftest in $perftests) {
    $perftest | Add-Member -MemberType NoteProperty -Name TestNr -Value $TestNr
    $testNr++
    if ($null -eq $perftest.StartDateTime) {
        $starttime = [datetime]::MinValue
        $perftest | Add-Member -MemberType NoteProperty -Name StartDateTime -Value $starttime -Force
    }
    else {
        $starttime = [datetime]::parseexact($perftest.StartDateTime, 'dd/MM/yyyy HH:mm', $null)
        $perftest | Add-Member -MemberType NoteProperty -Name StartDateTime -Value $starttime -Force
    }
    $endtime = [datetime]::MinValue
    $perftest | Add-Member -MemberType NoteProperty -Name EndDateTime -Value $endtime -Force
    $NodeIdcontent = ($perftest.nodeId | ConvertTo-Json -Depth 5) -replace '\s' -replace '"'
    $perftest | Add-Member -MemberType NoteProperty -Name NodeIdcontent -Value $NodeIdcontent
}

# export the tests to a file for later PowerBI analysis
$perftests | Export-Csv $settings.OrchestrationCsv -NoTypeInformation

# Rotate wordt nu niet meer gebruikt. De bedoeling is om niet 2x dezelfde MU achter elkaar te migreren. Nu gebeurt dit wel. 
$rotatestartitem = 0

foreach ($perftest in $perftests) {

    # wait until we may update the database
    Write-Verbose "Preparing Performance test: $($perftest.Name)"
    $time = Get-Date
    if ($perftest.StartDateTime -gt $time) {
        $starttime = $perftest.StartDateTime
    }
    else {
        $newtime = $time.AddSeconds(40) # wait at least 10 sec and max 1.10 sec for updating the database
        $starttime = New-Object DateTime $newtime.Year, $newtime.Month, $newtime.Day, $newtime.Hour, $newtime.Minute, 30, ([DateTimeKind]::local)
        $perftest.StartDateTime = $starttime        
    }
    Write-Verbose "$(Get-Date) : Wait until it is $starttime, when we can activate the test by filling the database"
    $timediff = New-TimeSpan -Start $time -End $startTime 
    $timediffstring = '{0:00} Minutes and {1:00},{2:000} seconds' -f $timediff.minutes, $timediff.seconds, $timediff.Milliseconds
    Write-Verbose "Waiting: $timediffstring"
    Start-Sleep -Milliseconds $timediff.TotalMilliseconds

    # select the testitems (Migration Units) which should be migrated
    Write-Verbose "$(Get-Date) : Activate the test: $($perftest.Name)"

    Write-Verbose "Check # of Bucket MU's per node SourceURL: $($perftest.Name)"
    $totalbuckets = ($condensedperftests.testdata | Where-Object { $_.Bucket -eq $perftest.Bucket }).Amount
    $dbitems = $TestSourceURLS | ForEach-Object { Get-MtHSQLMigUnits -Url $_ }
    Write-Verbose 'Get DBitems only for process inscope'
    $totalitems = $dbitems | Where-Object { ($_.Scope -eq 'list') -and ($_.ListTitle -like "Test_$($perftest.Bucket)_*") } | Group-Object -Property SourceUrl
    Write-Verbose 'Validate if there are as many sitecollections as nodes defined'
    $minnumberofsitecollections = $totalitems.count 
    Write-Verbose "Validate if ALL sitecollections contain enought MU's for processing"
    $minnumberofitems = ($totalItems | ForEach-Object { $_.Group.Count } | Measure-Object -Minimum  | Select-Object -Property Minimum).Minimum
       
    # Make sure there are enough totalbuckets in each sitecollection
    if ($minnumberofitems -le $totalbuckets -and $minnumberofsitecollections -ge $perftest.NodeID.Count) {

        $SiteCollectionID = 0
        foreach ($Node in $perftest.NodeId) {
            #One line not working
            $testitems = $totalitems[$SiteCollectionID].Group | Select-Object -First $perftest.AmountPerNode
  
            Write-Verbose "activate the tests of a specific node: $Node in sitecolection $($TestSourceURLS[$SiteCollectionID])" 
            foreach ($testitem in $testitems) {
                $Item = [PSCustomObject]@{
                    MUStatus   = 'Active' 
                    NextAction = $perftest.NextAction 
                    NodeId     = $Node
                    MigUnitId  = $testitem.MigUnitId
                }
                Update-MtHSQLMigUnitStatus -Item $Item
                Write-Verbose "activated the test for node $($Node): $($Item.MigUnitId)"              
            }
            $SiteCollectionID++
        }
        Write-Verbose "Test Activated $($perftest.Name)"    
       
        # export the tests to the csv file again for later PowerBI analysis (overwrite the starttime and add the MigrationIDs)
        $MigrationIdcontent = ($MigrationIds | ConvertTo-Json -Depth 5) -replace '\s' -replace '"'
        $perftest | Add-Member -MemberType NoteProperty -Name MigrationIdcontent -Value $MigrationIdcontent -Force
        $perftests | Export-Csv $settings.OrchestrationCsv -NoTypeInformation 
    
        # now wait for the migration itself, executed on the nodes
        Write-Verbose 'wait for the migration to finish'
        WaitForFinish
        Write-Verbose "Migration test: $($perftest.Name) is FINISHED"
        $perftest.EndDateTime = Get-Date
        $perftests | Export-Csv $settings.OrchestrationCsv -NoTypeInformation 
    
        # delete migrated units in target environment
        if ($perftest.deletetarget -ne 'no') {
            #$items = Get-MtHSQLMigUnits -all | Where-Object { $_.Scope -eq 'list' }
            $Items = $MigrationIds | ForEach-Object { Get-MtHSQLMigUnits -MigUnitId  $_ } 
            foreach ( $item in $items ) {
                Connect-MtHSharePoint -URL $item.DestinationURL | Out-Null
                if ($perftest.deletetarget -eq 'list') {
                    Remove-PnPList -Identity $item.ListTitle -Force
                }
                elseif ($perftest.deletetarget -eq 'items') {
                    Get-PnPListItem -List $item.ListTitle | ForEach-Object { Remove-PnPListItem -List $item.ListTitle -ID $_.Id -Force }
                }
            }
            Write-Verbose("Target items in $($item.DestinationURL) deleted")
            if ($minnumberofitems -gt $totalbuckets / 2) {
                Write-Verbose 'wait 5 minutes when you needed to delete more then half the target lists.'
                Start-Sleep -S 300
            }
        }
    }
    else {
        Write-Verbose 'Cancelled this test, because more buckets needed then testdata created'
    }
}
