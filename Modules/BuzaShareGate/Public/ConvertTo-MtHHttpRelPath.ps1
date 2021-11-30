#conv rel path to abs path, test included
function ConvertTo-MtHHttpRelPath {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true)][String]$sourceurl,
        [Parameter(Mandatory = $true)][String]$path,
        [switch]$webapp,
        [switch]$startingslash
    )
    #Select first item from array (in case  domain is used multiple times)
    $MigrationURL = ForEach-Object {$settings.Current.MigrationURLS} | Where-Object { $SourceURL -match $_.SourceTenantDomain } | Select-Object -first 1 
    if ($path[0] -eq '/') {
        $path = "https://" + $MigrationURL.SourceTenantDomain + $path
    }
    $newpath = [system.Uri] $path
    if ($newpath.IsAbsoluteUri) {
        
        $startsegment = 1 #relative to the webapp

        if (!$webapp -and ($newpath.segments.length -ge 3)) {
            if ($newpath.segments[1].replace('/', '') -in $MigrationURL.ManagedPath) {
                $startsegment = 3
            }
        }

        $returnvalue = $newpath.segments[$startsegment..$($newpath.segments.length - 1)] -join ''
        if ($startingslash) {
            $returnvalue = "/" + $returnvalue
        }
        return $returnvalue
    }
    else {
        throw 'ConvertTo-MthHttpRelPath called with incomplete http url'
    }
}