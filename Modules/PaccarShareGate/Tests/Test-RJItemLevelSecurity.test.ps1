using module MigrationClasses
BeforeDiscovery {
    Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
     # skip if we cannot use a deletable test database
    if ($skip) {
        Write-Verbose 'No SharePoint interaction Testing on this environment, because there is no SQL test database defined or deletion not allowed.'
    }
}

# Pester runs twice: Discovery and Real testing.
#Transaction tests are only run against the test database when there is a test database in the environment 
Describe 'Validate broken/item-level permissions' -Skip:$skip {
    BeforeAll {
        Start-MtHLocalPowerShell -settingfile "$(Get-MtHGitDirectory)\Settings.json" -test
        # load all PaccarShareGate commands in the local scope, so they can be mocked
        Get-Module PaccarShareGate | Remove-Module -Force
        $dir = Get-MtHGitDirectory
        (Get-Command -Module PaccarShareGate).name | ForEach-Object {
            . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
        } 
        #For testing the first entry is used
        $script:AbsDemoSiteUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain  -path $settings.current.MigrationURLS[0].DemoSite[0]
        $script:RelDemoListUrl = $settings.current.MigrationURLS[0].DemoSite[0] + '/' + $settings.current.MigrationURLS[0].DemoList
        $script:AbsDemoListUrl = ConvertTo-MtHHttpAbsPath -SourceURL $settings.current.MigrationURLS[0].SourceTenantDomain -path $RelDemoListUrl
        Connect-MtHSharePoint -URL $AbsDemoSiteUrl | Out-Null
        $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  RoleAssignments,  HasUniqueRoleAssignments, ReadSecurity, WriteSecurity  
        $Script:OriginaRoleAssignments =  $List.RoleAssignments
        $Script:OriginalHasUniqueRoleAssignments =  $List.HasUniqueRoleAssignments 
        $Script:OriginalUniqueItemReadSecurity =  $List.ReadSecurity 
        $Script:OriginalUniqueItemWriteSecurity =  $List.WriteSecurity 
    }  
    AfterAll {
        Stop-MtHLocalPowershell -test
    }
    Context '1: Check Demo list  SP and check uniqueroleassigments' {
        It '1.0: Validate correct Demo list' {
   
            $List.Title | Should -Be  "Demo"
        }

        It '1.1:Check Demolist "Permissions" types ' {
            #Item level ReadSecurity=2 
            # 1=read all items
            # 2=read items created by user
            
            #Item level WriteSecurity 
            # 1=Create and edit All items
            # 2=Create items and edit items that were created by the user
            # 4=None

            #If Read = #1 and Write  = #1 -> No item level security

            $Script:OriginalHasUniqueRoleAssignments| Should -BeOfType  [bool]
            $Script:OriginalUniqueItemReadSecurity| Should -BeOfType  [Int]
            $Script:OriginalUniqueItemWriteSecurity| Should -BeOfType  [Int]
        }
        It '1.2:Alter Unique role assignments  "HasUniqueRoleAssignments"' {
            if($Script:OriginalHasUniqueRoleAssignments)
            {
                Set-PNPLIst -Identity  $List.Title	-ResetRoleInheritance 
            }
            else {
                Set-PNPLIst -Identity  $List.Title	 -BreakRoleInheritance 
            }
           
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  HasUniqueRoleAssignments
            $ExpectedResult = !($Script:OriginalHasUniqueRoleAssignments)
            $List.HasUniqueRoleAssignments | Should -Be $ExpectedResult
        }
        
        It '1.3:reset Unique role assignments  "HasUniqueRoleAssignments"' {
            #Reset unique Users permissions ignored (Demo list only)
            if(!($Script:OriginalHasUniqueRoleAssignments))
            {
                Set-PNPLIst -Identity  $List.Title	-ResetRoleInheritance 
            }
            else {
                Set-PNPLIst -Identity  $List.Title	 -BreakRoleInheritance -CopyRoleAssignments $OriginaRoleAssignments 
            }
           
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  HasUniqueRoleAssignments
            $ExpectedResult = $Script:OriginalHasUniqueRoleAssignments
            $List.HasUniqueRoleAssignments | Should -Be $ExpectedResult
        }
    }
    Context '2: Check and alter Demo list ReadSecurity' {

        It '2.0:Alter Unique permissions in DemoList "ReadSecurity - Read All"' {
            #Not in PNP 3.28
            #Set-PNPLIst -Identity $List.title  -ReadSecurity AllUsersReadAccess
            $List.ReadSecurity = 1
            $List.Update()
            # 1=read all items
            # 2=read items created by user
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  ReadSecurity
            $List.ReadSecurity | Should -BeExactly 1
        }

        It '2.1 Alter Unique permissions in DemoList "ReadSecurity -  Read own items only"' {
            #Not in PNP 3.28
            #Set-PNPLIst -Identity $List.title  -ReadSecurity AllUsersReadAccessOnItemsTheyCreate
            $List.ReadSecurity = 2
            $List.Update()
            # 1=read all items
            # 2=read items created by user
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  ReadSecurity
            $List.ReadSecurity | Should -BeExactly 2
        }

        It '2.2 Reset Unique permissions in original value ' {
            #Not in PNP 3.28
            #Set-PNPLIst -Identity $List.title  -ReadSecurity AllUsersReadAccessOnItemsTheyCreate
            $List.ReadSecurity = $Script:OriginalUniqueItemReadSecurity
            $List.Update()
            # 1=read all items
            # 2=read items created by user
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  ReadSecurity
            $List.ReadSecurity | Should -BeExactly $Script:OriginalUniqueItemReadSecurity
        }
    }
   
    Context '3: Check and alter Demo list WriteSecurity' {
        It '3.0:Alter Unique permissions in DemoList "WriteSecurity "Create and edit All"' {
            #Item level WriteSecurity 
            # 1=Create and edit All items
            # 2=Create items and edit items that were created by the user
            # 4=None
            $List.WriteSecurity = 1
            $List.Update()
            # 1=read all items
            # 2=read items created by user
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  WriteSecurity
            $List.WriteSecurity| Should -BeExactly 1
        }

        It '3.1 Alter Unique permissions in DemoList "WriteSecurity - Create items and edit items that were created by the user"' {
            #Item level WriteSecurity 
            # 1=Create and edit All items
            # 2=Create items and edit items that were created by the user
            # 4=None
            $List.WriteSecurity = 2
            $List.Update()
            # 1=read all items
            # 2=read items created by user
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  WriteSecurity
            $List.WriteSecurity| Should -BeExactly 2
        }

        It '3.2 Alter Unique permissions in DemoList "WriteSecurity - None"' {
            #Item level WriteSecurity 
            # 1=Create and edit All items
            # 2=Create items and edit items that were created by the user
            # 4=None
            $List.WriteSecurity = 4
            $List.Update()
            # 1=read all items
            # 2=read items created by user
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  WriteSecurity
            $List.WriteSecurity| Should -BeExactly 4
        }

        It '3.2 Reset Unique permissions in original value  ' {
            #Not in PNP 3.28
            #Set-PNPLIst -Identity $List.title  -ReadSecurity AllUsersReadAccessOnItemsTheyCreate
            $List.WriteSecurity = $Script:OriginalUniqueItemWriteSecurity
            $List.Update()
            $Script:List = Get-PnPList -Identity $settings.current.MigrationURLS[0].DemoList -Includes  WriteSecurity
            $List.WriteSecurity | Should -BeExactly $Script:OriginalUniqueItemWriteSecurity
        }
    }
}