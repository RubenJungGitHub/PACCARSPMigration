using module MigrationClasses

# this function activates or deactivates a Migration Unit. 
# not found Migration Units cannot be activated. Already activated migration units will not be reactivated
# if a reactivation is needed (a first run), first make them inactive and then active again
# changeitems have (at least) 3 properties: MigUnitId, a NewMUStatus (active, inactive, fake) and NodeId (Null,0,1,2,3)

function Submit-MtHScopedSitesLists {
    [CmdletBinding()]
    Param (
        
        [parameter(mandatory = $true)] [System.Collections.Generic.List[PSObject]] $ChangeItems       
    )
    function add-activationresult {
        param(
            [PScustomObject]$result,
            [String]$Information
        )
        $activationitem = [PSCustomObject]@{
            ExecutedAt  = Get-Date
            MigUnitId   = $_.MigUnitId
            Information = $Information 
        }
        $activateresults.add($activationitem)
    }

    #Init logfile for import CSV Activation
    $activateresults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $ActivateLog = $settings.ActivateMUCsv
  
    $ChangeItemsSorted = $changeItems | Test-MtHMUChange | Sort-Object -Property MigUnitId 
    $DbItems = Get-MtHSQLMigUnits -all # on MigUnitId order (what is done in the query).
    $changeItemId = 0
    foreach ($ChangeItem in $ChangeItemsSorted) {
        #$ChangeItem = $ChangeItemsSorted[$changeItemId]
        #$DbItems| Where-Object {$_.MigUnitID -eq $ChangeItem.MigUnitID}
        $DbItems | Where-Object { $_.MigUnitID -eq $ChangeItem.MigUnitID } | ForEach-Object { 
            if ($_.MigUnitId -eq $ChangeItem.MigUnitId) {
                if ($_.MUStatus -eq 'notfound') {
                    $Information = "Warning: Item $($_.MigUnitId) has the status notfound, so is not available in the source"
                    Write-Verbose $Information
                    $ChangeItem
                }
                else {
                    if ($_.MUStatus -ne $ChangeItem.CurrentMUStatus) {
                        $Information = "Warning: Active state deviation. Item $($_.MigUnitId) has not the status $($ChangeItemsSorted[$changeItemId].CurrentMUStatus) but status $($_.MUStatus). Item $($_.MigUnitId) will be skipped."  
                        Write-Verbose $Information
                    }
                    elseif ($_.MUStatus -eq 'active' -and $ChangeItem.newMUStatus -eq 'fake') {
                        #Transition back from active not possible
                        $Information = "Warning: Reversed status action : Item $($_.MigUnitId) current status is $($_.MUStatus) and should become $($ChangeItemsSorted[$changeItemId].newMUStatus) :Reversal of status transitions is prohibited . Item $($_.MigUnitId) will be skipped."  
                        Write-Verbose $Information
                    }
                    else {
                        $_.MUStatus = $ChangeItem.NewMUStatus
                        if ($ChangeItem.NewMUstatus -in ('active', 'fake')) {
                            $_.NextAction = 'first'
                        }
                        $_.NodeId = $ChangeItemsSorted[$changeItemId].NodeId

                        # all processing of non active MUs is only done on node 1.
                        If ($ChangeItem.NewMUStatus -ne 'active' ) {
                            $_.nodeId = 1
                        }
                        Update-MtHSQLMigUnitStatus -Item $_
                    }
                }     
            }
            if (0 -ne $Information.Length ) {
                add-activationresult $_ $Information
            }
        }      
    }
    $activateresults | Export-Csv -Path $ActivateLog -Delimiter ';' -Encoding UTF8 -NoTypeInformation   
}