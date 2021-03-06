Add-Type -AssemblyName System.Windows.Forms

function Start-RJDBRegistrationCycle {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)][string]$NextAction
    )
    
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect      = $false # Multiple files can be chosen
        Filter           = 'CSV (*.csv)|*.csv' # Specified file types
        InitialDirectory = $settings.FilePath.MUInput
    }
    [void]$FileBrowser.ShowDialog()
    If ($FileBrowser.FileNames -like '*\*') {
        #Region construct form 
        #  csv should have Headers 'MigUnitId', 'CurrentMUStatus', 'NewMUStatus', 'NodeId'
        $CSVItems = Import-Csv -Path $FileBrowser.FileName -Delimiter ';'  -encoding UTF7
        try {
            
            $CSVItems = Resolve-RJCSVItems $CSVItems |  Sort-Object CompleteSourceURL

            $CSVItemsGrouped = $CSVItems |  Group-Object -Property CompleteSourceURL, listTitle | Sort-Object CompleteSourceURL
        
            #For demo purposes only because sourceURL alters when ending on Sites
    
            #Oneliner Not working 
            #{$CSVItems | Where-Object { $_.SourceURL  -match '/sites$'} | ForEach-Object {$_.SourceURL.Replace("/sites","")}}

            #Show Nodeselector form  for all grouped SourceURLS 
            $frmMUImportSelector = New-Object system.Windows.Forms.Form

            $frmMUImportSelector.ClientSize = '1400,600'
            $frmMUImportSelector.text = 'Migration unit sourceurl group node selector'
            $frmMUImportSelector.BackColor = '#ffffff'
            $frmMUImportSelector.StartPosition = 'CenterScreen'
            $frmMUImportSelector.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog

            $btnProcess = New-Object System.Windows.Forms.Button
            $btnProcess.Location = New-Object System.Drawing.Size(1000, 550)
            $btnProcess.Size = New-Object System.Drawing.Size(120, 23)
            $btnProcess.Text = 'Process'
            $btnProcess.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $frmMUImportSelector.Controls.Add($btnProcess)

            $btnCancel = New-Object System.Windows.Forms.Button
            $btnCancel.Location = New-Object System.Drawing.Size(1150, 550)
            $btnCancel.Size = New-Object System.Drawing.Size(120, 23)
            $btnCancel.Text = 'Cancel'
            $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $frmMUImportSelector.Controls.Add($btnCancel)

            $LVSource = New-Object System.Windows.Forms.ListView 
            $LVSource.View = 'Details'
            #$LVSource.FullRowSelect = $true
            $LVSource.Location = New-Object System.Drawing.Point(80, 60) 
            $LVSource.Size = New-Object System.Drawing.Size(1200, 400) 
            [void]$LVSource.Columns.Add('#')
            $LVSource.Columns[0].Width = 40
            [void]$LVSource.Columns.Add('SourceURL')
            $LVSource.Columns[1].Width = 450
            [void]$LVSource.Columns.Add('TargetURL')
            $LVSource.Columns[2].Width = 450
            [void]$LVSource.Columns.Add('Action')
            $LVSource.Columns[3].Width = 100
            [void]$LVSource.Columns.Add('ListTtilesMissing')
            $LVSource.Columns[4].Width = 100



            foreach ($CSVItemGroup in $CSVItemsGrouped) {
                $i++
                $ListItemColour = "white"
                $ListTitleMissing = $CSVItemGroup.Group | Where-Object { $_.ListTitle -ne ' ' }
                if ($NUll -eq $ListTitleMissing) {
                    $ListTitleMissing = 'TRUE'
                    $ListItemColour = "red"
                }
                else {
                    $ListTitleMissing = 'FALSE'
                }

                $LVi = New-Object System.Windows.Forms.ListViewItem($i)
                [void]$LVI.SubItems.Add($CSVItemGroup.Group[0].CompleteSourceURL)
                [void]$LVI.SubItems.Add($CSVItemGroup.Group[0].DestinationURL)
                [void]$LVI.SubItems.Add($NextAction)
                [void]$LVI.SubItems.Add($ListTitleMissing)
                $LVI.BackColor = $ListItemColour
                [void]$LVSource.Items.Add($LVI)
            }
            $frmMUImportSelector.Controls.Add($LVSource)
            #endregion
            # Display the form
            $Result = $frmMUImportSelector.ShowDialog()
            if ($Result -eq 'OK') {
                $ReturnCSVSorted = $CSVItems  | Sort-Object { $_.SourceURL, $_.ListTitle }
                return $ReturnCSVSorted 
            }
        }
        catch {
            Write-Host " $($_.ErrorDetails)" -BackgroundColor red
        }
    }
    return $null
}