using module MigrationClasses
# run defined SQL queries against the database. Only Queries with zero or one parameter $itemnr can be defined here.
function Invoke-MtHSQLquery {
    [CmdletBinding()]
    Param(
        
        [parameter(mandatory = $true)] [ValidateSet('D-ALL', 'D-FIRST', 'D-DELTA', 'E-ALLANDFAKE', 'E-ALL', 'E-FAKE', 'E-START', 'T-FillDBforTest', 'DistributeNodes', 'C-MUSC')][String] $QueryName,
        [parameter(mandatory = $false)] [int] $ItemNr,
        [parameter(mandatory = $false)] [PSObject] $DestinationURL,
        [switch]$NoResolveMUClass
    )
    Switch ($QueryName) {
        'C-MUSC' {
            # query C1 : Clear all MUs from MigrationUnits where TargetURL macthes (After reimport)
            $sql = @"
            Delete from MigrationUnits where DestinationURL = '$($DestinationURL)'
"@
        }
        'D-ALL' {
            # query D1 : Select all migration units to check last updated time ( Copy Detection cycle)
            # if never checked LastStartTime = $null
            $sql = @"
            SELECT U.MigUnitId AS MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction, MAX(StartTime) AS LastStartTime
            FROM MIgrationUnits AS U
            LEFT OUTER JOIN
            MigrationRuns AS R
            ON U.MigUnitId = R.MigUnitId
            WHERE (U.NextAction = 'none' AND (U.MUStatus = 'active' OR U.MUStatus = 'fake'))
            GROUP BY U.MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
            ORDER BY SourceURL;
"@
        }
        'E-ALLANDFAKE' {
            # Query E1 : Select all migrations to do
            $sql = @"
            SELECT U.MigUnitId AS MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  UniquePermissions, ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction, MAX(StartTime) AS LastStartTime
            FROM MIgrationUnits AS U
            LEFT OUTER JOIN
            MigrationRuns AS R
            ON U.MigUnitId = R.MigUnitId
            WHERE (U.NextAction IN ('first','delta') AND U.NodeId = $($settings.NodeId) AND (U.MUStatus = 'Active' OR U.MUStatus = 'Fake') AND (R.Result <> 'started' OR  R.Result IS NULL))
            GROUP BY U.MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId, UniquePermissions,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
            ORDER BY SourceURL;
"@
        }
        'E-ALL' {
            # Query E1 : Select all migrations to do
            $sql = @"
            SELECT U.MigUnitId AS MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction, MAX(StartTime) AS LastStartTime
            FROM MIgrationUnits AS U
            LEFT OUTER JOIN
            MigrationRuns AS R
            ON U.MigUnitId = R.MigUnitId
            WHERE (U.NextAction IN ('first','delta') AND U.NodeId = $($settings.NodeId) AND U.MUStatus = 'Active' AND (R.Result <> 'started' OR  R.Result IS NULL))
            GROUP BY U.MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
            ORDER BY SourceURL;
"@
        }
        'E-FAKE' {
            # Query E1 : Select all migrations to do
            $sql = @"
            SELECT U.MigUnitId AS MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction, MAX(StartTime) AS LastStartTime
            FROM MIgrationUnits AS U
            LEFT OUTER JOIN
            MigrationRuns AS R
            ON U.MigUnitId = R.MigUnitId
            WHERE (U.NextAction IN ('first','delta') AND U.NodeId = $($settings.NodeId) AND U.MUStatus = 'Fake' AND (R.Result <> 'started' OR  R.Result IS NULL))
            GROUP BY U.MigUnitId, EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ListTitle, ListId,  ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction
            ORDER BY SourceURL;
"@
        }
        'DistributeNodes' {
            # Query R3 : Get all active lirary MU's  for item level deletion where a Delta run has taken place (Last occurence)
            $sql = @"
            Update MigrationUnits Set
            NodeId = $($SiteCollection.NodeID)
            Where SourceUrl ='$($SiteCollection.SourceURL)'
"@
        }
        'LogMigrationProgress' {
            # Query L1 : Get progress information regarding mtotal migration process
            $sql = @"
            SELECT 
            FORMAT (getdate(), 'dd-MM-yyyy hh:MM') as Logdate
            ,[EnvironmentName]
            ,SUM (ItemCount) as ItemsCountINScope
            ,COUNT(SourceURL) as MUsINScope
            ,[MUStatus]
            ,NextAction
        FROM [SQLO365].[dbo].[MigrationUnits] u
        GROUP BY [EnvironmentName]
            ,[MUStatus]
            ,(NextAction)
            Order by ItemsCountINScope, MUsINScope, MUStatus, NextAction
"@
        }
        'T-FillDBforTest' {
            $NodeId = $settings.NodeId
            $sql = @"
            INSERT INTO MigrationUnits
    (EnvironmentName, CompleteSourceUrl, SourceUrl, DestinationUrl, ListUrl, ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction, CreationTime)
VALUES
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '', '', 'site', 'new', 1, 'none', SYSDATETIME()),
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '/sites/input1/shared docs', '', 'list', 'notfound', $NodeId, 'none', SYSDATETIME()),
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '/sites/input1/shared docs2', '', 'list', 'active', $NodeId, 'first', SYSDATETIME()),
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '/sites/input1/shared docs3', '', 'list', 'active', $NodeId, 'none', SYSDATETIME()),
    ('o365', 'https://mock.sharepoint.com/sites/input2', 'https://mock.sharepoint.com/sites/M1-input2', '/sites/input2/shared docs3', '', 'list', 'fake', $NodeId, 'none', SYSDATETIME())
"@
        }
    }

    $result = Invoke-Sqlcmd -ServerInstance $Settings.SQLDetails.Instance -Database $Settings.SQLDetails.Database -Query $sql
    #No MigrationUnitClass resolve if switch provided (For migration process progress purposes)
    if ($NoResolveMUClass.IsPresent) {
        $output = $result
    }
    else {
        $output = $result | Resolve-MtHMUClass
    }
    return $output
}
