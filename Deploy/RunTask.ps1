[CmdletBinding()]
param(  
    [Parameter(Position=0)][int]$NodeId = 0,
    [Parameter(Position=1)][string]$EndTime = '2021-11-24 07:00',
    [Parameter()][switch]$PerformanceTest,
    [switch]$SkipDetection,
    [switch]$Register,
    [switch]$RecalculateDestination,
    [string]$filter,
    [Parameter(Mandatory = $false)][String[]][ValidateSet(“first”,”delta”)]$NextAction
)   
# RunScheduledTasks. this script will be called from scheduled tasks


#If nextaction missing process all. This is also added to the Start-MTHExecutionCycle but if not added here the function is not called?
if ($Null -eq $NextAction -or '' -eq $NextAction) {
    $Nextaction = @('first', 'delta')
}

Import-Module -Name BuzaSharegate -Verbose:$false
Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -initsp -NodeId $NodeId
#Start-MtHLocalPowerShell -settingfile 'D:\beheer\BuZaShareGate\settings.json' -initsp -NodeId $NodeId

# switch on verbose in the BuzaShareGate Module when a -v flag is given to this function
if ($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent) {
    (Get-Module -Name 'BuzaShareGate').SessionState.PSVariable.Set('Global:VerbosePreference', 'Continue' )
}
else {
    (Get-Module -Name 'BuzaShareGate').SessionState.PSVariable.Set('Global:VerbosePreference', 'SilentlyContinue')
} 
Write-Verbose 'Verbose is turned on'
& {
    # Start-MtHLocalPowerShell -settingfile 'D:\beheer\BuZaShareGate\settings.json' -initsp
    New-MtHSQLDatabase | Out-Null # does only create it if there is no database present
    Write-Verbose 'Verbose is still turned on'
    $result = Get-MtHSQLMigUnits -MigUnitId 1

    # if database is empty or the weekly refresh should be done , register all items
    if ((($null -eq $result) -or ((Get-Date).dayOfWeek -eq 'Monday') -or $register) -and (!$performancetest -and !$recalculateDestination)) {
        $starttime = Get-Date
        Add-Content -Path $settings.RunTasklog -Value "$starttime : Register-MtHAllSitesList started"
        if (!$filter) {
            Register-MtHAllSitesLists 
        }
        else {
            Register-MtHAllSitesLists -filter $filter
        }
        $stoptime = Get-Date
        $timediff = New-TimeSpan -Start $startTime -End (Get-Date)
        $timediffstr = '{0:00} days {1:00}:{2:00}:{3:00},{4:000}' -f $timediff.days, $timediff.hours, $timediff.minutes, $timediff.seconds, $timediff.Milliseconds
        Add-Content -Path $settings.RunTasklog -Value "$stoptime : Register-MtHAllSitesList ended. total timespan: $timediffstr"
        $skipdetection = $true
    }
    if (!$skipdetection -and (!$performancetest -and !$recalculateDestination)) {
        $starttime = Get-Date
        Add-Content -Path $settings.RunTasklog -Value "$starttime : Start-MtHDetectionCycle started"
        Start-MtHDetectionCycle
        $stoptime = Get-Date
        $timediff = New-TimeSpan -Start $startTime -End (Get-Date)
        $timediffstr = '{0:00} days {1:00}:{2:00}:{3:00},{4:000}' -f $timediff.days, $timediff.hours, $timediff.minutes, $timediff.seconds, $timediff.Milliseconds
        Add-Content -Path $settings.RuntaskLog -Value "$stoptime : Start-MtHDetectionCycle ended. total timespan: $timediffstr"
    }

    if ($performancetest) { #execution cycle (continuous until endtime) starting on the full minute
        do {
            Write-Verbose "Start Performance test for Node: $NodeId"
            Write-Verbose 'wait for the following 1 min cycle, wait at least 10 seconds'
            $time = Get-Date
            $newtime = $time.AddSeconds(70) # wait at least 10 sec and max 1.10 sec for updating the database
            $starttime = New-Object DateTime $newtime.Year, $newtime.Month, $newtime.Day, $newtime.Hour, $newtime.Minute, 0, ([DateTimeKind]::local)
            Write-Verbose "$(Get-Date) : Wait at least until it is $starttime before executing the test"
            $timediff = New-TimeSpan -Start $time -End $startTime 
            $timediffstring = '{0:00} Minutes and {1:00},{2:000} seconds' -f $timediff.minutes, $timediff.seconds, $timediff.Milliseconds
            Write-Verbose "Waiting: $timediffstring"        
            Start-Sleep -Milliseconds $timediff.TotalMilliseconds          
            #end run the executioncycle
            Start-MtHExecutionCycle -LogPerformanceTests
        }
        while ($(Get-Date) -lt [datetime]::parseexact($endtime, 'yyyy-MM-dd HH:mm', $null))
    }
    elseif ($RecalculateDestination)
    {
        $items = Get-MtHSQLMigUnits -all
        foreach ($item in $items) {
            $item.DestinationURL = ConvertTo-MtHDestinationUrl -SourceUrl $item.SourceUrl
            Update-MtHSQLMigUnitStatus -Item $item -UpdateDestination
        }
    }
    else {
        $starttime = Get-Date
        Add-Content -Path $settings.RunTasklog -Value "$starttime : Start-MtHExecutionCycle started"
        Start-MtHExecutionCycle -NextAction:$NextAction
        $stoptime = Get-Date
        $timediff = New-TimeSpan -Start $startTime -End (Get-Date)
        $timediffstr = '{0:00} days {1:00}:{2:00}:{3:00},{4:000}' -f $timediff.days, $timediff.hours, $timediff.minutes, $timediff.seconds, $timediff.Milliseconds
        Add-Content -Path $settings.RunTasklog -Value "$stoptime : Start-MtHExecutionCycle end. total timespan: $timediffstr"
        #Log progress : Check if file exists 
        $ProgressFile = -Join ($Settings.FilePath.SGErrorReports, '\MigratrationProgressLog.csv')
        If (!(Test-Path $ProgressFile)) {
            Add-Content -Path "$($ProgressFile)" -Value ( -Join ('LogDate', ',', 'EnvironmentName', ',', 'ItemsCountINScope', ',', 'MUsMigrated', ',', 'MUStatus', ',', 'NextAction')) 
        }
        $Progress = Invoke-MtHSQLquery -QueryName LogMigrationProgress -NoResolveMUClass
        $Progress | ForEach-Object { Add-Content -Path "$($ProgressFile)" -Value ( -Join ($_.LogDate, ',', $_.EnvironmentName, ',' , $_.ItemsCountINScope, ',', $_.MUsInscope, ',', $_.MUStatus, ',', $_.NextAction)) }    
    }

} *>&1 | ForEach-Object { 
    $Mes = 'Output'
    if ($_.writewarningstream) {
        $Mes = 'Warning'
    }
    if ($_.writeverbosestream) {
        $Mes = 'Verbose'
    }
    if ($_.writeerrorStream) {
        $Mes = 'Error'
    }
    Write-Output "$(Get-Date) : $Mes : $_" 
    if ($_.writeerrorStream) {
        Write-Output $_ | Out-String
    }
}  | Tee-Object -Append -FilePath $settings.RuntaskDetailedLog