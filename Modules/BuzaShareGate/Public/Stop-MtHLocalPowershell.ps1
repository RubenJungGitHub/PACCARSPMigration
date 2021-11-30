function Stop-MtHLocalPowershell {
    [CmdletBinding()]
    param (
        [Parameter()][switch]$test
    )
    Write-Verbose "Stop-MtHLocalPowershell:  remove settings"
    <#if (($settings.startup.verbose) -and (Test-Path variable:global:OldVerbose)) {      
        Write-Verbose "Setting VerbosePreference back to original status: $global:OldVerbose"
        Set-Variable -Name VerbosePreference -Value $global:OldVerbose -Scope Global -Force
        Remove-Variable -Name OldVerbose -Scope Global
    } #>

    #Remove the settings variable, except if you are in test (when this function is called after every test script)
    if (!$test -and $(Test-Path variable:global:settings)) {
        Remove-Variable -Name settings -Scope Global 
    }  
}