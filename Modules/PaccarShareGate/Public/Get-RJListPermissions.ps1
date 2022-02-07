# get all lists and sites from one SP sitecollection URL, no test 
function Get-RJListPermissions {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)][PSCustomObject]$List,
        [Switch]$ForPermissionRemoval
    )
    $PermissionCollection = @()
    $RoleAssignments = $List.RoleAssignments
    Foreach ($RoleAssignment in $RoleAssignments) {
        #Get the Permission Levels assigned and Member
        Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member
 
        #Get the Principal Type: User, SP Group, AD Group
        $PermissionType = $RoleAssignment.Member.PrincipalType
    
        #Get all permission levels assigned (Excluding:Limited Access)
        $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select-object -property Name | Where-Object { $_.Name -ne 'Limited Access' }

        If ($PermissionLevels.Length -eq 0) { Continue }
        #Get SharePoint group members
        If ($PermissionType -in $Settings.PermissionTypes) {
            #Get Group Members
            if ($PermissionType -eq 'SharePointGroup') {
                $GroupMembers = Get-PnPGroupMembers -Identity $RoleAssignment.Member            
            }
            else {
                $GroupMembers = $null
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

            If ($ForPermissionRemoval -and $GroupMembers.Count -eq 0) 
            {
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
                $Permissions | Add-Member NoteProperty Group($RoleAssignment.Member.Title.Split('\')[$RoleAssignment.Member.Title.Split('\').Length - 1])
                $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup($Association)
                $Permissions | Add-Member NoteProperty RoleAssignment($RoleAssignment)
                $Permissions | Add-Member NoteProperty User($User.Title.Split('\')[$User.Title.Split('\').Length - 1])
                $Permissions | Add-Member NoteProperty LoginName ($User.LoginName)
                $Permissions | Add-Member NoteProperty Type($PermissionType)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                $Permissions | Add-Member NoteProperty RoleDefinitionBindings($RoleAssignment.RoleDefinitionBindings)
                $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                $PermissionCollection += $Permissions
            }
        }
    }
    return $PermissionCollection
}
