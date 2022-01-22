Add-Type -AssemblyName System.Windows.Forms

function Start-RJNavigation {
    [CmdletBinding()]
    
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Multiselect      = $false # Multiple files can be chosen
        Filter           = 'CSV (*.csv)|*.csv' # Specified file types
        InitialDirectory = $settings.FilePath.MUInput
    }
    [void]$FileBrowser.ShowDialog()
    If ($FileBrowser.FileNames -like '*\*') {
        #Region construct form 
        #  csv should have Headers 'MigUnitId', 'CurrentMUStatus', 'NewMUStatus', 'NodeId'
        $CSVItems = Import-Csv -Path $FileBrowser.FileName -Delimiter ';'  -encoding UTF7 | Where-Object { $_.Parent -ne '' }
        $TargetSites = $CSVItems.TargetSites |   Where-Object { $_ -ne '' }
        $NavItemsGrouped = $CSVItems | Where-Object { $_.Name -ne '' } |   Group-Object -Property Parent, SubLevel1, SubLevel2
        #First Clear all Menuitems
        
        foreach ($Site in $TargetSites) {
            Connect-MtHSharePoint -URL $Site | Out-Null
            #First remove all existing Nodes 
            $CurrentNavNodes = Get-PnPNavigationNode -Location QuickLaunch
            ForEach ($Node in $CurrentNavNodes) {
                Remove-PnPNavigationNode -Identity $Node.ID -Force                
            }

            #Now create new menu
            $NavItemsGrouped = $NavItemsGrouped | Where-Object { $_.Name -Notlike 'Home*' }
            foreach ($navgroup in $NavItemsGrouped) {
                $NavElements = $navGroup.Name.Split(',')
                ForEach ($NavElement in $NavElements) {
                    #Create top level 
                    $NavURL = $NavItemsGrouped.Group  | Where-Object { $_.Parent -eq $Navelement -and $_.ParentNavigation -ne '' }
                    $Parent = Add-PnPNavigationNode -Title $NavElement -Url $NavURL.ParentNavigation -Location "QuickLaunch" -First -Parent $Parent.ID                   
                    $a = 1
                    #GetParentID
                    #$ParentID  =Get-PnPNavigationNode -


                }
            }
            #Finally create Home Node 
            $HomeURL = $NavItemsGrouped | Where-Object { $_.Name -like 'Home*' }
            Add-PnPNavigationNode -Title "Home" -Url $HomeURL.Group.Target -Location "QuickLaunch" -First
            
        }
    }
}