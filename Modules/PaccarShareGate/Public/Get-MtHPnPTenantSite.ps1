# this functions returns the sitecollections in a tenant or webapp, no unit test
function Get-MtHPnPTenantSite {
    [CmdletBinding()]
    param()
    $sites = [System.Collections.Generic.List[PSCustomObject]]::new()
    if ($settings.current.SPVersion -eq 'SharePointOnline') {
        if ($settings.current.SPVersion -ne 'PnP.Powershell') {
            # if SharePointPnPPowerShell2013 is used, the demosite is returned, because it doesn't have the Get-PnPTenantSite function        
            foreach ($MigrationURL in $Settings.Current.MigrationURLS) {
                foreach ($DemoSite in $MigrationURL.DemoSite) {
                    $site = [PSCustomObject]@{
                        Url = ConvertTo-MtHHttpAbsPath -SourceURL $MigrationURL.SourceTenantDomain -path $DemoSite
                    }
                    $sites.add($site)
                }
            }
        }
        # PnPTenantSite is only a command for PnP.Powershell
        else {
            return Get-PnPTenantSite
        }
    }
    else {
        foreach ($MigrationURL in $Settings.Current.MigrationURLS) {
            $parameters = @{
                ScriptBlock    = {
                    Add-PSSnapin Microsoft.SharePoint.PowerShell
                    $webApp = Get-SPWebApplication $args[0] 
                    $sites = $webApp.Sites | Select-Object -Property Url #, LastContentModifiedDate
                    return $sites
                }
                ComputerName   = $settings.Current.SharePointComputerName
                Credential     = $global:SPScheduledTaskCred
                ArgumentList   = $MigrationURL.WebAppUrl
                Authentication = 'CredSSP'
            }
            Invoke-Command @parameters | Where-Object { $_ -like "*$($MigrationURL.SourceTenantDomain)*" } | ForEach-Object {
                $Sites.Add($_)
            }
        }
    }
    return $sites
}