#help function to show differences between 2 objects also between NULL and DBNULL
function Show-MtHdiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)][PSCustomObject]$Differences,
        [Parameter(Mandatory = $true)][string]$IdProp
    )
    $Differences | Group-Object -Property $idprop | ForEach-Object {
        $properties = $_.group[0].psobject.properties.name -ne 'SideIndicator'
        foreach ($name in $properties) {
            $index = 0
            if ($_.group[0].sideIndicator = '=>') {
                $index = 1
            }  
            if ($_.group[0].$name -ne $_.group[1].$name) {    
                Write-Host "On element with ID $($_.group[0].$idprop)"       
                Write-Host "result property $name is: $($_.group[$index].$name)"
                Write-Host "expected property $name is: $($_.group[1 - $index].$name)`r`n"
            }
            if ($_.group[$index].$name.Equals([DBNull]::Value)) {
                Write-Host "On element with ID $($_.group[0].$idprop)"
                Write-Host "result property $name is: [DBNULL]"

            }
            if ($_.group[1-$index].$name.Equals([DBNull]::Value)) { 
                Write-Host "On element with ID $($_.group[0].$idprop)"
                Write-Host "expected property $name is: [DBNULL]"
            }
        }
    }
}