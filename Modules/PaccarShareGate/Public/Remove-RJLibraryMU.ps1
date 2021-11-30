# deletes libraryMU  (full http path) in case MU are no longer found and to be deletedfrom target environment (MUStatus : notfound)
# this function needs to be checked

function Remove-RJLibraryMU
{
    #TO DO CHECK NOT SITEMU!!
    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $True)]
        [MigrationUnitClass]$MigrationItem
    )
    ### The entire library it to be deleted. This in case a MU has status "notfound" and settingsfile toggleswitch true
    $output = $true  
    try 
    {
        Remove-PnPList -Identity $MigrationItem.ListTitle -force
    }
    catch 
    {
        $output = $false
    }
    return $output
}