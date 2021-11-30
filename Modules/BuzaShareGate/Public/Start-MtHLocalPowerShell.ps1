###########################################################################################################
# FUNCTION TO RUN AT THE START OF EVERY POWERSHELL SCRIPT for Loading the SETTINGS object                 #
# this module should be in the PSModulePath                                                               #
# $settings is loaded in the global scope, it skips when already loaded correctly                         #
# Validation is done via Pester Test (environment.tests.ps1)                                              #
# Actively Used Modules (BuzaSharegate) are reloaded                                                      #
# Stop-MthLocalPowershell undo's what is loaded with this function                                        #
# Verbose switching, switch back with (doesn't work well because a module has its own scope)              #
###########################################################################################################

function Start-MtHLocalPowerShell {
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true)][PSCustomObject]$settingfile, # the complete path and file of the settingfile
        [parameter(mandatory = $false)][String]$environment,
        [parameter(mandatory = $false)][int32]$NodeId = 0,
        [switch]$test, # use this switch when you need to load the defined test settings.
        [switch]$initsp # also initialize SharePoint
    )

    # set default encoding
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'

    # change the default color of Verbose
    # $Host.PrivateData.VerboseForegroundColor = 'Gray'

    # Set the security protocol on TLS 1.2, sometimes needed for a webcall
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    Write-Verbose 'IN Start-MtHPowershell'

    # get local settings and return them
    if (Test-Path $settingfile) {
        
        # drop loaded settings
        if (Test-Path variable:global:settings) {
            Remove-Variable -Name settings -Scope global
        }

        # get global settings
        [string]$settingstring = Get-Content -Raw -Path $settingfile # Raw makes it a string of one line
        [PSCustomObject]$Global:settings = $settingstring | ConvertFrom-Json
     
        # Reload Local Module, if development changes are made it should be reloaded
        if ('LocalModules' -in $settings.startup.psobject.properties.name) {
            # re-import local module
            $settings.startup.LocalModules.split(',').Trim() | ForEach-Object {
                Get-Module $_ | Remove-Module -Force
                Import-Module -Name $_ -Force -Verbose:$false
            }         
            Write-Verbose "Reloaded Modules: $($settings.startup.LocalModules)"
        }

        # get currentsettings from settings environment variables. load with Start-LocalPowerShell
        if ($environment) {
            $settings.environment = $environment 
        }  # if a specific environment is requested
        
        if ('Environment' -in $settings.psobject.properties.name) { 
            $currentserversettings = $settings.EnvironmentDetails | Where-Object { $_.Name -eq $settings.environment } | Select-Object -First 1
            if ($null -eq $currentserversettings) {
                throw "no detailed information for $($settings.environment)"
            }
            else {
                $settings | Add-Member -MemberType NoteProperty -Name Current -Value $currentserversettings
            }
            if ($currentserversettings.timezone -notmatch 'local') {
                $timezone = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object { $_.StandardName -match $currentserversettings.timezone } | Select-Object -First 1
            }
            else {
                $timezone = [System.TimeZoneInfo]::Local
            }
            $settings | Add-Member -MemberType NoteProperty -Name TimeZone -Value $timezone
            if (!$test) {
                $currentdbsettings = $settings.DatabaseDetails | Where-Object { $_.Name -eq $settings.current.database } | Select-Object -First 1
            }
            else {
                # if the ExecuteTestOnDB is not valid, currentdbsettings will be $null resulting in not executing the database test
                $currentdbsettings = $settings.DatabaseDetails | Where-Object { $_.Name -eq $settings.current.ExecuteTestOnDB } | Select-Object -First 1
            }
            if ($null -eq $currentdbsettings) {
                if ($test) {
                    if ($settings.current.ExecuteTestOnDB -ne 'None') {               
                        throw "no detailed information for test database: $($settings.current.ExecuteTestOnDB) on environment $($settings.current.name)"
                    }
                } 
                else {
                    throw "no detailed information for database $($settings.current.database) on environment $($settings.current.name)"
                }
            }
            else {
                $settings | Add-Member -MemberType NoteProperty -Name SQLDetails -Value $currentdbsettings -Force
            }
        }
        if ($NodeID -ne 0) {
            $settings.NodeId = $NodeId
        }
        if ($initsp) {
            Initialize-MtHSharePoint
        }

        # define logging filenames if not defined yet
        if ($null -eq $settings.OrchestrationCsv) { 
            $DateTime = (Get-Date -Format 'yyyy-MM-dd HH.mm')
            $orgcsvname = "$($settings.FilePath.Logging)\PerfTestOrchestration$DateTime.csv"
            $settings | Add-Member -MemberType NoteProperty -Name OrchestrationCsv -Value $orgcsvname -Force
            $runtasklog = "$($settings.FilePath.Logging)\Runtasklog-Node$NodeID-$DateTime.log"
            $settings | Add-Member -MemberType NoteProperty -Name RuntaskLog -Value $runtasklog -Force
            $perfcsvname = "$($settings.FilePath.Logging)\Performance-Node$NodeID-$DateTime.csv"
            $settings | Add-Member -MemberType NoteProperty -Name PerformanceCsv -Value $perfcsvname -Force
            $runtaskdetailedlog = "$($settings.filepath.logging)\RunTasklog-Detailed-Node$NodeID-$DateTime.log"
            $settings | Add-Member -MemberType NoteProperty -Name RuntaskDetailedLog -Value $runtaskdetailedlog -Force
            $ActivateMUCsvName = "$($settings.FilePath.Logging)\ActivateMULog.csv-$DateTime.csv"
            $settings | Add-Member -MemberType NoteProperty -Name ActivateMUCsv -Value $ActivateMUCsvName -Force
        }

        # settings are completely loaded, now show info to the user (when verbose is on)
        Write-Verbose 'Start-MtHLocalPowerShell: defined Settings'
        Write-Verbose "test script : $test"
        Write-Verbose "SharePoint Environment : $($settings.environment)"
        Write-Verbose "Computername = $env:computername"
        if ($env:computername -in $settings.current.computernames) {
            Write-Verbose "Computername is in the intended range: $($settings.current.computernames -join(', '))"
        }
        else {
            if ($settings.current.computernames) {
                Write-Warning "Computername: $env:computername is not in the intended range: $($settings.current.computernames -join(', '))"
            }
            else {
                Write-Warning 'Computername range is empty'
            }
        }
        Write-Verbose "SQL.DatabaseName: $($settings.SQLDetails.Name),$($settings.SQLDetails.Database)"
        Write-Verbose "SQL Database may be deleted: $($settings.SQLDetails.DeleteDB)"
    }
    else {
        throw 'SETTINGFILE not found'
    }
}