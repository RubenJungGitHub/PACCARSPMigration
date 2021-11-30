# helpfunction to compare difference between objects, no test
function Compare-MtHdiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)][PSCustomObject]$Differences,
        [Parameter(Mandatory = $true)][string]$Idprop,
        [Parameter(Mandatory = $true)][PSCustomObject]$expectedUpdate
    )
    $returnvalue = $false
    $Differences | Group-Object -Property $idprop | ForEach-Object {
        $properties = $_.group[0].psobject.properties.name -ne 'SideIndicator'
        foreach ($name in $properties) {
            if ($_.group[0].$name -ne $_.group[1].$name) {
                $index = 0
                if ($_.group[0].sideIndicator = '=>') {
                    $index = 1
                }      
                if ($expectedUpdate.$name -ne $_.group[1 - $index].$name) {
                    Write-Host "On element with ID $($_.group[0].$idprop)"       
                    Write-Host "original $name is: $($_.group[$index].$name)"
                    Write-Host "New $name is: $($_.group[1 - $index].$name)"
                    Write-Host "Expected $name is: $($expectedUpdate.$name)`r`n"
                    $returnvalue = $true
                }
            }
        }
    }
    return $returnvalue
}