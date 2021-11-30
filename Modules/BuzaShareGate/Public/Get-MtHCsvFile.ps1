Add-Type -AssemblyName System.Windows.Forms

function Get-MtHCsvFile {
    [CmdletBinding()]
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect      = $false # Multiple files can be chosen
        Filter           = 'CSV (*.csv)|*.csv;' # Specified file types
        InitialDirectory = $settings.FilePath.MUInput
    }
    [void]$FileBrowser.ShowDialog()

    If ($FileBrowser.FileNames -like '*\*') {
        #Region construct form 
        #  csv should have Headers 'MigUnitId', 'CurrentMUStatus', 'NewMUStatus', 'NodeId'
        #return Import-Csv -Path $FileBrowser.FileName -Delimiter ';' 
        #Group MigUnitIDSPerSourceURL and assign NodeID
        $LVItems = [System.Collections.ArrayList]@() 
        $CSVItems = Import-Csv -Path $FileBrowser.FileName -Delimiter ';' 
        $SQLAllItems = Get-MtHSQLMigUnits -all 
        $SQLItems = $SQLAllItems | Where-Object { $_.MigUnitID -in $CSVItems.MigUnitID } | Group-Object -Property SourceURL
        #Show Nodeselector form  for all grouped SourceURLS 
        $frmNodeSelector = New-Object system.Windows.Forms.Form
        $btnActivate = New-Object System.Windows.Forms.Button
        $btnActivate.Location = New-Object System.Drawing.Size(1000, 900)
        $btnActivate.Size = New-Object System.Drawing.Size(120, 23)
        $btnActivate.Text = 'Activate'
        $btnActivate.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $frmNodeSelector.Controls.Add($btnActivate)
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Location = New-Object System.Drawing.Size(1150, 900)
        $btnCancel.Size = New-Object System.Drawing.Size(120, 23)
        $btnCancel.Text = 'Cancel'
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $frmNodeSelector.Controls.Add($btnCancel)
        $frmNodeSelector.ClientSize = '1400,1000'
        #$frmNodeSelector.WindowState = 'Maximized'
        $frmNodeSelector.text = 'Migration unit sourceurl group node selector'
        $frmNodeSelector.BackColor = '#ffffff'
        $frmNodeSelector.StartPosition = 'CenterScreen'
        $frmNodeSelector.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $LVSource = New-Object System.Windows.Forms.ListView 
        $LVSource.View = 'Details'
        #$LVSource.FullRowSelect = $true
        $LVSource.Location = New-Object System.Drawing.Point(80, 60) 
        $LVSource.Size = New-Object System.Drawing.Size(1200, 800) 
        [void]$LVSource.Columns.Add('NodeID')
        #$LVSource.LabelEdit = $true
        $LVSource.Columns[0].Width = 50
        [void]$LVSource.Columns.Add('Add. items')
        $LVSource.Columns[1].Width = 80
        [void]$LVSource.Columns.Add('Active items')
        $LVSource.Columns[2].Width = 80
        [void]$LVSource.Columns.Add('Total Items')
        $LVSource.Columns[3].Width = 80
        [void]$LVSource.Columns.Add('# MUs added')
        $LVSource.Columns[4].Width = 80
        [void]$LVSource.Columns.Add('SourceURL')
        $LVSource.Columns[5].Width = 890
        foreach ($SQLItem in  $SQLItems) {
            $MUToActivateItemCount = 0
            $MUTotalItems = 0
            $MUTotalItemsActive = 0
            $LVi = New-Object System.Windows.Forms.ListViewItem($SQLItem.Group[0].NodeId)
            $SQLItem.Group | ForEach-Object { $MUToActivateItemCount += $_.ItemCount }
            $SQLAllSourceURLItems = $SQLAllItems |  Where-Object { $_.sourceurl -in $SQLItem.Group[0].SourceUrl }
            $SQLAllActiveSourceUrlItems = $SQLAllSourceURLItems | Where-Object { $_.MUStatus -eq 'Active' }
            $SQLAllSourceURLItems | ForEach-Object { $MUTotalItems += $_.ItemCount }
            $SQLAllActiveSourceUrlItems | ForEach-Object { $MUTotalItemsActive += $_.ItemCount }
            $CSVItems | Where-Object {$_.MigUnitID -in $SQLAllSourceURLItems.MigUnitID -and $SQLAllSourceURLItems.SourceURL -eq  $SQLItem.Group[0].SourceUrl} | ForEach-Object { $_.NodeID = $SQLItem.Group[0].NodeId}
            [void]$LVI.SubItems.Add($MUToActivateItemCount)
            [void]$LVI.SubItems.Add($MUTotalItemsActive)
            [void]$LVI.SubItems.Add($MUTotalItems)
            [void]$LVI.SubItems.Add($SQLItem.Count)
            [void]$LVI.SubItems.Add($SQLItem.Name) 
            [void]$LVItems.Add($LVi)
            # All nodes on one url should be identical
            [void]$LVSource.Items.Add($LVI)
        }
        $frmNodeSelector.Controls.Add($LVSource)
        #endregion
        # Display the form
        $Result = $frmNodeSelector.ShowDialog()
        if ($Result -eq 'OK') 
        {
            return $CSVItems
        }
    }
    return $null
}