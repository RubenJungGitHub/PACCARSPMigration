USE PACCARSQLO365
GO
Alter TABLE MigrationUNits ADD SourceRoot VARCHAR(400) NULL
GO
EXEC sp_columns MigrationUnits;
GO