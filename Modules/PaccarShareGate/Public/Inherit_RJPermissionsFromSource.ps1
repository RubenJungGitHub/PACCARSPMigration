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
    $scrList = Get-PnPList -Identity $scrListTitle   -Connection $scrConn -Includes RoleAssignments
    $dstList = Get-PnPList -Identity $dstListTitle   -Connection $dstConn -Includes RoleAssignments
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

    $RoleAssignments = $scrList.RoleAssignments
    $PermissionCollection = @()
    Foreach ($RoleAssignment in $RoleAssignments) {
        #Get the Permission Levels assigned and Member
        Get-PnPProperty -ClientObject $roleAssignment -Property RoleDefinitionBindings, Member
     
        #Get the Principal Type: User, SP Group, AD Group
        $PermissionType = $RoleAssignment.Member.PrincipalType
        #Get all permission levels assigned (Excluding:Limited Access)
        $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select-object -property Name | Where-Object {$_.Name -ne 'Limited Access'}
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
                    $scrSPGroups[0].Title {$Association = 'Visitor' }
                    $scrSPGroups[1].Title {$Association = 'Member'}
                    $scrSPGroups[2].Title {$Association = 'Owner'}
                }
                $Permissions = New-Object PSObject
                $Permissions | Add-Member NoteProperty Group($RoleAssignment.Member.Title)
                $Permissions | Add-Member NoteProperty AssociatedSiteSPGroup($Association)
                $Permissions | Add-Member NoteProperty User($User.Title)
                $Permissions | Add-Member NoteProperty Type($PermissionType)
                $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
                $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
                $PermissionCollection += $Permissions
            }
        }
  <#      Else {
            #Add the Data to Object
            $Permissions = New-Object PSObject
            $Permissions | Add-Member NoteProperty User($RoleAssignment.Member.Title)
            $Permissions | Add-Member NoteProperty Type($PermissionType)
            $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
            $Permissions | Add-Member NoteProperty GrantedThrough("Direct Permissions")
            $PermissionCollection += $Permissions
        }#>
    }
    $a = 1
    #    $PermissionCollection
    #    $PermissionCollection | Export-CSV $ReportOutput -NoTypeInformation
    #    Write-host -f Green "Permission Report Generated Successfully!"
    #>
    
    #Read more: https://www.sharepointdiary.com/2019/02/sharepoint-online-pnp-powershell-to-export-document-library-permissions.html#ixzz7JeeSW8UW

    #Not sure if this is required
    #$scrSecGroups= Get-PnPUser | Were-Object {$_.Principaltype -eq 'SecurityGroup'}
    <#
    foreach ($scrGroup in $scrSPGroups) {
        $scrGroupMembers = Get-PnPGroupMembers -Identity $scrGroup
        Write-Host "$($scrGroup.Title) detected :  $($ScrGroupMembers.Count) members" -ForegroundColor Yellow
        foreach ($scrGroupMember in $ScrGroupMembers) {
            Write-Host "$($scrGroupMember.Title)" -f cyan
            #Check Associated groups only 
            if ($settings.AssociatedGroupsOnly) {
                $a = 1

            }
            #Find associated destination group 
            $DestGroup = $dstSPGroups | Where-Object { $_.Title }
        }
    }
#>

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