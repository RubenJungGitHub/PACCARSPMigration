#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -PSEdition Desktop

function install-Local {
    # files are local in d:\beheer\utilities\MSI which should be synced to the offline server: D:\Software\MigZip
    # in https://www.powershellgallery.com/ you can download the nuget packages of powershell modules and put them
    # in d:\beheer\utilities\MSI\Nuget

    # syncing is done by steppingstone.ps1 on the steppingstone
    
    # on the offline machine, the correct packageproviders should be installed.
    # get the overview by running get-packageprovider.
    # this should be giving: Nuget, 3.0.0 and Powershellget 2.2.5
    # if nuget is not correct: download at: https://www.nuget.org/downloads
    # get nugetpackagemanager is here: "D:\Beheer\Software\PaccarShareGate\Nuget\Microsoft.PackageManagement.NuGetProvider-2.8.5.208.dll"
    # this should be copied the offline server in: C:\Program Files\PackageManagement\ProviderAssemblies

    # so run on offline server, with elevated rights(As Admin):
    new-item -Path "c:\program files\PackageManagement" -ItemType Directory
    new-item -Path "c:\program files\PackageManagement\ProviderAssemblies" -ItemType Directory
    copy-item -Path "D:\Software\PaccarShareGate\Nuget\Microsoft.PackageManagement.NuGetProvider-2.8.5.208.dll" -Destination "c:\program files\PackageManagement\ProviderAssemblies"
    Register-PackageSource -Name Nuget.org -Location "D:\Software\PaccarShareGate\Nuget" - Providername Nuget
    Register-PSRepository -Name "Local" -SourceLocation 'D:\Software\PaccarShareGate\Nuget' -InstallationPolicy Trusted
    Set-psrepository -name "Local" -installationpolicy "Trusted"
    Install-Module PackageManagement -Force 
    Install-Module Powershellget -Force
    # Na het herstarten van powershell heb je de juiste versies van de packages
}
function get-installedversions {
    # machines: (via git tag toegevoegd, zodat dit in $totalversion terugkomt)
    # dev-1-0DAV
    # dev-2-
    # acc-1-AS96
    # acc-2-AS98
    # prod-1-PS99

    $totalversion = $(git describe --tags --long) + '-' + $((git log --oneline | Measure-Object -Line).Lines)  
    Write-Host "Software Git Version: $totalversion`r"
    # get-module -listavailable | select-object -Property Name, Version | where-object {$_.name -in ('pester', 'sqlserver', 'SharePointPnPPowerShell2013')}
    Get-Package  | Select-Object -Property Name, Version | Where-Object {
        ($_.name -in ('Git', 'Microsoft Visual Studio Code', 'Azure Data Studio', 'Microsoft PowerBI Desktop (x64)', 'ShareGate Desktop', 'pester', 'sqlserver', 'SharePointPnPPowerShell2013')) -or
        ($_.name -like 'Microsoft .NET') -or ($_.name -like 'SQL*')
    }
    Get-PackageProvider | Select-Object -Property Name, Version | Where-Object { $_.name -in @('Nuget', 'PowershellGet') }
}
function install-artifact {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)][String]$RepoDir = 'C:\Beheer',
        [Parameter(Mandatory = $false)][String[]]$Dirs,
        [Parameter(Mandatory = $false)][String[]]$Packages,
        [Parameter(Mandatory = $false)][String[]]$Extensions,
        [Parameter(Mandatory = $false)][String[]]$repositories,
        [Parameter(Mandatory = $false)][String[]]$ModulePathDirs,
        [Parameter(Mandatory = $false)][String[]]$Modules,
        [Parameter(Mandatory = $false)][String[]]$ScriptDirs,
        [Parameter(Mandatory = $false)][String]$gitname,
        [Parameter(Mandatory = $false)][String]$gitemail,
        [Parameter(Mandatory = $false)][Boolean]$ServerOnline
    )
    # zet de execution policy van de huidige powershell sessie op Bypass, dus unrestricted en ook geen waarschuwingen
    Set-ExecutionPolicy Bypass -Scope Process -Force

    # zet het security protocol op TLS 1.2, nodig voor de volgende webcall
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Write-Output '---------------------------'
    Write-Output 'Start Installation'
    Write-Output '---------------------------'
    if ($ServerOnline) {
        try {
            #check if choco is already installed
            $script:ip = choco list -lo
        }
        catch {
            # if not installed, install it
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            Write-Output 'Chocolatey Installed.....'
        }
    }
    if (!(Test-Path $repodir)) {
        New-Item $repodir -ItemType directory
        Write-Output "repodir: $repodir  created...."
    }
    Set-Location $repodir
    # maak directories aan (git repositories maken de git directories wel aan)
    foreach ($dir in $dirs) {
        if (!(Test-Path $dir)) {
            New-Item $dir -ItemType directory
            Write-Output "dir: $dir  created...."
        }
    }

    # doe de volgende installaties
    if ($ServerOnline) {
        $ip = choco list -lo
        $installedpackages = $ip.split(' ')
        Write-Output '---------------------------'
        Write-Output 'packages already installed'
        Write-Output '---------------------------'
        $ip
        Write-Output '---------------------------'
        Write-Output 'start installing packages'
        Write-Output '---------------------------'
        foreach ($package in $packages) {
            if ($package.toLower() -notin $installedpackages) {
                choco install $package -y
                Write-Output "$package installed........ "
            }
            else {
                Write-Output "$package already installed "
            }
        }
        $ip = choco list -lo
        $installedpackages = $ip.split(' ')
    }
    else {       
        Write-Output '-------------------------'
        Write-Output 'Install Packages Manually'        
        Write-Output '-------------------------'
        Pause
    }

    Write-Output '----------------------------'
    Write-Output 'Refresh environmentvariables'
    Write-Output '----------------------------'

    foreach ($level in 'Machine', 'User') {
        [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
            # For Path variables, append the new values, if they're not already in there
            if ($_.Name -match 'Path$') {
                $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select-Object -Unique) -join ';'
            }
            $_
        } | Set-Content -Path { "Env:$($_.Name)" }
    }

    #installeer de vscode extensions
    if ('vscode' -in $installedpackages) {
        $ie = code --list-extensions
        Write-Output '-------------------------------------'
        Write-Output 'start installation vscode extensions'
        Write-Output '-------------------------------------'
        foreach ($extension in $extensions) {
            if ($extension -notin $ie) {
                Write-Output "$extension to install"
                code --install-extension $extension | Out-Default
                Write-Output "$extension installed"
            }
            else {
                Write-Output "$extension already installed"
            }
        }
    }

    # configureer git
    if ('git' -in $installedpackages) {
        $gitconfig = git config --global --list
        if ("user.name=$gitname" -notin $gitconfig) {
            Write-Output '---------------'
            Write-Output 'configuring Git'
            Write-Output '---------------'
            git config --global user.name $gitname
            git config --global user.email $gitemail
            git config --global core.editor 'code --wait'
        }
    }
    Write-Output '--------------------------'
    Write-Output 'DownLoad Repos'
    Write-Output '--------------------------'
    # en download repositories
    Set-Location -Path $RepoDir
    foreach ($repository in $repositories) {
        $localdir = $repository.split('/')[-1].replace('.', '\.')
        if (!(Test-Path "$RepoDir\$LocalDir")) {
            git clone $repository
            Write-Output "$repository downloaded"
        }
    }
    Write-Output '-----------------------------'
    Write-Output 'Installing Powershell Modules'
    Write-Output '-----------------------------'

    # installeer de nieuwste NuGet Package provider
    Install-PackageProvider -Name NuGet -Force
    # en nu PSgallery op trusted
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

    foreach ($module in $modules) {
        if ($module -eq 'Pester') {
            $moduleinfo = Get-Module $module -ListAvailable  | Sort-Object -Property Version | Select-Object -Last 1
            if ($moduleinfo.version.major -lt 5) {
                Install-Module -Name Pester -Force -SkipPublisherCheck -Scope Allusers
            }
        }
        if ($module -eq 'Powershellget') {
            $lastmoduleinfo = Find-Module powershellget
            $moduleinfo = Get-Module $module -ListAvailable  | Sort-Object -Property Version | Select-Object -Last 1
            if ($lastmoduleinfo.version -gt $moduleinfo.version) {
                In
            }
        }
        try {
            Import-Module $module -ErrorAction Stop -Verbose:$false
            Write-Output "$module already installed......"
        }
        catch {
            try {
                Install-Module -Name $module -Scope allusers -Force -ErrorAction Stop
                Write-Output "$module installed......"
            }
            catch {
                Write-Output "Installing $module failed..."
            }
        }
    }

    Write-Output '--------------------------'
    Write-Output 'Adding to Environment Path'
    Write-Output '--------------------------'
    # Module dirs toevoegen aan systeem environment variabele: PSModulePath
    foreach ($dir in $ModulePathDirs) {
        $CurrentValue = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
        if (Test-Path $dir) {
            if ($dir -notin $currentValue.split(';')) {
                [Environment]::SetEnvironmentVariable('PSModulePath', $CurrentValue + [System.IO.Path]::PathSeparator + $dir, 'Machine')
                Write-Output "$dir added to enviroment variable: PSModulePath"
            }
        }
    }

    # Dirs toevoegen aan systeem environment variabele: Execution Path
    foreach ($dir in $ScriptDirs) {
        $CurrentValue = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        if (Test-Path $dir) {
            if ($dir -notin $currentValue.split(';')) {
                [Environment]::SetEnvironmentVariable('Path', $CurrentValue + [System.IO.Path]::PathSeparator + $dir, 'Machine')
                Write-Output "$dir added to enviroment variable: Path"
            }
        }
    }
    Write-Output '-----------------'
    Write-Output 'Installation Done'
    Write-Output '-----------------'
}

# ------------------ main -----------------------
$RepoDir = 'C:\Beheer'

$Artifacts = @{
    RepoDir        = $RepoDir
    dirs           = ('.\data', '.\data\buza', '.\Data\Buza\Logging', '.\Data\Buza\Mappings', '.\data\temp')
    packages       = ('vscode', 'git', 'sql-server-express', 'powerbi', 'sharegate-desktop')
    repositories   = ('https://github.com/mthacken/PaccarShareGate.git', 'https://github.com/mthacken/PowerShell.git')
    modules        = ('pester', 'sqlserver', 'SharePointPnPPowerShell2013')
    extensions     = ( 'ms-vscode.powershell', 'alefragnani.project-manager')
    ModulePathDirs = ("$RepoDir\Powershell\Modules", "$RepoDir\PaccarShareGate\Modules")
    ScriptDirs     = ("$RepoDir\Powershell\scripts")
    gitname        = 'mthacken'
    gitemail       = 'martijn@tenhacken.nl'
    ServerOnline   = $false
}
install-artifact @Artifacts

