# deletes files from $Library (full http path) which where an upload from local folder $FilePath (full path), 1 subfolder level deep
# If $Files is defined it will only delete these files
# this function needs to be checked ???
#RJ : Function checked. 

function Remove-MtHFiles 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$SourceURL,
        [Parameter(Mandatory = $True)]
        [String]$Library,
        [Parameter(Mandatory = $True)]
        [String]$FilePath,
        [Parameter(Mandatory = $False)]
        [PSCustomObject]$Files = $null,
        [switch]$RemoveFromSource
    )
    # if files are not defined, delete them all
    if ($null -eq $Files)
    {
        $files = @(Get-ChildItem $FilePath -File -Depth 1)
    }
    Write-Output "Deleting $($files.Length) files"
    #if no specific files are defined, all files in the collection will be deleted from the target
    
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # Removal of files can also take place in the destination during Deletion cycle
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    $MigrationURL = ForEach-Object {$settings.Current.MigrationURLS} | Where-Object { $SourceURL -match $_.SourceTenantDomain } | Select-Object -first 1 
    $script:removecontainer =$MigrationURL.DestinationTenantDomain
    if($RemoveFromSource){$script:removecontainer =$MigrationURL.SourceTenantDomain}


    foreach ($file in $files) 
    {
        ### check if this file is in a subfolder
        ### RJ : Not sure why this check is added. The file is uploaded to the List.
        #if ($filepath -ne $file.directory.fullname) {
        ### calculate the subfolder
        $script:relpath = -join ($Library , '/' , $file.FullName.SubString($FilePath.Length + 1).replace('\', '/'))
        #$result = Remove-PnPFile -SiteRelativeUrl $relpath -Force # assigned to var, because of possible PnP issues
        write-verbose "remove file: $relpath"
        $result = Remove-PnPFile -ServerRelativeUrl (ConvertTo-MtHHttpRelPath -sourceurl $script:removecontainer -path $relpath -webapp -startingslash)  -Force 
    }
}