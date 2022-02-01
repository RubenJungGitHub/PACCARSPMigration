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
                $Permissions | Add-Member NoteProperty User($RoleAssignment.Member.Title)
                $Permissions | Add-Member NoteProperty LoginName ($RoleAssignment.Member.LoginName)
                $Permissions | Add-Member NoteProperty Type($PermissionType)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
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
                $Permissions | Add-Member NoteProperty User($User.Title)
                $Permissions | Add-Member NoteProperty LoginName ($User.LoginName)
                $Permissions | Add-Member NoteProperty Type($PermissionType)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                $PermissionCollection += $Permissions
            }
        }
    }
    
    #Now map Source permissions to destination 
    $dstList = Get-PnPList -Identity $dstlistTitle  -Connection $dstConn -Includes RoleAssignments 
    Write-Host "Map permissions to destination MU $($dstList.Title)"
    #Check Only Associated Lists to be synchronized 
    if ($settings.AssociatedGroupsOnly) {
        $PermissionCollection = $PermissionCollection | Where-Object { $_.AssociatedSiteSPGroup -in $Settings.AssoiciatedGroupMembersCopy } 
    }
    $PermissionCollectionGrouped = $PermissionCollection | Group-Object -Property AssociatedSiteSPGroup
    
    # NOT SYSTEM ACCOUNT MAPPING!
    foreach ($permgroup in $PermissionCollectionGrouped.group) {
        if ($settings.AssociatedGroupsOnly) {
            ForEach ($Permission in $permgroup) {
                #Add  non existant target Users? 
                #Set-PnPListPermission -Identity $dstList -Group $dstGroup -user $permission.LoginName

                #Add non existant target  groups?
                #Set-PnPListPermission -Identity $dstList -Group $dstGroup -user $permission.LoginName

                #Check if associated Group only
                $dstGroup = $null | out-null
                Switch ($Permission.AssociatedSiteSPGroup) {
                    'Visitors' { $dstGroup = Get-PnPGroup -Connection $dstConn -AssociatedVisitorGroup }
                    'Members' { $dstGroup = Get-PnPGroup -Connection $dstConn -AssociatedMemberGroup }
                    'Owners' { $dstGroup = Get-PnPGroup -Connection $dstConn -AssociatedOwnerGroup }
                    default {
                        #To do: get specific Newly created group 
                    }
                }
                #Add Users to site roles 
                Write-Host "Add '$($permission.User)' to '$($dstGroup.Title)' on detination SC '$($dstConn.URL)'" -f green
                Add-PnPUserToGroup -LoginName $Permission.User -Connection $dstConn -Identity $dstGroup.Title
            }
        }
    }
    #Finally break destination List permissions 
    $hasUniquePermissions = Get-PnPProperty -ClientObject $dstList -Property "HasUniqueRoleAssignments"

    if (-Not $hasUniquePermissions) {
        Write-Host "Breaking permissions for MU '$($dstList.Title)'" -ForegroundColor cyan
        Set-PnPList -Connection $dstConn -Identity $dstList.ID -BreakRoleInheritance -CopyRoleAssignments
    }
    #To do remove user running the script?

}