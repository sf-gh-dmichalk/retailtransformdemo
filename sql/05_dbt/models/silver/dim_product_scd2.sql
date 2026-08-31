-------------------------------------------------------------------------------
-- dbt Model: silver.dim_product_scd2 (SCD Type 2)
-- Slowly-changing dimension for product attributes
-- Demonstrates: dbt snapshot-style logic for tracking product changes
-------------------------------------------------------------------------------
-- {{ config(
--     materialized='table',
--     post_hook="ALTER TABLE {{ this }} CLUSTER BY (brand, category)"
-- ) }}
-------------------------------------------------------------------------------
-- In practice this would be a dbt snapshot. Shown here as SQL for the demo.

CREATE OR REPLACE TABLE SILVER.DIM_PRODUCT_SCD2 (
    PRODUCT_SK          NUMBER AUTOINCREMENT,
    MATERIAL_NUMBER     VARCHAR(20)     NOT NULL,
    UPC                 VARCHAR(14),
    PRODUCT_NAME        VARCHAR(200),
    BRAND               VARCHAR(50),
    CATEGORY            VARCHAR(100),
    SUB_CATEGORY        VARCHAR(100),
    UNIT_WEIGHT_KG      NUMBER(10,4),
    PACK_SIZE           NUMBER(5,0),
    AVG_PRICE_PER_KG    NUMBER(10,2),
    -- SCD2 control columns
    EFFECTIVE_FROM      DATE            NOT NULL,
    EFFECTIVE_TO        DATE            DEFAULT '9999-12-31',
    IS_CURRENT          BOOLEAN         DEFAULT TRUE,
    _DBT_UPDATED_AT     TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- Full refresh from source
-- INSERT INTO SILVER.DIM_PRODUCT_SCD2
SELECT
    NULL AS PRODUCT_SK,  -- autoincrement
    MATERIAL_NUMBER,
    UPC,
    PRODUCT_NAME,
    BRAND,
    CATEGORY,
    SUB_CATEGORY,
    UNIT_WEIGHT_KG,
    PACK_SIZE,
    AVG_PRICE_PER_KG,
    EFFECTIVE_FROM,
    EFFECTIVE_TO,
    IS_CURRENT,
    CURRENT_TIMESTAMP()
FROM REF.DIM_PRODUCT;
