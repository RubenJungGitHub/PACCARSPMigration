Function Inherit_RJPermissionsFromSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$scrSite,
        [Parameter(Mandatory = $true)][string]$dstSite,
        [Parameter(Mandatory = $true)][string]$scrListTitle,
        [Parameter(Mandatory = $false)][PSCustomObject]$dstListTitle,
        [Parameter(Mandatory = $false)][PSCustomObject]$dstListID
    )
    
    #GetSourceLib
    $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserNameSP2010, $securePwd
    $scrConn = Connect-PnPOnline -URL $scrSite -Credentials $cred -ErrorAction Stop -ReturnConnection
    Write-Host "Connected to sourcesite $($scrConn.Url)" -BackgroundColor Green

    $scrSPGroups = [System.Collections.Generic.List[PSObject]]::new()
    $dstSPGroups = [System.Collections.Generic.List[PSObject]]::new()
    #if only associated groups (AssociatedGroupsOnly = true) need to be migrated file collections, else use SourceGroupMembersCopy from settings to populate collections
    if ($settings.AssociatedGroupsOnly) {
        #Keep this order!
        $scrSPGroups.Add((Get-PnPGroup -Connection $scrConn -AssociatedVisitorGroup))
        $scrSPGroups.Add((Get-PnPGroup -Connection $scrConn -AssociatedMemberGroup))
        $scrSPGroups.Add((Get-PnPGroup -Connection $scrConn -AssociatedOwnerGroup))
        $dstSPGroups.Add((Get-PnPGroup -Connection $dstConn -AssociatedVisitorGroup))
        $dstSPGroups.Add((Get-PnPGroup -Connection $dstConn -AssociatedMemberGroup))
        $dstSPGroups.Add((Get-PnPGroup -Connection $dstConn -AssociatedOwnerGroup))
    }
    Else {
        $scrSPGroups = Get-PnPGroup -Connection $scrConn | Where-Object { $_.Title -match $Settings.SourceGroupMembersCopy }
        $dstSPGroups = Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -match $Settings.SourceGroupMembersCopy }
    }
    $scrList = Get-PnPList -Identity $scrListTitle   -Connection $scrConn -Includes RoleAssignments
    if ($NUll -eq $scrListTitle) {
        Write-Host "List '$($dstListTitle)' not detected in source" -ForegroundColor red
    }
    else {
        Write-Host "Scanning groups and permissions on MU '$($scrList.Title)' on source SC '$($scrConn.URL)'" -f green
        $PermissionCollection = Get-RJListPermissions -List $scrList
        $PermissionCollectionGrouped = $PermissionCollection | Group-Object -Property Group, Type


        $dstConn = Connect-PnPOnline -URL $dstSite -UseWebLogin -ErrorAction Stop -ReturnConnection
        Write-Host "Connected to destinationSite $($dstConn.Url)" -BackgroundColor yellow
        #Now map Source permissions to destination 
        if ($dstListID) {
            $dstList = Get-PnPList -Identity $dstListID  -Connection $dstConn -Includes RoleAssignments 
        }
        else {
            $dstList = Get-PnPList -Identity $dstlistTitle  -Connection $dstConn -Includes RoleAssignments 
        }
        if ($NUll -eq $DstList) {
            Write-Host "List '$($dstListTitle)' with ID '$($dstListID)' not detected in target" -ForegroundColor red
        }
        else {
            #Initially  break destination List permissions  Depends on setting UniquePermissionsFromInheritance and remove all groups having access before granting  access
            if ($Settings.UniquePermissionsFromInheritance) {
                $hasUniquePermissions = Get-PnPProperty -ClientObject $dstList -Property "HasUniqueRoleAssignments"
                if (-Not $hasUniquePermissions) {
                    Write-Host "Breaking permissions for MU '$($dstList.Title)' and clear current permissions" -ForegroundColor cyan
                    Set-PnPList -Connection $dstConn -Identity $dstList.ID -BreakRoleInheritance -CopyRoleAssignments
                }
            }
            #Drop associated groups
            $DestinationPermissisonCollection =  Get-RJListPermissions -List $dstList -ForPermissionRemoval | Where-Object {$_.Group -ne  (Get-PnPGroup -Connection $dstConn -AssociatedOwnerGroup).title -and $_.Group -ne  (Get-PnPGroup -Connection $dstConn -AssociatedMemberGroup).title -and $_.Group -ne  (Get-PnPGroup -Connection $dstConn -AssociatedVisitorGroup).title}

            #Clear permissions on target
            foreach ($permission  in $DestinationPermissisonCollection) { 
                If($Permission.Group -eq '-')
                {
                    Set-PnPListPermission -Identity $dstList.Title -User $Permission.User -RemoveRole $Permission.Permissions.Name
                }
                else 
                {
                    Set-PnPListPermission -Identity $dstList.Title -Group $Permission.Group -RemoveRole $Permission.Permissions.Name
                }
            }
            #$DestinationPermissisonCollection | ForEach-Object {$a = 1}

            Write-Host "Map permissions to destination MU $($dstList.Title)"
            #Check Only Associated Lists to be synchronized 
            if ($settings.AssociatedGroupsOnly) {
                $PermissionCollection = $PermissionCollection | Where-Object { $_.AssociatedSiteSPGroup -in $Settings.AssoiciatedGroupMembersCopy } 
            }
            else {
                # NOT SYSTEM ACCOUNT MAPPING!
                $PermissionCollection = $PermissionCollection | Where-Object { $_.Group -ne '' -and $_.LoginName -ne 'SHAREPOINT\SYSTEM' } 
            }


        
            foreach ($permgroup in $PermissionCollectionGrouped) {
                if ($Settings.CreateGroupsAndGroups) {
                    #Add  non existant target objects 
                    Write-Host "Processing $($permgroup.Name)" -f green
                    If ($permgroup.name -match ', user') {
                        #New Users 
                        foreach ($Permission in $permgroup.group) {
                            if ((Get-PnPUser -Connection $dstConn | Where-Object { $_.Title -eq $Permission.User })) {
                                New-PnPUser -Connection $dstConn -LoginName $Permission.User
                            }
                            #Grant user permissions on Site level
                            Set-PnPWebPermission -User $Permission.User -AddRole $Permission.Permissions.Name
                            Set-PnPListPermission -Identity $dstList.Title -User $Permission.User -AddRole $Permissions.Permissions.Name
                        }
                    }
                    elseif ($permgroup.name -match ', SecurityGroup') {
                        #New securitygroup
                        foreach ($Permission in $permgroup.Group) {
                            If (-Not (Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -eq $Permission.User })) {
                                New-PnPGroup -Connection $dstConn -Title $Permission.User
                            }
                            if ($Permission.Group -eq '-') {
                                Dont map Group users. ONly actual AD users
                                Set-PnPWebPermission -User $Permission.User -AddRole $Permission.Permissions.Name
                                Set-PnPListPermission -Identity $dstList.Title -Group $Permission.User -AddRole $Permission.Permissions.Name
                            }
                        }
                    }
                    else {
                        #New Sharepointgroup 
                        If (-Not (Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -eq $permgroup.group[0].group })) {
                            New-PnPGroup -Connection $dstConn -Title $Permission.Group
                        }
                        $Permissions = ($PermissionCollection | Where-Object { $_.Group -eq $permgroup.group[0].group })[0].Permissions.Name
                        Set-PnPWebPermission -Group $permgroup.group[0].group -AddRole  $Permissions
                        #Add group members
                        ForEach ($User in $PermGroup.Group) {
                            Set-PnPListPermission -Identity $dstList.Title -Group $User.group -AddRole $Permissions
                        }
                        #$permgroup.group |  ForEach-Object { Add-PnPUserToGroup -LoginName $_.User -Connection $dstConn -Identity $_.group }
                        #Set-PnPListPermission -Identity $dstList.Title -Group $permgroup.group[0].group -AddRole $Permissions
                    }
                }
            }
        }
    }
}