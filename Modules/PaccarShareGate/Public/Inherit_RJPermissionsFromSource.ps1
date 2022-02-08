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
            Write-Host "Breaking permissions for MU '$($dstList.Title)' and clear current permissions" -ForegroundColor cyan
            Set-PnPList -Connection $dstConn -Identity $dstList.ID -BreakRoleInheritance 
            <#if ($Settings.UniquePermissionsFromInheritance) {
                $hasUniquePermissions = Get-PnPProperty -ClientObject $dstList -Property "HasUniqueRoleAssignments"
                if (-Not $hasUniquePermissions) {
                    Write-Host "Breaking permissions for MU '$($dstList.Title)' and clear current permissions" -ForegroundColor cyan
                    Set-PnPList -Connection $dstConn -Identity $dstList.ID -BreakRoleInheritance
                }
            }
            #Drop associated groups
            $DestinationPermissisonCollection = Get-RJListPermissions -List $dstList -ForPermissionRemoval | Where-Object { $_.Group -ne (Get-PnPGroup -Connection $dstConn -AssociatedOwnerGroup).title -and $_.Group -ne (Get-PnPGroup -Connection $dstConn -AssociatedMemberGroup).title -and $_.Group -ne (Get-PnPGroup -Connection $dstConn -AssociatedVisitorGroup).title }
#>
            #Clear permissions on target
            <#      foreach ($permission  in $DestinationPermissisonCollection) { 
                If ($Permission.Group -eq '-') {
                    Set-PnPListPermission -Identity $dstList.Title -User $Permission.User -RemoveRole $Permission.Permissions.Name
                }
                else {
                    Set-PnPListPermission -Identity $dstList.Title -Group $Permission.Group -RemoveRole $Permission.Permissions.Name
                }
            }#>
            #Remove user running the script 
            Set-PnPListPermission -Identity $dstList.Title -User $Settings.Current.UserName  -RemoveRole 'Full Control' -ErrorAction SilentlyContinue
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
                if ($Settings.CreateUsersAndGroups) {
                    #Add  non existant target objects 
                    Write-Host "Processing $($permgroup.Name)" -f green
                    If ($permgroup.group[0].Type -eq 'user') {
                        #New Users 
                        foreach ($Permission in $permgroup.group) {
                            try {
                                if ((Get-PnPUser -Connection $dstConn | Where-Object { $_.Title -eq $Permission.User })) {
                                    New-PnPUser -Connection $dstConn -LoginName $Permission.User
                                }
                                #Grant user permissions on Site level
                                Set-PnPWebPermission -User $Permission.User -AddRole $Permission.Permissions.Name -ErrorAction Stop
                                Set-PnPListPermission -Identity $dstList.Title -User $Permission.User -AddRole $Permission.Permissions.Name -ErrorAction Stop
                            }
                            catch {
                                Write-Host "$($_.ErrorDetails)" -BackgroundColor red
                            }
                        }
                    }
                    elseif ($permgroup.group[0].Type -eq 'SecurityGroup') {
                        #New securitygroup
                        foreach ($Permission in $permgroup.Group) {
                            try {
                                If (-Not (Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -eq $Permission.User })) {
                                    New-PnPGroup -Connection $dstConn -Title $Permission.User
                                }
                                if ($Permission.Group -eq '-') {
                                    #Dont map Group users. ONly actual AD users
                                    Set-PnPWebPermission -User $Permission.User -AddRole $Permission.Permissions.Name  -ErrorAction Stop
                                    Set-PnPListPermission -Identity $dstList.Title -Group ($Permission.User.ToUpper()) -AddRole $Permission.Permissions.Name  -ErrorAction Stop
                                }
                            }
                            catch {
                                Write-Host "$($_.ErrorDetails)" -BackgroundColor red
                            }
                        }
                    }
                    else {
                        #New Sharepointgroup 
                        try {
                            If (-Not (Get-PnPGroup -Connection $dstConn | Where-Object { $_.Title -eq $permgroup.group[0].group })) {
                                New-PnPGroup -Connection $dstConn -Title  $permgroup.group[0].group
                            }
                            $Permissions = ($PermissionCollection | Where-Object { $_.Group -eq $permgroup.group[0].group })[0].Permissions.Name
                            Set-PnPWebPermission -Group $permgroup.group[0].group -AddRole  $Permissions  -ErrorAction Stop
                            #Add group members
                        }
                        catch {
                            Write-Host "$($_.ErrorDetails)" -BackgroundColor red
                        }
                        ForEach ($User in $PermGroup.Group) {
                            try {
                                Add-PnPUserToGroup -LoginName $User.User -Connection $dstConn -Identity $User.group  -ErrorAction Stop
                            }
                            catch {
                                Write-Host "$($_.ErrorDetails)" -BackgroundColor red
                            }
                        }
                        try {
                            Set-PnPListPermission -Identity $dstList.Title -Group $User.group -AddRole $Permissions  -ErrorAction Stop
                        }
                        catch {
                            Write-Host "$($_.ErrorDetails)" -BackgroundColor red
                        }
                    }
                }
            }
        }
    }
}