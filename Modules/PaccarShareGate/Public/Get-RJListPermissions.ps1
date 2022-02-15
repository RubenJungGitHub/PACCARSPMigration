# get all lists and sites from one SP sitecollection URL, no test 
function Get-RJListPermissions {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)][PSCustomObject]$List,
        [Switch]$ForPermissionRemoval
    )
    $PermissionCollection = @()
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
    $RoleAssignments = $List.RoleAssignments
    Foreach ($RoleAssignment in $RoleAssignments) {
        #Get the Permission Levels assigned and Member
        Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member
       # Write-Host "Collect information for $($RoleAssignment.Member.Title)" -f Green
        if ($RoleAssignment.Member.Title -eq 'OPS - Logistics Operations Owners') { 
            $a = 1 
        }
        #Get the Principal Type: User, SP Group, AD Group
        $PermissionType = $RoleAssignment.Member.PrincipalType
    
        #Get all permission levels assigned (Excluding:Limited Access)
        #$PermissionLevels = $RoleAssignment.RoleDefinitionBindings 
        $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select-object -property Name | Where-Object { $_.Name -ne 'Limited Access' }

        If ($PermissionLevels.Length -eq 0) { Continue }
        #Get SharePoint group members
        If ($PermissionType -in $Settings.PermissionTypes) {
            #Get Group Members
            $GroupMembers = $null
            if ($PermissionType -eq 'SharePointGroup') {
                #$GroupMembers =Get-PnPGroupMembers -Identity $RoleAssignment.Member
                #Loose System account
                $GroupMembers =Get-PnPGroupMembers -Identity $RoleAssignment.Member | Where-Object {$_.LoginName  -ne 'Sharepoint\System'}
                #Leave Empty Groups if not configured
                If ($GroupMembers.count -eq 0 -And $Settings.InheritEmptyGroups -and $Permissions.Type -ne 'User') {
                    $Permissions = New-Object PSObject
                    $Permissions | Add-Member NoteProperty Group($RoleAssignment.Member.Title.Split('\')[$RoleAssignment.Member.Title.Split('\').Length - 1])
                    $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup($Association)
                    $Permissions | Add-Member NoteProperty RoleAssignment($RoleAssignment)
                    $Permissions | Add-Member NoteProperty User('')
                    $Permissions | Add-Member NoteProperty LoginName ($User.LoginName)
                    $Permissions | Add-Member NoteProperty Type($PermissionType)
                    $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                    $Permissions | Add-Member NoteProperty RoleDefinitionBindings($RoleAssignment.RoleDefinitionBindings)
                    $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                   # Write-Host "Add Permissions  Group :  $($Permissions.Group)  User :  $($Permissions.User) $($Permissions.Permissions.Name)" -f Green
                    $PermissionCollection += $Permissions
                }

                ForEach ($User in $GroupMembers) {
                    #Add the Data to Object
                    $Association = ''
                    Switch ($RoleAssignment.member.Title) {
                        $scrSPGroups[0].Title { $Association = 'Visitors' }
                        $scrSPGroups[1].Title { $Association = 'Members' }
                        $scrSPGroups[2].Title { $Association = 'Owners' }
                    }
                    $Permissions = New-Object PSObject
                    $Permissions | Add-Member NoteProperty Group($RoleAssignment.Member.Title.Split('\')[$RoleAssignment.Member.Title.Split('\').Length - 1])
                    $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup($Association)
                    $Permissions | Add-Member NoteProperty RoleAssignment($RoleAssignment)
                    $Permissions | Add-Member NoteProperty User($User.Title.Split('\')[$User.Title.Split('\').Length - 1])
                    $Permissions | Add-Member NoteProperty LoginName ($User.LoginName)
                    $Permissions | Add-Member NoteProperty Type($PermissionType)
                    $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                    $Permissions | Add-Member NoteProperty RoleDefinitionBindings($RoleAssignment.RoleDefinitionBindings)
                    $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                   # Write-Host "Add Permissions  Group :  $($Permissions.Group)  User :  $($Permissions.User) $($Permissions.Permissions.Name)" -f Green
                    $PermissionCollection += $Permissions
                }       
            }
            else {
                #Because some members Like(zzDAFEHVCSPSiteAdmin) is a user on the source and a sharepoint group in the target we need to manipulate 
                $User = $RoleAssignment.Member.Title.Split('\')[$RoleAssignment.Member.Title.Split('\').Length - 1]
                $Group = '-'
                $Type = $PermissionType
                if ($User -in $Settings.ConvertSourceUserToTargetGroup) {
                    $Type = 'SharePointGroup'
                    $Group = $User
                }
                $Permissions = New-Object PSObject
                $Permissions | Add-Member NoteProperty group($Group)
                $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup("-")
                $Permissions | Add-Member NoteProperty RoleAssignment($RoleAssignment)
                $Permissions | Add-Member NoteProperty User($User)
                $Permissions | Add-Member NoteProperty LoginName ($RoleAssignment.Member.LoginName)
                $Permissions | Add-Member NoteProperty Type($Type)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                $Permissions | Add-Member NoteProperty RoleDefinitionBindings($RoleAssignment.RoleDefinitionBindings)
                $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
               # Write-Host "Add Permissions  Group :  $($Permissions.Group)  User :  $($Permissions.User) $($Permissions.Permissions.Name)" -f Green
                $PermissionCollection += $Permissions
            }

            If ($ForPermissionRemoval -and $GroupMembers.Count -eq 0) {
                #Register Group for removal
                $Permissions = New-Object PSObject
                $Permissions | Add-Member NoteProperty Group($RoleAssignment.Member.Title.Split('\')[$RoleAssignment.Member.Title.Split('\').Length - 1])
                $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup($Association)
                $Permissions | Add-Member NoteProperty RoleAssignment($RoleAssignment)
                $Permissions | Add-Member NoteProperty User($User.Title.Split('\')[$User.Title.Split('\').Length - 1])
                $Permissions | Add-Member NoteProperty LoginName ($User.LoginName)
                $Permissions | Add-Member NoteProperty Type($PermissionType)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                $Permissions | Add-Member NoteProperty RoleDefinitionBindings($RoleAssignment.RoleDefinitionBindings)
                $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
               # Write-Host "Add Permissions  Group :  $($Permissions.Group)  User :  $($Permissions.User) $($Permissions.Permissions.Name)" -f Green
                $PermissionCollection += $Permissions
            }
        }
    }
    return $PermissionCollection
}
