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
        $PermissionCollection = @()
        $RoleAssignments = $scrList.RoleAssignments
        Foreach ($RoleAssignment in $RoleAssignments) {
            #Get the Permission Levels assigned and Member
            Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member
     
            #Get the Principal Type: User, SP Group, AD Group
            $PermissionType = $RoleAssignment.Member.PrincipalType
        
            #Get all permission levels assigned (Excluding:Limited Access)
            $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select-object -property Name | Where-Object { $_.Name -ne 'Limited Access' }
            #$PermissionLevels = ($PermissionLevels | Where { $_ -ne "Limited Access" }) -join ","

            If ($PermissionLevels.Length -eq 0) { Continue }
            #Write-Host "PermissionType $($PermissionType)"
            #Get SharePoint group members
            If ($PermissionType -in $Settings.PermissionTypes) {
                #Get Group Members
                if ($PermissionType -eq 'SharePointGroup') {
                    $GroupMembers = Get-PnPGroupMembers -Identity $RoleAssignment.Member            
                }
                else {
                    $Permissions = New-Object PSObject
                    $Permissions | Add-Member NoteProperty group("-")
                    $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup("-")
                    $Permissions | Add-Member NoteProperty RoleAssignment($RoleAssignment)
                    $Permissions | Add-Member NoteProperty User($RoleAssignment.Member.Title.Split('\')[$RoleAssignment.Member.Title.Split('\').Length - 1])
                    $Permissions | Add-Member NoteProperty LoginName ($RoleAssignment.Member.LoginName)
                    $Permissions | Add-Member NoteProperty Type($PermissionType)
                    $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                    $Permissions | Add-Member NoteProperty RoleDefinitionBindings($RoleAssignment.RoleDefinitionBindings)
                    $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                    $PermissionCollection += $Permissions
                }
                #Leave Empty Groups
                If ($GroupMembers.count -eq 0) { Continue }
     
                ForEach ($User in $GroupMembers) {
                    #Add the Data to Object
                    $Association = ''
                    Switch ($RoleAssignment.member.Title) {
                        $scrSPGroups[0].Title { $Association = 'Visitors' }
                        $scrSPGroups[1].Title { $Association = 'Members' }
                        $scrSPGroups[2].Title { $Association = 'Owners' }
                    }
                    $Permissions = New-Object PSObject
                    $Permissions | Add-Member NoteProperty Group($RoleAssignment.Member.Title)
                    $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup($Association)
                    $Permissions | Add-Member NoteProperty RoleAssignment($RoleAssignment)
                    $Permissions | Add-Member NoteProperty User($User.Title)
                    $Permissions | Add-Member NoteProperty LoginName ($User.LoginName)
                    $Permissions | Add-Member NoteProperty Type($PermissionType)
                    $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                    $Permissions | Add-Member NoteProperty RoleDefinitionBindings($RoleAssignment.RoleDefinitionBindings)
                    $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                    $PermissionCollection += $Permissions
                }
            }
        }
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
            #Initially  break destination List permissions  Depends on setting UniquePermissionsFromInheritance
            if ($Settings.UniquePermissionsFromInheritance) {
                $hasUniquePermissions = Get-PnPProperty -ClientObject $dstList -Property "HasUniqueRoleAssignments"
                if (-Not $hasUniquePermissions) {
                    Write-Host "Breaking permissions for MU '$($dstList.Title)'" -ForegroundColor cyan
                    Set-PnPList -Connection $dstConn -Identity $dstList.ID -BreakRoleInheritance -CopyRoleAssignments
                }
            }
            Write-Host "Map permissions to destination MU $($dstList.Title)"
            #Check Only Associated Lists to be synchronized 
            if ($settings.AssociatedGroupsOnly) {
                $PermissionCollection = $PermissionCollection | Where-Object { $_.AssociatedSiteSPGroup -in $Settings.AssoiciatedGroupMembersCopy } 
            }
            else {
                # NOT SYSTEM ACCOUNT MAPPING!
                $PermissionCollection = $PermissionCollection | Where-Object { $_.Group -ne '' -and $_.LoginName -ne 'SHAREPOINT\SYSTEM' } 
            }
            $PermissionCollectionGrouped = $PermissionCollection | Group-Object -Property Group, Type
        
            foreach ($permgroup in $PermissionCollectionGrouped) {
                if ($Settings.CreateGroupsAndGroups) {
                    #Add  non existant target objects 
                    Write-Host "Processing $($permgroup.Name)" -f green
                    If ($permgroup.name -match 'user') {
                        #New Users 
                        foreach ($Permission in $permgroup.group) {
                            if ((Get-PnPUser -Connection $dstConn | Where-Object { $_.Title -eq $Permission.User })) {
                                New-PnPUser -Connection $dstConn -LoginName $Permission.User
                            }
                            Set-PnPWebPermission -User $Permission.User -AddRole $Permission.Permissions.Name
                        }
                    }
                    elseif ($permgroup.name -match 'SecurityGroup') {
                        foreach ($Permission in $permgroup.Group) {
                            If (-Not (Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -eq $Permission.User })) {
                                New-PnPGroup -Connection $dstConn -Title $Permission.User
                            }
                            Set-PnPWebPermission -User $Permission.User -AddRole $Permission.Permissions.Name
                            Set-PnPListPermission -Identity $dstList.Title -Group $Permission.User -AddRole $Permission.Permissions.Name
                        }
                    }
                    else {
                        If (-Not (Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -eq $permgroup.group[0].group })) {
                            New-PnPGroup -Connection $dstConn -Title $Permission.Group
                        }
                        $Permissions = ($PermissionCollection | Where-Object { $_.Group -eq $permgroup.group[0].group })[0].Permissions.Name
                        Set-PnPWebPermission -Group $permgroup.group[0].group -AddRole  $Permissions
                        #Add group members
                        $permgroup.group |  ForEach-Object { Add-PnPUserToGroup -LoginName $_.User -Connection $dstConn -Identity $_.group }
                        Set-PnPListPermission -Identity $dstList.Title -Group $permgroup.group[0].group -AddRole $Permissions
                    }
                }
            }
        }
    }
}