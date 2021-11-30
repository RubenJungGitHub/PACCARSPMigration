[CmdletBinding()]
param(
    [String]$rerun = $null
)

function add-testresult {
    param(
        [PScustomObject]$result, 
        [switch]$detailed
    )
    $result.containers | ForEach-Object {
        #     $deleteitem = $_.item.fullname
        #     $testresults = $testresults | where-object { $_.item -ne $deleteitem }
        $item = [PSCustomObject]@{
            Item          = $_.item.fullname
            ExecutedAt    = '{0:yyyy-MM-dd HH:mm}' -f $_.ExecutedAt
            msecuser      = [Math]::Round($_.UserDuration.totalMilliseconds)
            msecdiscovery = [Math]::Round($_.DiscoveryDuration.totalMilliseconds)
            msecframework = [Math]::Round($_.FrameworkDuration.totalMilliseconds)
            PassedCount   = $_.PassedCount
            TotalCount    = $_.TotalCount
            FailedCount   = $_.failedcount
            SkippedCount  = $_.SkippedCount 
            NotRunCount   = $_.NotRunCount
        }
        $testresults.add($item)
        $script:testname = $item.Item
        $script:testtime = $item.ExecutedAt
    }
    if ($detailed) {
        $result.passed | ForEach-Object {
            $item = [PSCustomObject]@{
                testname = $testname
                testtime = $testtime 
                Item     = $_.name
                msecuser = [Math]::Round($_.Duration.totalMilliseconds)
            }
            $testresultsdetailed.add($item)
        }
    }
}

#show verbose switch 
$VerboseSwitch = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
write-host "Verbose = $VerboseSwitch"

#initialize
Set-Location -Path $(Get-MtHGitDirectory)
Start-MtHLocalPowerShell -settingfile '.\settings.json' -test
$testresultpath = "$($settings.FilePath.logging)\Testresults.csv" 
$testresultdetailpath = "$($settings.FilePath.logging)\Testresultsdetailed.csv"
$testresults = [System.Collections.Generic.List[PSObject]]::new()
$testresultsdetailed = [System.Collections.Generic.List[PSObject]]::new()

# read the current testresults if they exist
if ( Test-Path -Path $testresultpath ) {
    Import-Csv -Path $testresultpath -Delimiter ';' -Encoding UTF8 | ForEach-Object {
        $testresults.add($_) 
    }
}
if ( Test-Path -Path $testresultdetailpath ) {
    Import-Csv -Path $testresultdetailpath -Delimiter ';' -Encoding UTF8 | ForEach-Object {
        $testresultsdetailed.add($_) 
    }
}

# run the unit tests
$runitems = Get-ChildItem .\Modules\BuzaSharegate\Tests\*.tests.ps1
if (!!$runitems) {
    #these are only the unit tests
    $resultunit = Invoke-Pester -Script $runitems.fullname -Output Detailed -Verbose:$VerboseSwitch -PassThru 
    if ($resultunit.failedcount -eq 0) {
        Write-Host 'Unit Tests is OK'
        add-testresult -result $resultunit
    }
    else {
        Throw 'Error in Unit Tests, Integration Tests Skipped'
    }
}

# run the integration tests
$runitems = Get-ChildItem .\Tests\*.tests.ps1
if (!!$runitems) {
    #these are the integration tests
    $resultint = Invoke-Pester -Path $runitems.fullname -Output Detailed -Verbose:$VerboseSwitch -PassThru 
    if ($resultint.failedcount -eq 0) {
        Write-Host 'Tests are successful'
        add-testresult $resultint
    }
    else {
        Throw 'Error in Integration Tests'
    }
}

# if rerun, run a specific test
if (!!$rerun) {
    $runitems = Get-ChildItem ".\Tests\$rerun.tests.ps1"
    if (!!$runitems) {
        $resultint = Invoke-Pester -Path $runitems.fullname -Output Detailed -PassThru #these are the integration tests
        if ($resultint.failedcount -eq 0) {
            add-testresult $resultint -detailed
            Write-Host "$item.fullname Test(s) are successful" 
        }
        else {
            Write-Host "$rerun Test(s) are unsuccessful:"
            break
        }
        $testresultsdetailed | Export-Csv -Path $testresultdetailpath -Delimiter ';' -Encoding UTF8
    }
}

# store the test results
$testresults | Export-Csv -Path $testresultpath -Delimiter ';' -Encoding UTF8
