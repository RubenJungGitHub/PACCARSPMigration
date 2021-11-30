INSERT INTO MigrationUnits
    (EnvironmentName, SourceUrl, DestinationUrl, ListUrl, ShareGateCopySettings, Scope, MUStatus, NodeId, NextAction, CreationTime)
VALUES
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '', '', 'site', 'new', 1, 'none', SYSDATETIME()),
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '/sites/input1/shared docs', '', 'list', 'notfound', 1, 'none', SYSDATETIME()),
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '/sites/input1/shared docs2', '', 'list', 'active', 1, 'first', SYSDATETIME()),
    ('o365', 'https://mock.sharepoint.com/sites/input1', 'https://mock.sharepoint.com/sites/M1-input1', '/sites/input1/shared docs3', '', 'list', 'active', 1, 'none', SYSDATETIME())
GO
