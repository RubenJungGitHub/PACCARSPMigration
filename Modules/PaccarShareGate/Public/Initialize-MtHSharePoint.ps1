# This function needs an update about writing passwords to the settingfile
# Passwords/credentials (username/password combinations) need a separate section in settings. 
# in the settings.environments there are the matching usernames
# next there will be a section for pester tests, with overwritten settings when doing pester testing (with/without Mock)

function Initialize-MtHSharePoint {
    [CmdletBinding()]
    param()

    # if we use credentials, we need to put them in a global variable for later reuse. We also put them encrypted in the settings file.
    if ($settings.Current.LoginType -eq 'Credentials') {
        try {
            # if the password is encrypted in the settingsfile, this should be OK
            $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString -ErrorAction Stop
            $global:cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserName, $securePwd
        }
        catch {
            # else we are requesting the password from the user
            $global:cred = Get-Credential -UserName $settings.current.UserName -Message "Enter your Credentials for the user: $($settings.current.UserName)"
            $encryptedPassword = $cred.Password | ConvertFrom-SecureString
            $settings.current | Add-Member -NotePropertyName EncryptedPassword -NotePropertyValue $encryptedPassword
            $Settings | Select-Object -Property * -ExcludeProperty current, timezone, SQLdetails | ConvertTo-Json -Depth 5 | Set-Content $settings.FilePath.SettingsFile
        }
    }

    # if the SharePoint SPScheduledTaskAccountName is added to the properties, we need to request the password and add that to the settings file
    if ('SPScheduledTaskAccountName' -in $settings.Current.PSObject.Properties.Name) {
        try {
            # if the password is encrypted in the settingsfile, this should be OK
            $securePwd = $settings.current.SPScheduledTaskEncryptedPassword | ConvertTo-SecureString -ErrorAction Stop
            $global:SPScheduledTaskCred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.SPScheduledTaskAccountName, $securePwd
        }
        catch {
            # else we are requesting the password from the user
            $global:SPScheduledTaskCred = Get-Credential -UserName $settings.current.SPScheduledTaskAccountName -Message "Enter the Credentials for the user : $($settings.current.SPScheduledTaskAccountName)"
            $encryptedPassword = $SPScheduledTaskCred.Password | ConvertFrom-SecureString
            $settings.current | Add-Member -NotePropertyName SPScheduledTaskEncryptedPassword -NotePropertyValue $encryptedPassword -Force
            $Settings | Select-Object -Property * -ExcludeProperty current, timezone, SQLDetails | ConvertTo-Json -Depth 5 | Set-Content $settings.FilePath.SettingFile
        }
    }

    # we can also pick them from the Windows credential manager (not used here)
    if ($settings.current.LoginType -eq 'CredentialManager') {
        $global:cred = Get-PnPStoredCredential -Name $settings.current.CMName
    }

    # now connect to SharePoint

    # if you are using a token, you need to login to AAD to get the token (not used here)
    if ($settings.current.LoginType -eq 'Token') {
        Connect-PnPOnline -PnPO365ManagementShell -Url "https://$($settings.current.MigrationURLS[0].SourceTenantDomain)" -LaunchBrowser -ErrorAction Stop
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments')]
        $global:token = Get-PnPAccessToken
    }

    # if we connect to online we need to connect to the admin URL first
    if ($settings.current.SPVersion -eq 'SharePointOnline') {
        #Initially connect to the first URL from the array of sitecollections in the settingsfile
        $CONNECTURL = -Join("https://",$settings.current.MigrationURLS[0].SourceTenantDomain,'/',$settings.current.MigrationURLS[0].ManagedPath[0],$settings.current.MigrationURLS[0].ConnectURL)
        #$URL = "https://" + $settings.current.MigrationURLS[0].SourceTenantDomain
        #$adminURL = "$($URL.Substring(0, $URL.IndexOf('.sharepoint.com')))-admin.sharepoint.com"
       # Connect-MtHSharePoint -URL $adminURL -ErrorAction Stop
        #Connect-MtHSharePoint -URL $URL -ErrorAction Stop
        Connect-MtHSharePoint -URL $CONNECTURL -ErrorAction Stop
    }
    else {
        #Connect to the source site collection should go well
        Connect-MtHSharePoint -URL "https://$($settings.current.MigrationURLS[0].SourceTenantDomain)" -ErrorAction Stop
    }
    Write-Verbose "Connected to Environment: $($settings.current.Name) on $($settings.current.SPVersion) with URL: $($settings.current.MigrationURLS[0].SourceTenantDomain)"
}
