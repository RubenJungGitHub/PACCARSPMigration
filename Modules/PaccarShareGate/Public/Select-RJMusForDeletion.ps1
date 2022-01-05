Add-Type -AssemblyName System.Windows.Forms

function Select-RJMusForDeletion {
    [CmdletBinding()]
    $Sql = @"
    SELECT [EnvironmentName]
      ,[DestinationUrl]
    FROM [PACCARSQLO365].[dbo].[MigrationUnits]
    Group BY EnvironmentName, DestinationURL
"@
    $DestinationURLS = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Query $Sql
  
    $frmMuDeletionSelector = New-Object system.Windows.Forms.Form

    $frmMuDeletionSelector.ClientSize = '1400,600'
    $frmMuDeletionSelector.text = 'Destination URL MU Deletion selection'
    $frmMuDeletionSelector.BackColor = '#ffffff'
    $frmMuDeletionSelector.StartPosition = 'CenterScreen'
    $frmMuDeletionSelector.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog

    $btnProcess = New-Object System.Windows.Forms.Button
    $btnProcess.Location = New-Object System.Drawing.Size(1000, 550)
    $btnProcess.Size = New-Object System.Drawing.Size(120, 23)
    $btnProcess.Text = 'Process'
    $btnProcess.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $frmMuDeletionSelector.Controls.Add($btnProcess)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Size(1150, 550)
    $btnCancel.Size = New-Object System.Drawing.Size(120, 23)
    $btnCancel.Text = 'Cancel'
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $frmMuDeletionSelector.Controls.Add($btnCancel)

    $LVSource = New-Object System.Windows.Forms.ListView 
    $LVSource.View = 'Details'
    $LVSource.LabelEdit = $true
    $LVSource.FullRowSelect = $true
    $LVSource.Location = New-Object System.Drawing.Point(80, 60) 
    $LVSource.Size = New-Object System.Drawing.Size(1200, 400) 
    [void]$LVSource.Columns.Add('#')
    $LVSource.Columns[0].Width = 40
    [void]$LVSource.Columns.Add('EnvironmentName')
    $LVSource.Columns[1].Width = 200
    [void]$LVSource.Columns.Add('DestinationURL')
    $LVSource.Columns[2].Width = 650

    foreach ($DestinationURL  in $DestinationURLS) {
        $i++
        $LVi = New-Object System.Windows.Forms.ListViewItem($i)
        [void]$LVI.SubItems.Add($DestinationURL.EnvironmentName)
        [void]$LVI.SubItems.Add($DestinationURL.DestinationURL)
        [void]$LVSource.Items.Add($LVI)
    }
    $frmMuDeletionSelector.Controls.Add($LVSource)
    #endregion
    # Display the form
    $Result = $frmMuDeletionSelector.ShowDialog()
    if ($Result -eq 'OK') {
        #Return items marked with D
        $DestinationMUForDeletion = $LVSource.Items | Where-Object {$_.Text  -eq 'D'}  | Select-Object -Property SubItems
        return $DestinationMUForDeletion 
    }
}
return $null