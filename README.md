# SQL Server to Azure Database for PostgreSQL Migration using ora2pg

This repository serves as a field-tested blueprint for migrating relational workloads from Microsoft SQL Server (targeting the `SalesLT` AdventureWorks dataset) to **Azure Database for PostgreSQL Flexible Server** using **Ora2Pg**. 

Designed to help field engineers execute clean, predictable migrations, this guide addresses known engine translation boundaries and bypasses common configuration traps.

---

## 🚀 Repository Structure

If you are setting this up from scratch, ensure your directory matches this structure:

```text
sql2pg-demo/
├── README.md
├── config/
│   └── sqlserver_to_postgres.conf
├── scripts/
│   └── install_vm.sh
└── sql/
    ├── views/
    │   ├── views.sql 

```

---

## 🛠️ Step-by-Step Execution Sequence

### Phase 1: Provision the VM Architecture
Deploy the hardened Ubuntu 24.04 base requirements, installing system paths along with standard SQL Server ODBC drivers.

```bash
chmod +x scripts/install_vm.sh
./scripts/install_vm.sh
```

### Phase 2: Pre-Migration Assessment
Validate catalog connectivity and generate the migration complexity and cost estimation matrix.

```bash
# Test catalog scanning visibility
ora2pg -M -t SHOW_TABLE -c sqlserver_to_postgres.conf

# Generate formal HTML effort matrix
ora2pg -M -t SHOW_REPORT -c sqlserver_to_postgres.conf --cost_unit_value 10 --dump_as_html --estimate_cost > migration_report.html
```

### Phase 3: Create Target Roles & Sequences
Create the target identity schema framework and deploy source sequences in dependency order.

```bash
# Create the necessary target user profile 
psql "host=<postgres-host> port=5432 dbname=<dbname> user=<username> sslmode=require" \
  -v ON_ERROR_STOP=1 -c "CREATE ROLE saleslt LOGIN PASSWORD '<password>';"

# Extract and apply relational Sequences
ora2pg -M -p -t SEQUENCE -o sequence.sql -b ./schema/sequences -c sqlserver_to_postgres.conf
psql "host=<postgres-host>  port=5432 dbname=<dbname> user=<username> sslmode=require" \
  -v ON_ERROR_STOP=1 -f ./schema/sequences/sequence.sql
```

### Phase 4: Structural DDL Export & Patching
Export the table structures to file, clean up known engine translation artifacts, and apply the DDL to the target.

```bash
# Export tables to disk
ora2pg -M -t TABLE -o table.sql -b ./schema/tables -c sqlserver_to_postgres.conf

# Patch invalid collation and encoding markers
sed -i 's/ COLLATE 0//g' ./schema/tables/table.sql
sed -i "s/client_encoding TO 'LATIN1'/client_encoding TO 'UTF8'/" ./schema/tables/table.sql

# Import cleaned base relations
psql "host=<postgres-host>  port=5432 dbname=<dbname> user=<username> sslmode=require" \
  -v ON_ERROR_STOP=1 -L ./schema/tables/import_tables.log -f ./schema/tables/table.sql
```

### Phase 5: Fast Bulk Data Loading
Stream data directly from SQL Server to Azure PostgreSQL. This utilizes the configuration's `PG_INITIAL_COMMAND` to safely bypass live foreign key evaluation order via replication roles.

```bash
# This streams directly to the target DSN; it does not require a manual psql execution pass
ora2pg -M -t COPY -o data.sql -b ./data -c sqlserver_to_postgres.conf
```

### Phase 6: Apply Hand-Ported Logical Views
Deploy the custom, optimized views (including the recursive CTE and XQuery/XPath conversions) that the automated engine could not natively translate.

```bash
for view_file in sql/views/*.sql; do
  psql "host=<postgres-host>  port=5432 dbname=<dbname> user=<username> sslmode=require" \
    -v ON_ERROR_STOP=1 -f "$view_file"
done
```

### Phase 7: Reconciliation Validation Testing
Execute an active schema and row count verification audit to guarantee data integrity across both database environments.

```bash
ora2pg -M -t TEST -c sqlserver_to_postgres.conf > validation_diff.txt
```

---

## 🧠 Field Engineering Notes & Known Workarounds

If you are adapting this toolkit for other migrations, be aware of these architectural boundaries:

1. **Configuration Trailing Comments:** Ora2Pg parses directives literally. Adding trailing comments (e.g., `TRUNCATE_TABLE 0 # clears target`) breaks evaluation logic. Comments *must* reside on separate lines.
2. **Command Line Flags Over Directives:** Forcing SQL Server parsing mode requires the `-M` (or `--mssql`) flag on the command line. Declaring `TYPE MSSQL` in the configuration file is structurally invalid.
3. **Source Connection Default Schema Isolation:** Ora2Pg's data extraction path issues unqualified queries (e.g., `SELECT ... FROM [Address]`). If the migration user defaults to the `dbo` schema, SQL Server misses the target object. A custom data reader (`sl_reader`) with an explicit `DEFAULT_SCHEMA = SalesLT` assignment must be provisioned on the source database.
4. **Procedural Code Translation Gaps:** Complex SQL Server schemas require manual engineering:
    * **Recursive CTEs** require the explicit `WITH RECURSIVE` declaration standard in Postgres.
    * **XQuery Schema Elements** (`.value()`) cannot be mapped dynamically. They must be explicitly rewritten using native PostgreSQL `xpath()` syntax, utilizing cross-joined arrays to safely map underlying XML namespaces.

---
