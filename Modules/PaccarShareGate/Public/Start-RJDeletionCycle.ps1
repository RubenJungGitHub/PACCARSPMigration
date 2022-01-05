# Starts deletion scan for  libraryMU  Status notfound nextaction delete
# When all MU;s are deleted, all remaining MU items to be deleted will also be processed.
# this function needs to be checked ???

function Start-RJDeletionCycle {
    [CmdletBinding()]
    param( 
        [PSCustomObject[]]$DeleteMUTargetURLS
    )

    # this is the migration script which will be run in Powershell 5.1 in a background job.   
    # get all  migration Units and/or items to be deleted 

    #Region Delete MU's
    ForEach ($DeleteURL in $DeleteMUTargetURLS ) {
        $DeleteUrls = -Join ($DeleteURLS, '''', $DeleteURL.SubItems[2].Text, '''', ',') 
    }
    $DeleteUrls = $DeleteUrls.Substring(0, $DeleteUrls.Length - 1)
    $Sql = @"
    SELECT   *
FROM [PACCARSQLO365].[dbo].[MigrationUnits]
Where DestinationURL In ($DeleteURLS)
Order By DestinationURL
"@

    $RemoveMUS = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Query $Sql | Resolve-MtHMUClass

    foreach ($RemoveMU in $RemoveMUs) {

        #Check if list really really is non existant prior to removal  
        #To do : What if Site is deleted completely. Do we update all site lists to "Not found"?    
        if ($Connection.URL -ne $RemoveMU.DestinationURL) {
            $Connection = Connect-MtHSharePoint -URL $RemoveMU.DestinationURL
        }
        #Connection failed. Unable to check
        #Check if list can be found. If existant no exception  : No deletion 
        $List = Get-PnPList -Identity $RemoveMU.ListTitle 
        if ($null -eq $List) {
            Write-Host "$($RemoveMU.ListTitle) not found in $($RemoveMU.DestinationURL) . Try with prefix $($RemoveMU.DuplicateTargetLibPrefix)" -ForegroundColor Yellow
            $ListWithPrefix = -Join ($RemoveMU.ListTitle, $RemoveMU.DuplicateTargetLibPrefix) 
            $List = Get-PnPList -Identity $ListWithPrefix
        }
        If ($Null -ne $Connection -and $null -ne $List) {
            #remove list 
            $result = Remove-RJLibraryMU -MigrationItem $RemoveMU
            if ($true -eq $Result )
            { Write-Host  "$($List.Title) removed from  $($RemoveMU.DestinationURL)" -ForegroundColor green }
            else {
                { Write-Host  "Failed to remove $($List.Title)  from  $($RemoveMU.DestinationURL)" -ForegroundColor red }
            }
        }
    }
}