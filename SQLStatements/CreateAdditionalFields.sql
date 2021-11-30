USE SGABUZ_Sharegate_Migration
GO
Alter TABLE MigrationRuns ADD MigrationType VARCHAR(10) NULL  Check (MigrationType IN ('first','delta','delete', NULL))
GO
EXEC sp_columns MigrationRuns;
GO