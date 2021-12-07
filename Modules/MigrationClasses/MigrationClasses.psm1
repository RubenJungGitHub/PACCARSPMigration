class MigrationUnitClass {
    [string]$SourceSC
    [string]$EnvironmentName
    [string]$CompleteSourceUrl
    [string]$SourceUrl
    [string]$DestinationUrl
    [string]$ListUrl = ''
    [string]$ListTitle = ''
    [string]$ListId
    [bool]$UniquePermissions
    [bool]$MergeMUS
    [int]$ListTemplate
    [int]$ItemCount
    [string]$ShareGateCopySettings = ''
    [string]$Scope
    [String]$MUStatus = 'new'
    [int]$NodeId
    [String]$NextAction = 'none'
    [String]$DuplicateTargetLibPrefix = ''
    [int]$MigUnitId = 0
    [dateTime]$LastStartTime
    # constructors
    MigrationUnitClass () {
    }
    # methods
    Validate() {
        #$this.DestinationUrl = ConvertTo-MtHDestinationUrl -SourceUrl $this.sourceUrl  
        if ($this.Scope -notin ('list', 'site')) {
            throw 'Scope invalid'
        }
        if (!$this.MUStatus) {
            $this.MUStatus = 'new'
        }
        if (!$this.NextAction) {
            $this.NextAction = 'none'
        }
        if ($this.MUStatus -notin ('fake', 'active', 'failed', 'inactive', 'new', 'notfound')) {
            throw 'MUStatus invalid'
        }
        if ($this.NextAction -notin ('none', 'first', 'delta')) {
            throw 'NextAction invalid'
        }
        if ($null -eq $this.ShareGateCopySettings) {
            $this.ShareGateCopySettings = ''
        }
    }
}


class MigrationRunClass {
    [int]$MigUnitId
    [datetime]$StartTime
    [int]$Processed
    [string]$Result
    [string]$SGSessionId
    [decimal]$RunTimeInSec
    [string]$Details
    [string]$Kind
    [int]$MigRunId
}
