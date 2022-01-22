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
            #First create Home Node 
            $HomeURL = $NavItemsGrouped | Where-Object { $_.Name -like 'Home*' }
            Add-PnPNavigationNode -Title "Home" -Url $HomeURL.Group.Target -Location "QuickLaunch" -First

            #Now create new menu
            $NavItemsGrouped = $NavItemsGrouped | Where-Object { $_.Name -Notlike 'Home*' }
            foreach ($navgroup in $NavItemsGrouped) {
                $NavElements = $navGroup.Name.Split(',')
                ForEach($NavElement in $NavElements)
                {
                    #Create top level 
                  $NavURL = $NavItemsGrouped.Group  | Where-Object {$_.Parent -eq $Navelement -and $_.ParentNavigation  -ne ''}
                    Add-PnPNavigationNode -Title $NavElement -Url $NavURL -Location "QuickLaunch" -First                    


                }

                Add-PnPNavigationNode -Title "Home" -Url $HomeURL.Group.Target -Location "QuickLaunch" -First
                #Add-PnPNavigationNode -Title "Contoso USA" -Url "http://contoso.sharepoint.com/sites/contoso/usa/" -Location "QuickLaunch" -Parent 2012

            }
        }
    }
}