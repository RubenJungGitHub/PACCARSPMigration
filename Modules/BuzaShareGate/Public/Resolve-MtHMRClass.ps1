using module MigrationClasses
# change a PSCustomObject into a MigrationRunClass by copying only its valid properties. Other properties are causing issues. Unit test required, not available ???
function Resolve-MtHMRClass {
    [OutputType([System.Collections.Generic.List[MigrationRunClass]])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeLine)][PSCustomObject]$items
    )
    process {
        $returnlist = [System.Collections.Generic.List[MigrationRunClass]]::new()
        $MRCprops = ([MigrationRunClass]::new().PSObject.properties.name)
        $items | foreach-object {
            $returnvalue = New-Object MigrationRunClass 
            foreach($prop in $MRCprops) {
                $returnvalue.$prop = $_.$prop
            }
            $returnlist.add($returnvalue)
        }
        return $returnlist  
    }
}