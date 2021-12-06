Add-Type -AssemblyName System.Windows.Forms

function Start-RJDBRegistrationCycle {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)][string]$NextAction 
    )
    
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect      = $false # Multiple files can be chosen
        Filter           = 'CSV (*.csv)|*.csv' # Specified file types
        #Filter           = 'XLS (*.XLSX)| *.xlsx' # Specified file types
        InitialDirectory = $settings.FilePath.MUInput
    }
    [void]$FileBrowser.ShowDialog()
        #$objExcel = new-object -comobject excel.application 
        #$MUWorkBook = $objExcel.Workbooks.Open($FileBrowser.FileNames) 
        #ForEach($MUWorkSheet in $MUWorkBook.Worksheets)
        #{
        #        Write-Host $MUWorkSheet

        #}

    If ($FileBrowser.FileNames -like '*\*') {
        #Region construct form 
        #  csv should have Headers 'MigUnitId', 'CurrentMUStatus', 'NewMUStatus', 'NodeId'
        #return Import-Csv -Path $FileBrowser.FileName -Delimiter ';' 
        #Group MigUnitIDSPerSourceURL and assign NodeID
        $LVItems = [System.Collections.ArrayList]@() 
        $CSVItems = Import-Csv -Path $FileBrowser.FileName -Delimiter ';' 
        $CSVItems = Resolve-RJCSVItems $CSVItems
        #Show Nodeselector form  for all grouped SourceURLS 
        $frmNodeSelector = New-Object system.Windows.Forms.Form
        $btnProcess = New-Object System.Windows.Forms.Button
        $btnProcess.Location = New-Object System.Drawing.Size(1000, 900)
        $btnProcess.Size = New-Object System.Drawing.Size(120, 23)
        $btnProcess.Text = 'Process'
        $btnProcess.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $frmNodeSelector.Controls.Add($btnProcess)
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
        [void]$LVSource.Columns.Add('SourceURL')
        #$LVSource.LabelEdit = $true
        $LVSource.Columns[0].Width = 500
        [void]$LVSource.Columns.Add('TargetURL')
        $LVSource.Columns[2].Width = 500
        [void]$LVSource.Columns.Add('Occurence')
        $LVSource.Columns[3].Width = 20
        [void]$LVSource.Columns.Add('Action')
        $LVSource.Columns[3].Width = 50
        $CSVItemsGrouped = $CSVItems | Group-Object -Property CompleteSourceURL
        foreach ($CSVItemGroup in $CSVItemsGrouped.Group) {
            $LVi = New-Object System.Windows.Forms.ListViewItem($CSVItemGroup.CompleteSourceURL)
            [void]$LVI.SubItems.Add($CSVItemGroup.DestinationURL)
            [void]$LVI.SubItems.Add($CSVItemGroup.Count)
            [void]$LVI.SubItems.Add($NextAction)
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