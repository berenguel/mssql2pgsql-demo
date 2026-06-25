-- Recursive category hierarchy.
-- T-SQL -> PostgreSQL: SQL Server's implicit recursive CTE must be declared
-- WITH RECURSIVE in PostgreSQL; SCHEMABINDING / SET / GO dropped; identifiers
-- lowercased and schema-qualified.
CREATE OR REPLACE VIEW saleslt.vgetallcategories AS
WITH RECURSIVE categorycte (parentproductcategoryid, productcategoryid, name) AS (
    SELECT parentproductcategoryid, productcategoryid, name
    FROM saleslt.productcategory
    WHERE parentproductcategoryid IS NULL
  UNION ALL
    SELECT c.parentproductcategoryid, c.productcategoryid, c.name
    FROM saleslt.productcategory AS c
    INNER JOIN categorycte AS bc ON bc.productcategoryid = c.parentproductcategoryid
)
SELECT pc.name AS parentproductcategoryname,
       ccte.name AS productcategoryname,
       ccte.productcategoryid
FROM categorycte AS ccte
JOIN saleslt.productcategory AS pc
  ON pc.productcategoryid = ccte.parentproductcategoryid;

-- Plain four-table join. In SQL Server this is WITH SCHEMABINDING (indexed-view
-- capable); reproduced here as a standard view. If the source view were actually
-- indexed, the faithful translation would be a MATERIALIZED VIEW + CREATE INDEX.
CREATE or replace VIEW saleslt.vproductanddescription AS
SELECT p.productid,
       p.name,
       pm.name AS productmodel,
       pmx.culture,
       pd.description
FROM saleslt.product AS p
INNER JOIN saleslt.productmodel AS pm
    ON p.productmodelid = pm.productmodelid
INNER JOIN saleslt.productmodelproductdescription AS pmx
    ON pm.productmodelid = pmx.productmodelid
INNER JOIN saleslt.productdescription AS pd
    ON pmx.productdescriptionid = pd.productdescriptionid;

-- The hard one: SQL Server XQuery (.value()) over an XML column.
-- No automatic Ora2Pg path -- hand-translated to PostgreSQL xpath().
--  - namespaces declared once in a CTE instead of per-call
--  - xpath('string((...)[1])', xmlcol, nsmap))[1]::text  ==  .value('(...)[1]','nvarchar')
--  - catalogdescription cast ::xml (it migrated as text under the all-text mapping)
-- Requires the catalogdescription column to contain well-formed XML.
CREATE or replace VIEW saleslt.vproductmodelcatalogdescription AS
WITH src AS (
    SELECT productmodelid, name, rowguid, modifieddate,
           catalogdescription::xml AS cd
    FROM saleslt.productmodel
    WHERE catalogdescription IS NOT NULL
),
ns AS (
    SELECT ARRAY[
        ARRAY['p1','http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription'],
        ARRAY['html','http://www.w3.org/1999/xhtml'],
        ARRAY['wm','http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain'],
        ARRAY['wf','http://www.adventure-works.com/schemas/OtherFeatures']
    ] AS map
)
SELECT
    s.productmodelid,
    s.name,
    (xpath('string((/p1:ProductDescription/p1:Summary/html:p)[1])', s.cd, ns.map))[1]::text                         AS summary,
    (xpath('string((/p1:ProductDescription/p1:Manufacturer/p1:Name)[1])', s.cd, ns.map))[1]::text                   AS manufacturer,
    (xpath('string((/p1:ProductDescription/p1:Manufacturer/p1:Copyright)[1])', s.cd, ns.map))[1]::text              AS copyright,
    (xpath('string((/p1:ProductDescription/p1:Manufacturer/p1:ProductURL)[1])', s.cd, ns.map))[1]::text             AS producturl,
    (xpath('string((/p1:ProductDescription/p1:Features/wm:Warranty/wm:WarrantyPeriod)[1])', s.cd, ns.map))[1]::text AS warrantyperiod,
    (xpath('string((/p1:ProductDescription/p1:Features/wm:Warranty/wm:Description)[1])', s.cd, ns.map))[1]::text    AS warrantydescription,
    (xpath('string((/p1:ProductDescription/p1:Features/wm:Maintenance/wm:NoOfYears)[1])', s.cd, ns.map))[1]::text   AS noofyears,
    (xpath('string((/p1:ProductDescription/p1:Features/wm:Maintenance/wm:Description)[1])', s.cd, ns.map))[1]::text AS maintenancedescription,
    (xpath('string((/p1:ProductDescription/p1:Features/wf:wheel)[1])', s.cd, ns.map))[1]::text                      AS wheel,
    (xpath('string((/p1:ProductDescription/p1:Features/wf:saddle)[1])', s.cd, ns.map))[1]::text                     AS saddle,
    (xpath('string((/p1:ProductDescription/p1:Features/wf:pedal)[1])', s.cd, ns.map))[1]::text                      AS pedal,
    (xpath('string((/p1:ProductDescription/p1:Features/wf:BikeFrame)[1])', s.cd, ns.map))[1]::text                  AS bikeframe,
    (xpath('string((/p1:ProductDescription/p1:Features/wf:crankset)[1])', s.cd, ns.map))[1]::text                   AS crankset,
    (xpath('string((/p1:ProductDescription/p1:Picture/p1:Angle)[1])', s.cd, ns.map))[1]::text                       AS pictureangle,
    (xpath('string((/p1:ProductDescription/p1:Picture/p1:Size)[1])', s.cd, ns.map))[1]::text                        AS picturesize,
    (xpath('string((/p1:ProductDescription/p1:Picture/p1:ProductPhotoID)[1])', s.cd, ns.map))[1]::text              AS productphotoid,
    (xpath('string((/p1:ProductDescription/p1:Specifications/Material)[1])', s.cd, ns.map))[1]::text                AS material,
    (xpath('string((/p1:ProductDescription/p1:Specifications/Color)[1])', s.cd, ns.map))[1]::text                   AS color,
    (xpath('string((/p1:ProductDescription/p1:Specifications/ProductLine)[1])', s.cd, ns.map))[1]::text             AS productline,
    (xpath('string((/p1:ProductDescription/p1:Specifications/Style)[1])', s.cd, ns.map))[1]::text                   AS style,
    (xpath('string((/p1:ProductDescription/p1:Specifications/RiderExperience)[1])', s.cd, ns.map))[1]::text         AS riderexperience,
    s.rowguid,
    s.modifieddate
FROM src s CROSS JOIN ns;

