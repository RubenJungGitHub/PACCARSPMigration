Add-Type -AssemblyName System.Windows.Forms

function Start-RJNavigation {
    [CmdletBinding()]
    Param(
        [switch]$Create
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
        $CSVItems = Import-Csv -Path $FileBrowser.FileName -Delimiter ';'  -encoding UTF7 | Where-Object { $_.Parent -ne '' }
        $TargetSites = $CSVItems.TargetSites |   Where-Object { $_ -ne '' }
        $NavItemsTLGrouped = $CSVItems | Where-Object { $_.Name -ne '' } |   Group-Object -Property Parent
        $NavItemsSL1Grouped = $CSVItems | Where-Object { $_.Name -ne '' } |   Group-Object -Property Parent, SubLevel1
        $NavItemsSL2Grouped = $CSVItems | Where-Object { $_.Name -ne '' } |   Group-Object -Property Parent, SubLevel1, SubLevel2
        #First Clear all Menuitems
        
        foreach ($Site in $TargetSites) {
            Write-Host "Connect to $($Site)" 
            Connect-MtHSharePoint -URL $Site | Out-Null
            #First remove all existing Nodes 
            $CurrentNavNodes = Get-PnPNavigationNode -Location QuickLaunch
            ForEach ($Node in $CurrentNavNodes) {
                Remove-PnPNavigationNode -Identity $Node.ID -Force                
            }


            #Now create new menu
            #Drop home on toplevel, naming conventions questionable
            if ($create) {
                $NavTLItemsGrouped = $NavItemsTLGrouped | Where-Object { $_.Name -Notlike 'Home*' } 
                foreach ($navgroup in $NavTLItemsGrouped) {

                    #Get and create top level 
                    $NavItem = $NavGroup.Group  | Where-Object { $_.Parent -eq $NavGroup.Name -and $_.ParentNavigation -ne '' }
                    if ($Null -eq $NavItem) {
                        $NavItem = $NavGroup.Group[0]
                    }
                    Write-Host "Create parent node $($NavItem.Parent)" -ForegroundColor Green
                    if('' -eq $NavItem.ParentNavigation){$NavItem.ParentNavigation ='http://linkless.header/'}
                    $ParentTL = Add-PnPNavigationNode -Title $NavItem.Parent -Url $NavItem.ParentNavigation -Location "QuickLaunch"  -Parent $Parent.ID

                    #Get and create sublevel 1    
                    $NavSL1ItemsGrouped = $NavItemsSL1Grouped | Where-Object { $_.name -like ( -join ($ParentTL.Title, '*')) }
                    $NavSL1ItemsGrouped = $NavSL1ItemsGrouped
                    ForEach ($Navslgroup in $NavSL1ItemsGrouped) {
                        $NavItem = $Navslgroup.Group  | Where-Object { $_.Parent -eq $ParentTL.Title -and $_.SubLevel1Navigation -ne '' }
                        if ($Null -eq $NavItem) {
                            $NavItem = $Navslgroup.Group[0]
                        }
                        Write-Host "Create sublevel 1 node $($ParentTL.Title) / $($NavItem.SubLevel1)" -ForegroundColor Green
                        if('' -eq $NavItem.SubLevel1Navigation){$NavItem.SubLevel1Navigation ='http://linkless.header/'}

                        $ParentSL1 = Add-PnPNavigationNode -Title $NavItem.SubLevel1 -Url $NavItem.SubLevel1Navigation -Location "QuickLaunch" -Parent $ParentTL.ID  
                   
                        #Get and create sublevel 2
                        $NavSL2ItemsGrouped = $NavItemsSL2Grouped | Where-Object { $_.name -like ( -join ($ParentTL.Title, ', ', $ParentSL1.Title, '*')) }
                        $NavSL2ItemsGrouped = $NavSL2ItemsGrouped 
                        ForEach ($Navsl2group in $NavSL2ItemsGrouped) {
                            Write-Host "Create sublevel 2 node $($ParentTL.Title) / $($NavItem.SubLevel1) / $($Navsl2group.Group.SubLevel2)" -ForegroundColor Green
                            if ($Navsl2group.Group.SubLevel2 -ne '') {
                                if('' -eq $Navsl2group.Group.SubLevel2Navigation ){$Navsl2group.Group.SubLevel2Navigation  ='http://linkless.header/'}
                                Add-PnPNavigationNode -Title $Navsl2group.Group.SubLevel2 -Url $Navsl2group.Group.SubLevel2Navigation -Location "QuickLaunch" -Parent $ParentSL1.ID   | out-null
                            }
                        }
                    }
                }
                #Finally create Home Node 
                Write-Host "Create HOME node" -ForegroundColor Green
                $HomeURL = $NavItemsTLGrouped | Where-Object { $_.Name -like 'Home*' }
                Add-PnPNavigationNode -Title "Home" -Url $HomeURL.Group.ParentNavigation -Location "QuickLaunch" -First | out-null
            }
        }
    }
}