# Deployment script, voor 1 zip file voor alles wat je op de offline server nodig hebt.

# push en pull van mijn eigen laptop
#Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\settings.json"
if ($env:COMPUTERNAME -in @('LAPTOP-RDDO0DAV', 'DESKTOP-Q0P52LG')) {
    $IncomingGitRepo 
    $OutgoingGitRepo 
    switch ($env:COMPUTERNAME) {
        'LAPTOP-RDDO0DAV' {
            $IncomingGitRepo = Get-ChildItem -Path 'D:\beheer\software\GitBundles\BuzaSharegateback*.bundle'
            $OutgoingGitRepo = 'D:\beheer\software\GitBundles\BuzaSharegate.bundle'    
        }
        'DESKTOP-Q0P52LG' {
            $IncomingGitRepo = Get-ChildItem -Path 'C:\BuZa\Beheer\software\GitBundles\BuzaSharegateback*.bundle'
            $OutgoingGitRepo = 'C:\BuZa\Beheer\software\GitBundles\BuzaSharegate.bundle'    
        }
    }
    Set-Location -Path $(Get-MtHGitDirectory -Error)

    if ($incominggitrepo) {
        git pull $IncomingGitRepo[0]
        Write-Host 'Pulled incoming git repo. Is this the correct action?'
        Pause
        Remove-Item $IncomingGitRepo[0]
        if ($IncomingGitRepo.count -gt 1) {
            Write-Host 'Please run Deploy again to pull another git bundle....'
        }
    }
    else {
        # check if there are no changes after your last commit
        # then create a git bundle and copy it to the Atos Chess VM, so it can be copied to the Buza Environment
        # more info on how to use git bundle: https://git-scm.com/docs/git-bundle

        if ($null -eq (git ls-files -mo --exclude-standard)) {
            # creer van de huidige git een bundle (alle git files) die je kan kopieren naar een offline bibliotheek 
            Write-Host 'All files Committed'
        }
        else {
            Write-Host 'Warning: You did not commit all files first'
            Pause
        }
        # creer van de huidige git een bundle (alle git files) die je kan kopieren naar een offline bibliotheek 
        Git bundle create $OutgoingGitRepo --all
    }
}

# push en pull van de Buza Servers
if ($env:COMPUTERNAME -in @('NLWBUZAAS98', 'NLWBUZAAS96', 'NLWBUZPAS99','NLWBUZPAS95','NLWBUZPAS97')) {
    $extension = $env:COMPUTERNAME.Substring(7, 4)
    $IncomingGitRepo = 'D:\software\gitbundles\BuzaSharegate.bundle'
    $OutgoingGitRepo = "D:\software\gitbundles\BuzaSharegateback-$extension.bundle"

    Set-Location -Path $(Get-MtHGitDirectory -Error)

    if (Test-Path $incominggitrepo) {
        Write-Host 'Following Git Bundle to Pull:'
        Get-ChildItem  $IncomingGitRepo
        Pause
        git pull $IncomingGitRepo 
        Write-Host 'Pulled incoming git repo. Is this correctly done? Remove GitRepo?'
        Pause
        Remove-Item $IncomingGitRepo
    }
    else {
        Write-Host 'No Git Bundle to Pull, Push latest commits?'
        Pause
        # check if there are no changes after your last commit
        # then create a git bundle and copy it to the Atos Chess VM, so it can be copied to the Buza Environment
        # more info on how to use git bundle: https://git-scm.com/docs/git-bundle

        if ($null -eq (git ls-files -mo --exclude-standard)) {
            # creer van de huidige git een bundle (alle git files) die je kan kopieren naar een offline bibliotheek 
            Write-Host 'All files Committed'
        }
        else {
            Write-Host 'Warning: You did not commit all files first'
            Pause
        }

        # creer van de huidige git een bundle (alle git files) die je kan kopieren naar een offline bibliotheek 
        Git bundle create $outgoinggitrepo --all
    }
}