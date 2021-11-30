# detect changes in the Migration Units
function Start-MtHDetectionCycle {
    [CmdletBinding()]
    param()
    # get all active migration Units
    $items = Invoke-MtHSQLquery -QueryName 'D-ALL'
    $totalitems = $items.Count
    Write-Verbose "total items to scan: $totalitems"
    $i = 1
    $itemcount = 0
    $lastsourceUrl = $null
    foreach ($item in $items) {
        Write-Progress -Activity 'Detect change Scan' -Status "$i of $totalitems Complete" -PercentComplete $($i++ * 100 / $totalitems)
        # Connect-MtHSharePoint $item.SourceUrl
        if ($lastsourceUrl -ne $item.SourceUrl)
        {
            Connect-MtHSharePoint -URL $item.SourceUrl | Out-Null
            $LastSourceUrl = $item.SourceUrl
        }
        $LastItemModifiedTime = Test-MtHSPMigUnitModified -item $item
        if ($LastItemModifiedTime -eq $null) {
            # what should we do with no lastITemModified Time !!!,
            # could be a hickup in the system. where you do not want to put all MUs on Not found ???
        }
        if ($LastItemModifiedTime -gt $item.LastStartTime) {
            # put item on increment/delta
            $item.NextAction = 'delta'
            Update-MtHSQLMigUnitStatus -Item $Item
            $itemcount++
        }
    }
    Write-Progress -Activity 'Detect Change Scan' -Status 'Ready' -Completed
    Write-Verbose "changes on $itemcount items detected "
    return $itemcount
}