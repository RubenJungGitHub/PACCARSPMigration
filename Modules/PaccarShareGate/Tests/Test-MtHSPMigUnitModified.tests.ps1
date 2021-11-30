using module MigrationClasses
BeforeAll {
  $dir = Get-MtHGitDirectory
  (Get-Command -Module PaccarShareGate).name | ForEach-Object {
    . "$dir\Modules\PaccarShareGate\Public\$_.ps1" 
} 
}
Describe 'UnitTests for Test-MtHSPMigUnitModified' -Tag 'Unit' {
  BeforeEach {
    Mock -CommandName Get-PnPList -Mockwith {
      return [PSCustomObject]@{ LastItemModifiedDate = [DateTime]::ParseExact('2021-01-02 12:00:00', 'yyyy-MM-dd hh:mm:ss', $null) }
    }
    Mock -CommandName get-PnPWeb -Mockwith {
      return [PSCustomObject]@{ LastItemModifiedDate = [DateTime]::ParseExact('2021-03-02 12:00:00', 'yyyy-MM-dd hh:mm:ss', $null) }
    }
    $script:input1 = [MigrationUnitClass]@{
      EnvironmentName = 'o365'
      SourceUrl       = 'https://mock.sharepoint.com/sites/input1'
      Scope           = 'site'
    }
    $script:input2 = [MigrationUnitClass]@{
      EnvironmentName = 'o365'
      SourceUrl       = 'https://mock.sharepoint.com/sites/input1'
      ListUrl         = 'https://mock.sharepoint.com/sites/input1/shared documents'
      ListTitle       = 'shared documents'
      Scope           = 'list'
    }
  }
  It 'Should return the date 02/03/2021' {
    $result = Test-MtHSPMigUnitModified -item $input1
    $result.ToString('dd/MM/yyyy') | Should -Be '02/03/2021'
  }
  It 'should return the date 02/01/2021' {   
    $result = Test-MtHSPMigUnitModified -item $input2
    $result.ToString('dd/MM/yyyy') | Should -Be '02/01/2021'
  }
  It 'Should call function get-PnP-Web once for input1'  {
    Test-MtHSPMigUnitModified -item $input1
    Should -Invoke get-PnPWeb -Exactly 1
  }
  It 'Should not call function Get-PnPList input1'  {
    Test-MtHSPMigUnitModified -item $input1
    Should -Invoke Get-PnPList -Exactly 0
  }
  It 'Should not call function Get-PnPWeb for input2' {
    Test-MtHSPMigUnitModified -item $input2
    Should -Invoke get-PnPWeb -Exactly 0
  }
  It 'Should call function Get-PnPList once for input2'  {
    Test-MtHSPMigUnitModified -item $input2
    Should -Invoke Get-PnPList -Exactly 1
  }
}