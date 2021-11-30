# function to calculate the destination url of a site or sitecollection from the source sitecollection url, test included

function ConvertTo-MtHDestinationUrl {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true)][String]$SourceUrl
    )
    $newpath = [system.Uri] $SourceUrl
    #Select first item from array (in case  domain is used multiple times)
    $MigrationURL = ForEach-Object {$settings.Current.MigrationURLS} | Where-Object { $SourceURL -match $_.SourceTenantDomain } | Select-Object -first 1 
    if ($newpath.IsAbsoluteUri) {
        if ($newpath.Authority -ne $MigrationURL.SourceTenantDomain ) {
            throw 'SourceUrl not complying to SourceTenantDomain in settings'
        }
        $len = $newpath.Segments.Length - 1
        if ($len -ge 2) {
            if ($newpath.segments[1].replace('/', '') -notin $MigrationURL.ManagedPath) {
                throw 'SourceUrl not complying to managed path in settings'
            }
            $destinationUrl = 'https://' + $MigrationURL.DestinationTenantDomain + $($newpath.Segments[0, 1] -join '') + $MigrationURL.SitePrefix + $($newpath.Segments[2..$len] -join '')
        }
        else {
            $destinationUrl = 'https://' + $MigrationURL.DestinationTenantDomain + '/' + $MigrationURL.ManagedPath[0] + '/' + $MigrationURL.SitePrefix + 'root'
        }
    }
    else {
        throw 'ConvertTo-MtHDestinationUrl called with incomplete http url'
    }
    return $DestinationUrl
}