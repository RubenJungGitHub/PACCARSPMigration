
# I'm not sure why the if statement is useful. just return Errors = 0, could be sufficient ???
function Start-MtHFakeMigration {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] [MigrationUnitClass]$MigrationItem
    )
    if (($migrationItem.NextAction -in @('first', 'delta')) -and ($migrationItem.MUStatus -eq 'fake')) {
        $value = return [PSCustomObject]@{
            Errors = 0
            SessionId = 'None'
        }
    }
    else {
        $value = [PSCustomObject]@{
            Errors = 1
            SessionId = 'None'
        }
    }
    return $value
}
