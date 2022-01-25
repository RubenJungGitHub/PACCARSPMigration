#Parameters
$SiteURL = "https://paccar.sharepoint.com/sites/DAF-OPS-TA-Document-Site"
$ParentListName = "Control PlanPE-Area1-quality"
$ChildListName = "LijndeelPE_Area1_quality"
#Field display names - Case sensitive!
$ParentFieldTitle = "Lijndeel"
$ChildFieldTitle = "Title"
 
#Connect to SharePoint Online
Connect-PnPOnline $SiteURL -UseWebLogin
#Get Parent List, ParentField  & Child field
$ParentList = Get-PnPList -Identity $ParentListName
$ParentField  = Get-PnPField -List $ParentList -Identity $ParentFieldTitle
$ChildField = Get-PnPField -List $ChildListName -Identity $ChildFieldTitle

#Get the parentField Schema  XML
[Xml]$ParentFieldSchema = $ParentField.SchemaXml
#Get the ChildField Schema XML
[Xml]$ChildFieldSchema = $ChildField.SchemaXml

$ChildFieldSchema.Field.Attributes["List"].'#text' = "{$($ParentList.Id.Guid)}"
$ChildFieldSchema.field.Attributes["ShowField"].'#text' = $ParentFieldTitle

$ChildField.SchemaXml = $Schema.OuterXml
$ChildField.UpdateAndPushChanges($true)
Invoke-PnPQuery


#Update Field ChildFieldSchema with New Parent List and Field
#$ParentFieldSchema.Field.Attributes["List"].Value = "{$($ChildField.Id.Guid)}"
#$ParentFieldSchema.field.Attributes["ShowField"].Value = $ChildField



#Invoke-PnPQuery
#Set-PnPField -Identity $ParentField -Values @{SchemaXml=$ParentFieldSchema.OuterXml}


#Read more: https://www.sharepointdiary.com/2019/04/sharepoint-online-fix-lookup-field-using-powershell.html#ixzz7J0TushS4