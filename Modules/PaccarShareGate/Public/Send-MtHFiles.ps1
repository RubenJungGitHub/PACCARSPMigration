# copies all files from the local folder $FilePath (full path) to the $Library (full http path) in Office 365/SharePoint, 1 subfolder level deep
# If $Files is defined it will only upload these files
# it expects that the library in SharePoint is already created.
# this function should be checked ???

function Send-MtHFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$SourceURL,
        [Parameter(Mandatory = $True)]
        [String]$Library,
        [Parameter(Mandatory = $True)]
        [String]$FilePath,
        [Parameter(Mandatory = $False)]
        [PSCustomObject]$Files = $null
    )
    if ($null -eq $Files) {
        $files = @(Get-ChildItem $FilePath -File -Depth 1)
    }
    $MigrationURL = ForEach-Object {$settings.Current.MigrationURLS} | Where-Object { $SourceURL -match $_.SourceTenantDomain } | Select-Object -first 1 
    # if the library doesn't exist create it.
    if ($settings.current.SPVersion -eq 'SharePointOnline') {
        # RootFolder.ServerRelativeUrl is including the "/sites/demo/"rel URL for SPOnline
        $RelLibrary = ConvertTo-MtHHttpRelPath -sourceurl  $MigrationURL.SourceTenantDomain -path $Library -webapp -startingslash
    }
    else {
        # RootFolder.ServerRelativeUrl is excluding the "/sites/demo/"rel URL for SP2013 (I thought but seems not to be)
        $RelLibrary = ConvertTo-MtHHttpRelPath  -sourceurl  $MigrationURL.SourceTenantDomain -path $Library -webapp -startingslash
    }
    $listname = $library.split('/')[-1] #listname is the last part of the path
    $listnames = Get-PnPList
    if ($RelLibrary -notin $listnames.RootFolder.ServerRelativeUrl) {
        # RootFolder.ServerRelativeUrl is including the "/sites/demo/"rel URL"
        New-PnPList -Title $Listname -Template DocumentLibrary
    }
    Write-Verbose "Uploading $($files.count) files"
    foreach ($file in $files) {
        ### check if this file is in a subfolder
        if ($filepath -ne $file.directory.fullname) {
            ### calculate the subfolder
            $relpath = $Library + '/' + $file.FullName.SubString($FilePath.Length + 1).replace('\', '/')
            if ($null -eq (Get-PnPFolder -Url $relpath -ErrorAction SilentlyContinue)) {
                Add-PnPFolder -Name $file.PSParentPath.SubString($FilePath.Length + 39) -Folder $Library
            }
        }
        else {
            $relpath = ConvertTo-MtHHttpRelPath -sourceurl  $MigrationURL.SourceTenantDomain -path $Library
        }
        $result = Add-PnPFile -Path $file.FullName -Folder $relpath # assigned to var, because of possible PnP issues
    }
}