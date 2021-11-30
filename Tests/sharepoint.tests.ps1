# this test script checks if you can interact with the sharepoint environment. 
# It Uploads a random file and updates this file and checks if the last modified date is changing.
# At the end the file is deleted from SharePoint

Using Module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
    $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB
    $script:skipsitecheck = $env:Computername -in @('nlwbuzpaS97','nlwbuzpaS95','nlwbuzaaS98')
}

Describe 'SharePoint.tests.ps1: Testing the SharePoint Interface' -Tag 'Integration' {
    BeforeAll {
        # check all interactions with SharePoint, including uploading a file to the DemoList in settings.
        # Get-Module PaccarShareGate | Remove-Module
        # import-module PaccarShareGate # No mocking, so it can be loaded as a normal module.
        Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
        $script:skip = !$settings.SQLdetails -or !$settings.SQLdetails.DeleteDB

        $script:RelSiteUrl = $settings.current.MigrationURLS[0].DemoSite[0]
        $script:ListTitle = $settings.current.MigrationURLS[0].DemoList
        $script:SiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.Current.MigrationURLS[0].SourceTenantDomain -path $RelSiteUrl
        $script:RelListUrl = $RelSiteUrl + '/' + $ListTitle
        $script:ListUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.Current.MigrationURLS[0].SourceTenantDomain -path $RelListUrl
        # fill the Demo Library
        if (!$skip) {     
            # Create testdata : check if the SP demo library (locally stored) is already filled, if not fill it
            New-MtHTestData -Number 25 -MaxFileSize 10000 -RandomSize
            $files = (Get-ChildItem -Path $settings.FilePath.TempDocs -Depth 1 -File)
            $script:randomfile = $files[(Get-Random -Maximum $files.count)]
        
            # relrandom file = randomfile fullname without the path but with a potential subdirectory
            $script:relrandomfile = $randomfile.FullName.Replace("$($settings.FilePath.TempDocs)\", '')
            $script:RelPath = $RelListUrl + '/' + $relrandomfile
            $script:SiteMU = [MigrationUnitClass]@{
                SourceUrl  = $siteUrl
                Scope      = 'site'
                MUStatus   = 'active'
                NextAction = 'none'
            }
            $script:ListMU = [MigrationUnitClass]@{
                SourceUrl  = $siteUrl
                ListUrl    = $RelListUrl
                ListTitle  = $ListTitle
                Scope      = 'list'
                MUStatus   = 'active'
                NextAction = 'none'
            }
        }
    }
    AfterAll {
        if (!$skip) {
            Remove-MtHFiles  -SourceUrl $Settings.Current.MigrationURLS[0].SourceTenantDomain -Library $ListURL -FilePath $settings.FilePath.TempDocs -Files @($randomfile)
        }
        Stop-MtHLocalPowershell
    }
    Context 'Check SharePoint Connection' {
        It '1.1: Initialize-MtHSharePoint should not run into an error' {
            { Initialize-MtHSharePoint } | Should -Not -Throw
        }
        It '1.2: Connect to demo sitecollection should be OK' {
            { Connect-MtHSharePoint -URL $siteUrl } | Should -Not -Throw
        }
        # should at least return the Demo site....
        It '1.3: Checking the Admin rights should give sites back' -skip:$skipsitecheck {
            $result = Test-MtHAdminRightsAllSites
            $result.count | Should -BeGreaterThan 0
        }
    }
    Context 'Check SharePoint interaction with demo library' -Skip:$skip {
        It '1.4: Checking the Last Modified date of the List MU' {
            $script:ResultDate1 = Test-MtHSPMigUnitModified -item $ListMU
            $timediff = New-TimeSpan -Start $resultDate1 -End $(Get-Date)
            $timediff.TotalSeconds | Should -BeGreaterThan 1
        }
        It '1.5: Checking the Last Modified date of the Site MU' {
            $script:ResultDate2 = Test-MtHSPMigUnitModified -item $SiteMU
            $timediff = New-TimeSpan -Start $resultDate2 -End $(Get-Date)
            $timediff.TotalSeconds | Should -BeGreaterThan 1
        }
        It '1.6: Upload one file to the SharePoint Library should work' {
            Connect-MtHSharePoint -URL $siteUrl
            {Send-MtHFiles -SourceURL $settings.Current.MigrationURLS[0].SourceTenantDomain -Library $ListURL -FilePath $settings.FilePath.TempDocs -Files @($randomfile) } | Should -Not -Throw
        }
        It '1.7: Last Modified date of the List MU should be updated' {
            $script:ResultDate3 = Test-MtHSPMigUnitModified -item $ListMU
            $timediff = New-TimeSpan -Start $resultDate1 -End $resultDate3
            $timediff.TotalSeconds | Should -BeGreaterThan 1
        }
        # you would expect if you update a list the last modified date of the corresponding SiteCollection is updated, but that is ot the case
        # for now we skip this test
        It '1.8: Last Modified date of the Site MU should be updated'-Skip {
            $script:ResultDate4 = Test-MtHSPMigUnitModified -item $SiteMU
            $timediff = New-TimeSpan -Start $resultDate2 -End $resultDate4
            $timediff.TotalSeconds | Should -BeGreaterThan 1
        }
        It '1.9: Update the file and upload it to the SharePoint Library again should work' {
            Start-Sleep -Seconds 1
            Add-Content -Path $randomfile.FullName "`nNew Version"
            Connect-MtHSharePoint -URL $siteUrl
            { Send-MtHFiles -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -Library $ListURL -FilePath $settings.FilePath.TempDocs -Files @($randomfile) } | Should -Not -Throw
        }
        It '1.10: Last Modified date of the List MU should be updated' {
            $script:ResultDate5 = Test-MtHSPMigUnitModified -item $ListMU
            $timediff = New-TimeSpan -Start $resultDate3 -End $resultDate5
            $timediff.TotalSeconds | Should -BeGreaterThan 1
        }
        # you would expect if you update a list the last modified date of the corresponding SiteCollection is updated, but that is ot the case
        # for now we skip this test
        It '1.11: Last Modified date of the Site MU should be updated' -Skip {
            $script:ResultDate6 = Test-MtHSPMigUnitModified -item $SiteMU
            $timediff = New-TimeSpan -Start $resultDate4 -End $resultDate6
            $timediff.TotalSeconds | Should -BeGreaterThan 1
        }
    }
}