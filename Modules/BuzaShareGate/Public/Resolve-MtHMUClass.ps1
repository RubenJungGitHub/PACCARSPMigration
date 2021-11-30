using module MigrationClasses
# change a PSCustomObject into a MigrationRunClass by copying only its valid properties. Other properties are causing issues. Unit test available
function Resolve-MtHMUClass {
    [OutputType([System.Collections.Generic.List[MigrationUnitClass]])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeLine)][PSCustomObject]$items        
    )
    process {
        $returnlist = [System.Collections.Generic.List[MigrationUnitClass]]::new()
        $MUCprops = ([MigrationUnitClass]::new().PSObject.properties.name)
        $items |  foreach-object {
            $returnvalue = New-Object MigrationUnitClass 
            $returnvalue.LastStartTime = [DateTime]::MinValue
            foreach ($prop in $MUCprops) 
            {
                if ($_.$prop -and !($_.$prop.Equals([DBNull]::Value))) {
                    $returnvalue.$prop = $_.$prop
                }
            }
            $returnlist.add($returnvalue)
        }
        return $returnlist  
    }
}