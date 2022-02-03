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
        $MUSourceURL = -Join($SourceURL.Split('//')[0],'//')
        $SourceURL = $SourceURL.Replace($MUSourceURL, '')        
        #Trim and Drop trailing slash
        $SourceURL = $SourceURL.TrimEnd()
        If ($SourceURL -match '/$') { $SourceURL = $SourceURL.Substring(0, $SourceURL.Length - 1) }
        $MUListURL = ""
        $Segments = $sourceurl.Split('/')
        $Segments[1..($Segments.Length)] | ForEach-Object { $MUListURL += -Join ('/', $_) }
        $Segments[0..2] | ForEach-Object { $MUSourceRoot += -Join ('/', $_) }
        $MUSourceRoot = -join($MUSourceURL,'/', $MUSourceRoot)
        #Extract List Root . Validate is Lists is 
        $Offset = 1
        if ($Segments[($Segments.Length - 1)] -in $Settings.SourceURLIgnoreSections) { $Offset++ }
        $MUListitle = $MUListUrl.Split('/')[$MUListUrl.Split('/').Length - 1]
        For($i = 0; $i -lt $Segments.Length-1; $i++){
            $MUSourceURL = -join ($MUSourceURL, $Segments[$i],'/')
        }
        #remove ignores 
        ForEach ($Ignore in  $Settings.SourceURLIgnoreSections) {
            $MUSourceURL = $MUSourceURL.Replace($Ignore, "")
            #Drop trailing slash
            If ($MUSourceURL -match '/$') { $MUSourceURL = $MUSourceURL.Substring(0, $MUSourceURL.Length - 1) }
        }
        return $MUSourceRoot, $MUSourceURL, $MUListURL, $MUListitle
    }
    else {
        throw 'ConvertTo-RJListURL called with incomplete http url'
    }
}