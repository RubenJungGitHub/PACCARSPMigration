# a random file is generated in the TempDocs library of length $size bytes
function New-RandomFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][int]$Size,
        [Parameter(Mandatory = $true)][string]$WordsFile,
        [Parameter(Mandatory = $true)][string]$DocsPath
    )
    ## create random filename ##
    
    # select a word in a wordsfile csv from column English
    $RandomWord = (Import-Csv -Path $WordsFile -Delimiter ';').English.trim() | Get-Random
    # add a random powershell verb
    $Randomverb = (Get-Verb).verb | Get-Random
    # add an extention from this array
    $RandomExtension = ('txt', 'log') | Get-Random
    # create the full filepath
    $RandomFilePath = $DocsPath + '\' + $RandomWord + '-' + $randomVerb + '.' + $RandomExtension

    ## Check if Unique, otherwise add the string 'new' to the basename
    while (Test-Path $RandomFilePath) {
        $RandomFilePath = ($RandomFilePath.replace('.' + $RandomExtension, 'New')) + '.' + $RandomExtension
    }
    
    ## Fillup the file
    $BlockSize = 10000
    $filecontent = New-LoremIpsum -size 10000
    do {
        if ($size -gt $BlockSize) { 
            $size -= $BlockSize
        }
        else {
            $filecontent = New-LoremIpsum -size $size
            $size = 0
        }
        $filecontent | Out-File $RandomFilePath -Append -Encoding UTF8
    }
    while ($size -gt 0)

    ## return the filename
    return $RandomFilePath
}
