# Creates a new random Lorem Ipsum string with the specified characteristics, no unit test

function New-LoremIpsum {
    [CmdletBinding()]
    param([int]$size)

    $words = @("lorem", "ipsum", "dolor", "sit", "amet", "consectetuer",
        "adipiscing", "elit", "sed", "diam", "nonummy", "nibh", "euismod",
        "tincidunt", "ut", "laoreet", "dolore", "magna", "aliquam", "erat")

    $totalsize = 0
    $sentences =  [System.Collections.Generic.List[String]]::new()
    $content = ""
    foreach($i in 0..25) {
        $SentenceSize = 0
        $result = New-Object System.Text.StringBuilder
        do {
            if ($SentenceSize -gt 0) { $result.Append(" ") | out-null }
            $AppendWord = $words[(Get-Random -Minimum 0 -Maximum $words.Length)]
            $result.Append($AppendWord) | out-null
            $SentenceSize += $AppendWord.length
        }
        while ($SentenceSize -lt 95)
        $result.Append(". ") | out-null
        $result.Append("`r`n") | out-null
        $sentences.add($result.toString())
    }
    do {
        $i = (get-Random -Minimum 0 -Maximum 25)
        $content +=  $sentences[$i]
        $totalsize += $sentences[$i].length
    }
    while ($totalsize -lt $size)
    return $content
}