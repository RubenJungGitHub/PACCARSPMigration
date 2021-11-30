# static tests of the change object for Migration Units. So check properties and value limits, but does not check if the currentMUStatus is correct
# that should be checked by the calling function.

function Test-MtHMUChange {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeLine, Mandatory = $true)][PSCustomObject]$Items
    )
    process {
        foreach ($item in $items) {
            foreach ( $property in $Item.Psobject.Properties.name ) {
                if ($property -notin ('MigUnitId', 'CurrentMUStatus', 'NewMUStatus', 'NodeId')) {
                    Throw "Property $property not expected in input object"
                }
            }
            foreach ( $property in ('MigUnitId', 'CurrentMUStatus', 'NewMUStatus')) {
                if ($property -notin ($Item.Psobject.Properties.name)) {
                    Throw "Property $property should be in input object"
                }
            }
            if ($Item.NewMUStatus -notin ('fake', 'active', 'inactive')) {
                Throw "the newMUStatus must be in fake, active or inactive, no other status '$($Item.NewMUStatus)' allowed"
            }
            If ($Item.CurrentMUStatus -notin ('active', 'fake', 'failed', 'inactive', 'new', 'notfound')) {
                Throw "the currentMUStatus '$($Item.CurrentMUStatus)' is not allowed"
            }
            If ($Item.NewMUStatus -eq $Item.CurrentMUStatus) {
                Throw "the currentMUStatus '$($Item.CurrentMUStatus)' should differ from the new status '$($Item.NewMUStatus)'"
            }
            if ($Item.NewMUStatus -eq 'active') {
                if (('NodeId' -notin $Item.Psobject.Properties.name) -or (($Item.NodeId -le 0) -and ($Item.NodeId -gt $settings.MaxNodeId))) {
                    Throw "NodeId should exist and stay in range to activate a MU. NodeId: $($Item.NodeId)"
                }
            }
        }
        return $items
    }
}