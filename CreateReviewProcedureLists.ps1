# general connect to sharepoint with login type and optional password defined in $global:settings, No test

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
$Params = @{
    Url = 'https://paccar.sharepoint.com/sites/DAF-MS-ASCOM-Site'
}
$params.Add('UseWebLogin', $true)
try {
    $AdminTaskList = "Admin-Tasks"
    $ProcessOwnerTaskList = "ProcessOwner-Tasks"
    
    $AdminStatusFieldChoices = @("Not Started", "In Progress", "Completed")
    $AdminPriorityFieldChoices = @("(1) High", "(2) Normal", "(3) Low")

        
    $ProcessOwnertatusFieldChoices = @("Review", "Actual", "Need Update", "Expired (archive)")

    $connection = Connect-PnPOnline @Params -ErrorAction Stop -ReturnConnection    
    #Remove list if existant 
    Remove-PnPList -Identity $AdminTaskList -force  -ErrorAction SilentlyContinue

    #Create admin task list 
    New-PnPList -Title $AdminTaskList  -Template GenericList  -Connection $Connection
    $List = Get-PnPList -Identity $AdminTaskList

    #Define Status XML choice Field
    #Add status Field to list from XML
    Add-PnPField -List $List -DisplayName "Status" -InternalName "Status" -Type Choice -AddToDefaultView -Choices $AdminStatusFieldChoices -Required | Out-Null
    Set-PnPDefaultColumnValues -List $List -Field "Status" -Value  $AdminStatusFieldChoices[0] | Out-Null

    #Add Priority Field 
    Add-PnPField -List $List -DisplayName "Priority" -InternalName "Priority" -Type Choice -AddToDefaultView -Choices $AdminPriorityFieldChoices -Required | Out-Null

    #Add Procedure Number field 
    Add-PnPField -List $List -DisplayName "RelatedProcID" -InternalName "RelatedProcID" -Type Number -AddToDefaultView -Required | Out-Null

    #Add Assigned to field 
    Add-PnPField -List $List -DisplayName "Assigned To" -InternalName "Assigne To" -Type user -AddToDefaultView  -Required | Out-Null
    #Add description Field 
    Add-PnPField -List $List -DisplayName "Description" -InternalName "Description" -Type Note -AddToDefaultView  -Required | Out-Null
    #Add start date field  (Date only)
    $FieldXML = "<Field Type='DateTime' Name='Start Date' ID='$([GUID]::NewGuid())' DisplayName='Start Date' Required ='TRUE' Format='DateOnly' FriendlyDisplayFormat='Disabled' Viewable='TRUE'></Field>" 
    Add-PnPFieldFromXml -FieldXml $FieldXML -List $List | Out-Null
    #Add Due date field 
    $FieldXML = "<Field Type='DateTime' Name='Due Date' ID='$([GUID]::NewGuid())' DisplayName='Due Date' Required ='TRUE' Format='DateOnly' FriendlyDisplayFormat='Disabled' Viewable='TRUE'></Field>"
    Add-PnPFieldFromXml -FieldXml $FieldXML -List $List | Out-Null
    
    Set-PnPView -List $List  -Identity "All Items" -Fields "Title", "Status", "Priority", "Assigned To", "Description", "Start Date", "Due Date", "RelatedProcID" | out-null

    #Remove list if existant 
    Remove-PnPList -Identity $ProcessOwnerTaskList -force  -ErrorAction SilentlyContinue

    #Create admin task list 
    New-PnPList -Title $ProcessOwnerTaskList  -Template GenericList  -Connection $Connection
    $List = Get-PnPList -Identity $ProcessOwnerTaskList

    #Define Status XML choice Field
    #Add status Field to list from XML
    Add-PnPField -List $List -DisplayName "Status" -InternalName "Status" -Type Choice -AddToDefaultView -Choices $ProcessOwnertatusFieldChoices -Required | Out-Null
    Set-PnPDefaultColumnValues -List $List -Field "Status" -Value  $ProcessOwnertatusFieldChoices[0] | Out-Null

    #Add Priority Field 
    Add-PnPField -List $List -DisplayName "Priority" -InternalName "Priority" -Type Choice -AddToDefaultView -Choices $AdminPriorityFieldChoices -Required | Out-Null

    #Add Procedure Number field 
    Add-PnPField -List $List -DisplayName "RelatedProcID" -InternalName "RelatedProcID" -Type Number -AddToDefaultView -Required | Out-Null

    
    #Add Assigned to field 
    Add-PnPField -List $List -DisplayName "Assigned To" -InternalName "Assigne To" -Type user -AddToDefaultView  -Required | Out-Null
    #Add description Field 
    Add-PnPField -List $List -DisplayName "Description" -InternalName "Description" -Type Note -AddToDefaultView  -Required | Out-Null

    #Add comments Field 
    Add-PnPField -List $List -DisplayName "Comments" -InternalName "Comments" -Type Note -AddToDefaultView  -Required | Out-Null

    #Add start date field  (Date only)
    $FieldXML = "<Field Type='DateTime' Name='Start Date' ID='$([GUID]::NewGuid())' DisplayName='Start Date' Required ='TRUE' Format='DateOnly' FriendlyDisplayFormat='Disabled' Viewable='TRUE'></Field>" 
    Add-PnPFieldFromXml -FieldXml $FieldXML -List $List | Out-Null
    #Add Due date field 
    $FieldXML = "<Field Type='DateTime' Name='Due Date' ID='$([GUID]::NewGuid())' DisplayName='Due Date' Required ='TRUE' Format='DateOnly' FriendlyDisplayFormat='Disabled' Viewable='TRUE'></Field>"
    Add-PnPFieldFromXml -FieldXml $FieldXML -List $List | Out-Null
    Set-PnPView -List $List  -Identity "All Items" -Fields "Title", "Status", "Priority", "Assigned To", "Description","Comments", "Start Date", "Due Date", "RelatedProcID" | out-null




    Write-Host "Lists created " -ForegroundColor Green
}
catch [System.SystemException] {
    $ErrorMessage += $_.Exception.Message + 'on the following  URL:'
    $ErrorMessage += $Url
    Write-Error $ErrorMessage
}
