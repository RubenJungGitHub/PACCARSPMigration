Import-Module Sharegate
Start-MtHLocalPowerShell -settingfile -join($settings.FilePath.SettingsFile,'\settings.json')
$csvFile = "$($settings.filepath.mappings)\users.csv"
$table = Import-CSV $csvFile -Delimiter ";"
$mappingSettings = New-MappingSettings
foreach ($row in $table) {
    $results = Set-UserAndGroupMapping -MappingSettings $mappingSettings -Source $row.SourceValue -Destination $row.DestinationValue
    $row.sourcevalue
}
Export-UserAndGroupMapping -MappingSettings $mappingSettings -Path "$($settings.filepath.mappings)\SGUserMappingfile"