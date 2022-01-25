CREATE TABLE MigrationUnits
(
    EnvironmentName VARCHAR(10) NOT NULL
        CHECK (EnvironmentName IN ('o365','aef','acceptance','production')),
    SourceSC VARCHAR(400) NOT NULL,
    CompleteSourceUrl VARCHAR(400) NOT NULL,
    SourceUrl VARCHAR(400) NOT NULL,
    DestinationUrl VARCHAR(400) NOT NULL,
    SitePermissionsSource VARCHAR(400) NOT NULL,
    DuplicateTargetLibPrefix VARCHAR(50) NOT NULL,
    TargetLibPrefixGiven VARCHAR(400) NULL,
    ListUrl VARCHAR(400) NULL,
    ListTitle NVARCHAR(400) NULL,
    ListTitleWithPrefix NVARCHAR(400) NULL,
    ListID VARCHAR(400) NULL,
    ItemCount INT Null,
    UniquePermissions BIT,
    MergeMUS BIT,
    
    ShareGateCopySettings VARCHAR(400) NULL,
    Scope VARCHAR(10) NOT NULL
        CHECK (Scope IN ('list','site')),
    MUStatus VARCHAR(10) NOT NULL
        CHECK (MUStatus IN ('active','fake','failed','inactive','new','notfound')),
    NextAction VARCHAR(10) NOT NULL
        CHECK ( NextAction IN ('none','first','delta','delete')),
    NodeId INT NULL,
    CreationTime DATETIME2(0) NOT NULL,
    MigUnitId INT IDENTITY(1,1) NOT NULL PRIMARY KEY
);

CREATE TABLE MigrationRuns
(
    MigUnitId INT NOT NULL
        REFERENCES MigrationUnits
        ON DELETE CASCADE,
    StartTime DATETIME2(0) NOT NULL,
    Processed BIT NOT NULL,
    Result VARCHAR(20) NOT NULL
       CHECK (Result IN ('started','success','failed','null','deleted')),
    Kind VARCHAR(10) NOT NULL
       Check (Kind IN ('real','fake')),
    MigrationType VARCHAR(10) NOT NULL
       Check (MigrationType IN ('first','delta','delete')),
    SGSessionId VARCHAR(20) NOT NULL,
    RunTimeInSec Numeric(12,4) NOT NULL,
    Details NVARCHAR(MAX),
    MigRunId INT IDENTITY(1,1) NOT NULL PRIMARY KEY
);
GO
