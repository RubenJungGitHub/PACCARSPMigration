# Create testdata : check if the TempDocs library (locally stored) is already filled, if not fill it.
function New-MtHTestData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][int]$Number,
        [Parameter(Mandatory = $true)][int]$MaxFileSize,
        [switch]$RandomSize
    )

    if (!(Test-Path variable:global:settings)) {
        Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json" -test
    }
    $Count = 0
    if (Test-Path -Path $settings.FilePath.TempDocs) {
        $Count = (Get-ChildItem -Path $settings.FilePath.TempDocs -File).count
    }
    $FileSize = $MaxFileSize
    if ($Count -lt $Number) {
        # create a local library with 25 ($number) random files and fill the SP demo library
        for ($i = $count; ($i -lt $Number); $i++) {
            if ($RandomSize) {
                $FileSize = Get-Random -Minimum 5000 -Maximum $MaxFileSize
            }
            New-RandomFile -DocsPath $settings.FilePath.TempDocs -WordsFile  $settings.FilePath.WordsFile  -Size $FileSize
            Write-Verbose "create random file $i"
        }
        Write-Verbose "All Random Files created and available in: $($settings.FilePath.TempDocs)"
    }
    else {
        Write-Verbose "All Random Files already available in: $($settings.FilePath.TempDocs)"
    }
}