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
        $SourceURL = $SourceURL.Replace('https://','')        
        $SourceURL = $SourceURL.Replace('http://','')        
        #Drop trailing slash
        If ($SourceURL -match '/$') {$SourceURL = $SourceURL.Substring(0, $SourceURL.Length-1)}
        $MUSourceURL = ""
        $MUListURL = ""
        $Segments = $sourceurl.Split('/')
        $Segments[1..($Segments.Length)] | ForEach-Object { $MUListURL += -Join ('/', $_) }
        #Extract List Root . Validate is Lists is 
        $Offset = 1
        if ($Segments[($Segments.Length - 1)] -in $Settings.SourceURLIgnoreSections) {$Offset++}
        #$Segments[0..($Segments.Length - $Offset)] | ForEach-Object { $MUSourceURL += -Join ($_, '/') } 
        #$MUSourceURL = $MUSourceURL.Substring(0,$MUSourceURL.Length-1)
        $MUListitle = $MUListUrl.Split('/')[$MUListUrl.Split('/').Length-1]
        $MUSourceURL = -join('https://', $SourceURL.Replace(-Join('/', $MUListitle), ''))
        #remove ignores 
        ForEach($Ignore in  $Settings.SourceURLIgnoreSections)
            {$MUSourceURL= $MUSourceURL.Replace($Ignore,"")
            #Drop trailing slash
            If ($MUSourceURL -match '/$') {$MUSourceURL = $MUSourceURL.Substring(0, $MUSourceURL.Length-1)}
        }
        
        return $MUSourceURL, $MUListURL, $MUListitle
    }
    else {
        throw 'ConvertTo-RJListURL called with incomplete http url'
    }
}