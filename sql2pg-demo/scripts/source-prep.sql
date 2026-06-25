-- Run against the SOURCE SQL Server database (the user database, e.g.):
--   sqlcmd -S <server>.database.windows.net -d <source-db> -U <admin> -P '<pwd>'
--
-- WHY: Ora2Pg's MSSQL data export issues `SELECT ... FROM [Table]` UNQUALIFIED
-- and relies on the connecting login's DEFAULT_SCHEMA to resolve it. The Azure
-- SQL server-admin login maps to dbo in every database, and dbo's default
-- schema is fixed to dbo and cannot be changed -- so an unqualified read misses
-- a SalesLT table and fails with "Invalid object name 'Address'".
--
-- Fix: a dedicated read login whose DEFAULT_SCHEMA is the source schema.

CREATE USER sl_reader WITH PASSWORD = '<SOURCE_PWD>';
ALTER USER sl_reader WITH DEFAULT_SCHEMA = SalesLT;
ALTER ROLE db_datareader ADD MEMBER sl_reader;   -- read all data
ALTER ROLE db_owner ADD MEMBER sl_reader; 
GRANT VIEW DEFINITION TO sl_reader;              -- read catalog/metadata
GO

-- (Demo shortcut, if you don't care about least privilege:
--   ALTER ROLE db_owner ADD MEMBER sl_reader;
--  but keep DEFAULT_SCHEMA = SalesLT regardless -- that's the part that fixes the read.)

-- Verify the unqualified name now resolves:
SELECT TOP 1 AddressID FROM Address;
GO
