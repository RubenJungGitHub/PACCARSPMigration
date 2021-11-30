# returns the current git main directory (without ending \), no test
function Get-MtHGitDirectory {
    [CmdletBinding()]
    param ( 
        [Parameter()][switch]$Error   
    )
    try {
        $dir = (git rev-parse --git-dir)
        if ($dir -in @('.git', '')) {
            $dir = (Get-Location).Path
        }
        else {
            $dir = Split-Path $dir -Parent 
        }
    }
    catch {
        if ($Error) {
            Throw "$(Get-Location) has No Git Library"
        }
        else {
            Write-Warning "$(Get-Location) has No Git Library"
            $dir = Get-Location
        }
    }
    return $dir
}