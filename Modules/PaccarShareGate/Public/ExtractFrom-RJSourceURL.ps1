#conv rel path to abs path, test included
function ExtractFrom-RJSourceURL {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true)][String]$sourceurl,
        [switch]$startingslash
    )
    #Select first item from array (in case  domain is used multiple times)
    $ExtractURL = [system.Uri] $SourceURL
    if ($ExtractURL.IsAbsoluteUri) {
        $MUSourceURL = ""
        $MUListURL = ""
        $Segments = $sourceurl.Split('/')
        $Segments[3..($Segments.Length - 2)] | ForEach-Object { $MUListURL += -Join ('/', $_) }
        #Extract List Root . Validate is Lists is 
        $Offset = 3
        if ($Segments[($Segments.Length - 3)] -in $Settings.SourceURLIgnoreSections) {$Offset =4}
        $Segments[0..($Segments.Length - $Offset)] | ForEach-Object { $MUSourceURL += -Join ($_, '/') } 
        $MUSourceURL = $MUSourceURL.Substring(0,$MUSourceURL.Length-1)
        return $MUSourceURL, $MUListURL
    }
    else {
        throw 'ConvertTo-RJListURL called with incomplete http url'
    }
}