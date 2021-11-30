function Invoke-MtHSQLQueryFile {
    [CmdletBinding()]
    Param(
        [parameter(mandatory = $true)] [String] $FileName
    )
    $sqlquery = get-content -Raw -Path $FileName

     $result = Invoke-Sqlcmd -ServerInstance ($Settings.SQLDetails.Instance) -Database ($Settings.SQLDetails.Database) -Query $sqlquery
     Return $result
}
