class MigrationUnitClass {
    [string]$EnvironmentName
    [string]$SourceUrl
    [string]$DestinationUrl
    [string]$ListUrl = ''
    [string]$ListTitle = ''
    [string]$ListId
    [int]$ListTemplate
    [int]$ItemCount
    [string]$ShareGateCopySettings = ''
    [string]$Scope
    [String]$MUStatus = 'new'
    [int]$NodeId
    [String]$NextAction = 'none'
    [int]$MigUnitId = 0
    [dateTime]$LastStartTime
    # constructors
    MigrationUnitClass () {
    }
    # methods
    Validate() {
        $this.DestinationUrl = ConvertTo-MtHDestinationUrl -SourceUrl $this.sourceUrl  
        if ($this.Scope -notin ('list', 'site')) {
            throw 'Scope invalid'
        }
        if ($this.Scope -eq 'list') {       
            $this.ListUrl = ConvertTo-MtHHttpRelPath -SourceUrl $this.sourceurl -path $this.ListUrl -webapp -startingslash
        }
        if ($this.scope -eq 'site' -and $this.ListUrl) {
            throw 'ListURl should be null or empty for a site MU'
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
