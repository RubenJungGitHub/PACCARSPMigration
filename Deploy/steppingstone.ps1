# synchronize all software with migration VMs Acceptance and Production

Write-Host 'Current logged on user :'  $env:username 

# usersettings
switch ($env:username) {
    'NL25335' {
        $MappedDrive = '\\tsclient\u'
        $copyinstallationfiles = $false
        $copyreports = $false
        $action = @('InstallationFiles', 'Reports', 'BothReportsandInstallationFiles') | out-gridview  -Title "Select Action" -OutputMode Single

        switch ($action) {
            'InstallationFiles' {
                $copyinstallationfiles = $true 
            }
            'Reports' {
                $copyreports = $true 
            }
            'BothReportsandInstallationFiles' {
                $copyinstallationfiles = $true
                $copyreports = $true 
            }
        }
    }
    'NL07428' {
        $MappedDrive = '\\tsclient\v\Buza'
        $copyinstallationfiles = $false
        $copyreports = $false
    }
}

$steppingstones = @(
    [PSCustomObject]@{
        Name               = 'Acceptance'
        Computername       = 'NLWBUZST04'
        destinationservers = @('nlwbuzaaS98', 'nlwbuzaaS96')
    },
    [PSCustomObject]@{
        Name               = 'Production'
        Computername       = 'NLWBUZST031'
        destinationservers = @('nlwbuzpaS99', 'nlwbuzpaS97', 'nlwbuzpaS95')
    }
)

# define main paths
$steppingstone = $steppingstones | Where-Object { $_.Computername -eq $env:computername }
$swsource = -join ($MappedDrive, '\Beheer\Software\BuZaShareGate')
$gitsource = -join ($MappedDrive, '\Beheer\Software\GitBundles')
$reportsource = -join ($MappedDrive, '\Beheer\ShareGateReports\', $steppingstone.name)
$mappingsource = -join ($MappedDrive, '\Beheer\Data\Buza\Mappings')

if (!(Test-Path -Path $reportsource)) {
    New-Item -Path $reportsource -ItemType 'Directory'
}

#display main info
Write-Host "Mapped SS drive : $MappedDrive"
Write-Host "SWSource :'  $swsource" 
Write-Host "GitSource :'  $GitSource"
Write-Host "ReportSource :'  $reportsource"

# copy software forth (to the buza servers)
if ($copyinstallationfiles) {
    foreach ($dest in $steppingstone.destinationservers) {
        # kopieer installatie files - houd deze in sync (vanaf Laptop naar Servers)
        robocopy "$swsource\Nuget" "\\$dest\d$\Software\BuZaShareGate\Nuget" *.nupkg
        robocopy $swsource "\\$dest\d$\Software\BuZaShareGate" *.exe
        robocopy $swsource "\\$dest\d$\Software\BuZaShareGate" *.zip
        robocopy $swsource "\\$dest\d$\Software\BuZaShareGate" *.msi
        robocopy "$swsource\Extensions" "\\$dest\d$\Software\BuZaShareGate\Extensions" *.vsix
        # kopieer mapping files
        robocopy "$mappingsource" "\\$dest\d$\Beheer\Data\Buza\Mappings" *.sgum
    }
}

# copy reports back (from the buza servers)
if ($copyreports) {
    foreach ($dest in $steppingstone.destinationservers) {
        robocopy "\\$dest\d$\Beheer\ShareGateReports" $reportsource  *.xlsx
        robocopy "\\$dest\d$\Beheer\ShareGateReports" $reportsource  *.csv
        robocopy "\\$dest\d$\Beheer\ShareGateReports" "\\$dest\d$\Beheer\ShareGateReports\Archive"  *.csv /Move
        robocopy "\\$dest\d$\Beheer\ShareGateReports" "\\$dest\d$\Beheer\ShareGateReports\Archive"  *.xlsx /Move
        robocopy "\\$dest\d$\Beheer\data\Buza\Logging" $reportsource  *.csv
        robocopy "\\$dest\d$\Beheer\data\Buza\Logging" $reportsource  *.log
        robocopy "\\$dest\d$\Beheer\data\Buza\Logging" "\\$dest\d$\Beheer\data\Buza\Logging\Archive" *.csv /Move
        robocopy "\\$dest\d$\Beheer\data\Buza\Logging" "\\$dest\d$\Beheer\data\Buza\Logging\Archive" *.log /Move
    } 
}

# copy git bundle back and forth
foreach ($dest in $steppingstone.destinationservers) {
    # kopieer de git bundle (in en out)
    $extension = $dest.Substring(7, 4)
    robocopy "\\$dest\d$\software\GitBundles" $gitsource  "buzasharegateback-$extension.bundle" /Move
    robocopy $gitsource "\\$dest\d$\Software\GitBundles" 'buzasharegate.bundle'
}


# remove de source bundle
$TempPath = -join ($MappedDrive, '\beheer\software\gitbundles\buzasharegate.bundle')
if ((Test-Path -Path $TempPath)) {
    Write-Host "Source bundle 'buzasharegate.bundle' on $TempPath Deleted!"
    Remove-Item -Path $TempPath
}
Pause