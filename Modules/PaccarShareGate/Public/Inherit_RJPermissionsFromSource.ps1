Function Inherit_RJPermissionsFromSource {
    $scrSite = 'http://dafshare-org.eu.paccar.com/organization/ops-smc/MTSMC'
    $dstSite = 'https://paccar.sharepoint.com/sites/DAF-MS-ASCOM-Document-Site'
    $scrListTitle = 'Presentaties'
    $dstlistTitle = 'Presentaties'
    #GetSourceLib
    $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserNameSP2010, $securePwd
    $scrConn = Connect-PnPOnline -URL $scrSite -Credentials $cred -ErrorAction Stop -ReturnConnection
    Write-Host "Connected to sourcesite $($scrConn.Url)" -BackgroundColor Green
    $dstConn = Connect-PnPOnline -URL $dstSite -UseWebLogin -ErrorAction Stop -ReturnConnection
    Write-Host "Connected to destinationSite $($dstConn.Url)" -BackgroundColor yellow
    $scrList = Get-PnPList -Identity $scrListTitle   -Connection $scrConn 
    $scrSPGroups = [System.Collections.Generic.List[PSObject]]::new()
    if ($settings.AssociatedGroupsOnly) {
        $scrSPGroups.Add(9Get-PnPGroup -Connection $scrConn -AssociatedMemberGroup))
        $scrSPGroups.Add((Get-PnPGroup -Connection $scrConn -AssociatedVisitorGroup))
        $scrSPGroups.Add((Get-PnPGroup -Connection $scrConn -AssociatedOwnerGroup))
    }
    Else 
    {
        $scrSPGroups = Get-PnPGroup -Connection $scrConn | Where-Object { $_.Title -match $Settings.SourceGroupMembersCopy }
    }

    #$scrSecGroups= Get-PnPUser | Were-Object {$_.Principaltype -eq 'SecurityGroup'}
    $dstGroups = Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -match $Settings.SourceGroupMembersCopy }
    foreach ($scrGroup in $ScrGroups) {
        $scrGroupMembers = Get-PnPGroupMembers -Identity $scrGroup.ID
        Write-Host "$($scrGroup.Title) detected :  $($ScrGroupMembers.Count) members" -ForegroundColor Yellow
        foreach ($scrGroupMember in $ScrGroupMembers) {
            Write-Host "$($scrGroupMember.Title)" -f cyan
            #Find associated destination group 
            $DestGroup = $dstGroups | Where-Object { $_.Title }
        }
    }
    <#
    
    $DocumentLibraries = Get-PnPList | Where-Object { $_.Hidden -eq $false } #Or $_.BaseType -eq "DocumentLibrary"

    foreach ($item in $DocumentLibraries) {
        if ($item.Title -like $sheetLists.Cells.Item(2, 1).text) {
            Write-Host $item.Title 
    
            $ListName = $item.Title
            $MyList = Get-PnPList -Identity $ListName 
            $hasUniquePermissions = Get-PnPProperty -ClientObject $MyList -Property "HasUniqueRoleAssignments"

            if (!$hasUniquePermissions) {
                Write-Host "Breaking permissions for"$ListName -ForegroundColor Yellow
                Set-PnPList -Identity $ListName -BreakRoleInheritance -ClearSubscopes
            }

            for ($iGroups = 1; $iGroups -le $rowMaxGroups - 1; $iGroups++) {
                $PermGroup = $sheetGroup.Cells.Item($rowNameGroups + $iGroups, $colGroupName).text    
                $PermLevel = $sheetGroup.Cells.Item($rowNameGroups + $iGroups, $colPermissionLevel).text
    
                Set-PnPListPermission -Identity $ListName -Group $PermGroup -AddRole $PermLevel
    
                Write-Host $SiteUrl $ListName $PermGroup $PermLevel
            }

            #Get the list & User objects
            $List = Get-PnPList -Identity $ListName
            $User = Get-PnPUser -Identity $UserID

            #Remove User from List Permissions
            $List.RoleAssignments.GetByPrincipal($User).DeleteObject()
            $Context.ExecuteQuery()

            write-host "next object..." -ForegroundColor Yellow 
        }
    }
    $objExcel.quit() 
    #>
}