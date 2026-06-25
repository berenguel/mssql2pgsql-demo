-- Run against the TARGET PostgreSQL database (admin):
--   psql "host=<pg-host>.postgres.database.azure.com port=5432 dbname=postgres user=<pg-user> sslmode=require" -f sql/target-prep.sql
--
-- Drops any previous attempt and creates the owner role. The saleslt schema
-- itself is (re)created by the imported sequence.sql / table.sql, which then
-- run `ALTER SCHEMA saleslt OWNER TO saleslt` -- so the role must exist first.

DROP SCHEMA IF EXISTS saleslt CASCADE;
-- Create the owner role only if it isn't already there.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'saleslt') THEN
    CREATE ROLE saleslt LOGIN PASSWORD '<PG_ROLE_PWD>';
  END IF;
END$$;
