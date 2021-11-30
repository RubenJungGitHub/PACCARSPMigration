# convert rel path to abs path, test included
function ConvertTo-MtHHttpAbsPath {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true)][String]$SourceURL,
        [Parameter(Mandatory = $true)][String]$path
    )
    if ($path[0] -eq '/') {
        $MigrationURL = ForEach-Object {$settings.Current.MigrationURLS} | Where-Object { $SourceURL -match $_.SourceTenantDomain } | Select-Object -first 1 
        $path = "https://" + $MigrationURL.SourceTenantDomain + $path
    }

    if ($path -notlike "https://" + '*') {
        $path = "https://" + $path
    }
    $newpath = [system.Uri] $path
    if (! $newpath.IsAbsoluteUri) {
        throw 'ConvertTo-MthHttpAbsPath called with not valid relative url'
    }
    return $path
}