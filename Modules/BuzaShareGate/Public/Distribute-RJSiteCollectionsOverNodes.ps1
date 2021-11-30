Add-Type -AssemblyName System.Windows.Forms
function Distribute-RJSiteCollectionsOverNodes {
    [CmdletBinding()]
    
    $SourceURLGroupedData = [System.Collections.ArrayList]@()   
    $ProcessingNodes = $Settings.MaxNodeID

    Write-Verbose 'Read Sourceurl intervals from JSON'
    [string]$SiteCollectionBuckets = Get-Content -Raw -Path "$(Get-MtHGitDirectory)\SiteCollectionSizeIntervals.json"
    [PSCustomObject]$SiteCollectionSizeIntervals = $SiteCollectionBuckets | ConvertFrom-Json

    Write-Verbose 'Get DB entries and  group by sourceurl and count SC totalitems'
    $DBSourceURLMus = Get-MtHSQLMigUnits -all | Group-Object -Property SourceURL
    foreach ($DBSourceURLMu in  $DBSourceURLMus) {
        $SourceURLTotalItems = 0
        $DBSourceURLMu.Group | ForEach-Object { $SourceURLTotalItems += $_.ItemCount }
        $SourceURLGroupedData.add([PSCustomObject]@{
                SourceURL  = $DBSourceURLMu.Group[0].SourceUrl
                TotalItems = $SourceURLTotalItems
                NodeID     = 0
                IntervalBucket = ""
                IntervalMinItems = 0 
                IntervalMaxItems = 0 
            }
        )
    }

    Write-Verbose 'Distribute NodeIDs over SOurceurls per interval '
    foreach ($SCSizeInterval  in  $SiteCollectionSizeIntervals.SCSizeIntervals) {
        $SCURLProcessingNode = 0
        Write-Verbose "New interval $($SCSizeInterval.SCBucket) MinimumItemCount ' $($SCSizeInterval.MinimumItemCount)  MaximumItemCount ' $($SCSizeInterval.MaximumItemCount) " 
        $SourceURLGroupSize = $SourceURLGroupedData | Where-Object { ($_.TotalItems -ge $SCSizeInterval.MinimumItemCount) -and ($_.TotalItems -lt $SCSizeInterval.MaximumItemCount) }
        foreach ($URLSizeGroup in $SourceURLGroupSize) {
            $URLSizeGroup.IntervalBucket =  $SCSizeInterval.SCBucket
            $URLSizeGroup.IntervalMinItems = $SCSizeInterval.MinimumItemCount
            $URLSizeGroup.IntervalMaxItems = $SCSizeInterval.MaximumItemCount
            If ($SCURLProcessingNode -ge $Processingnodes) {
                $SCURLProcessingNode = 1
            }
            else {
                $SCURLProcessingNode++
            }
            $URLSizeGroup.NodeID = $SCURLProcessingNode

        }
    }

    #Create form 
    $LVItems = [System.Collections.ArrayList]@() 

    #Show Nodeselector form  for all grouped SourceURLS 

    $frmNodeDistribution = New-Object system.Windows.Forms.Form
    $btnDistribute = New-Object System.Windows.Forms.Button
    $btnDistribute.Location = New-Object System.Drawing.Size(1000, 900)
    $btnDistribute.Size = New-Object System.Drawing.Size(120, 23)
    $btnDistribute.Text = 'Activate'
    $btnDistribute.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $frmNodeDistribution.Controls.Add($btnDistribute)
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Size(1150, 900)
    $btnCancel.Size = New-Object System.Drawing.Size(120, 23)
    $btnCancel.Text = 'Cancel'
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $frmNodeDistribution.Controls.Add($btnCancel)
    $frmNodeDistribution.ClientSize = '1400,1000'
    #$frmNodeDistribution.WindowState = 'Maximized'
    $frmNodeDistribution.text = 'Node distribution over Sitecolleciton urls'
    $frmNodeDistribution.BackColor = '#ffffff'
    $frmNodeDistribution.StartPosition = 'CenterScreen'
    $frmNodeDistribution.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $LVSource = New-Object System.Windows.Forms.ListView 
    $LVSource.View = 'Details'
    #$LVSource.FullRowSelect = $true
    $LVSource.Location = New-Object System.Drawing.Point(80, 60) 
    $LVSource.Size = New-Object System.Drawing.Size(1200, 800) 
    [void]$LVSource.Columns.Add('SourceURL')
    $LVSource.Columns[0].Width = 825
    [void]$LVSource.Columns.Add('SCBucket')
    $LVSource.Columns[1].Width = 75
    [void]$LVSource.Columns.Add('MiniItems')
    $LVSource.Columns[2].Width = 75
    [void]$LVSource.Columns.Add('MaxItems')
    $LVSource.Columns[3].Width = 75
    [void]$LVSource.Columns.Add('SC Items')
    $LVSource.Columns[4].Width = 100
    [void]$LVSource.Columns.Add('NodeID')
    #$LVSource.LabelEdit = $true
    $LVSource.Columns[5].Width = 50

    foreach ($URLSizeGroup in $SourceURLGroupedData) {
        $LVi = New-Object System.Windows.Forms.ListViewItem($URLSizeGroup.SourceUrl)
        [void]$LVI.SubItems.Add($URLSizeGroup.IntervalBucket)
        [void]$LVI.SubItems.Add($URLSizeGroup.IntervalMinItems)
        [void]$LVI.SubItems.Add($URLSizeGroup.IntervalMaxItems)        
        [void]$LVI.SubItems.Add($URLSizeGroup.TotalItems)
        [void]$LVI.SubItems.Add($URLSizeGroup.NodeID)
        # All nodes on one url should be identical
        [void]$LVSource.Items.Add($LVI)
    }
    $frmNodeDistribution.Controls.Add($LVSource)
    #endregion
    # Display the form
    $Result = $frmNodeDistribution.ShowDialog()
    if ($Result -eq 'OK') {
        foreach ($URLSizeGroup in $SourceURLGroupedData) {
            Invoke-MtHSQLquery -QueryName DistributeNodes -SiteCollection $URLSizeGroup
        }
    }
}