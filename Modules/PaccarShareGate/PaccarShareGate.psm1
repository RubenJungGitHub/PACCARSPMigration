#Get public and private function definition files to load
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

#Dot source the files
Foreach ($import in @($Public + $Private)) {
    Try {
          Write-Host "Import module : " $Import.Name 
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Export only the Public functions ($Public.BaseName) for the (WIP) modules
Export-ModuleMember -Function @($Public).BaseName -Verbose