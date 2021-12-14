# general connect to sharepoint with login type and optional password defined in $global:settings, No test
function Connect-MtHSharePoint {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)] [string] $URL,
        [switch]$returnconnection
    )
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $Params = @{
        Url = $URL
    }
    if ($settings.current.LoginType -eq 'Token') {
        $params.add('AccessToken', $token)
    }
    elseif ($settings.current.LoginType -eq 'Current') {
        if ($settings.current.SPVersion -ne 'SharePointOnline') {
            $params.Add('CurrentCredentials', $true)
        }
        else {
            $params.Add('Current', $true)  
        }
    }
    elseif ($settings.current.LoginType -eq 'UseWebLogin') {
        $params.Add('UseWebLogin', $true)
    }
    elseif ($settings.current.LoginType -eq 'Interactive') {
        $params.Add('Interactive', $true)
    }
    elseif ($settings.current.LoginType -eq 'Credentials') {
        $securePwd = $settings.current.EncryptedPassword | ConvertTo-SecureString
        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $settings.current.UserName, $securePwd
        $params.add('Credentials', $cred)
    }
    else {
        throw "Error found for the environment: $($settings.Environment)"
    }
    try {
        $Connection
        #$connection = $false
        if ($returnconnection) {
            $connection = Connect-PnPOnline @Params -ErrorAction Stop -ReturnConnection
        }
        else {
            $connection = $false
            Connect-PnPOnline @Params -ErrorAction Stop -ReturnConnection
            $connection = $true
        }
    }
    catch [System.SystemException] {
        $ErrorMessage += $_.Exception.Message + 'on the following  URL:'
        $ErrorMessage += $Url
        Write-Error $ErrorMessage
        return $null
    }
    return $connection
}

