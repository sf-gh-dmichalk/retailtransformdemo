-------------------------------------------------------------------------------
-- dbt Model: silver.fct_pos_sales (INCREMENTAL)
-- Conformed POS sell-through fact at store/product/day grain
-- Joins bronze cleansed POS to product and store dimensions
-- Incremental: only processes rows newer than the last run
-------------------------------------------------------------------------------
-- {{ config(
--     materialized='incremental',
--     unique_key='pos_sale_sk',
--     cluster_by=['transaction_date', 'retailer_code'],
--     incremental_strategy='merge'
-- ) }}
-------------------------------------------------------------------------------

CREATE OR REPLACE TABLE SILVER.FCT_POS_SALES (
    POS_SALE_SK         VARCHAR(64)     NOT NULL,   -- surrogate key (hash)
    RETAILER_CODE       VARCHAR(20),
    STORE_KEY           NUMBER,
    UPC                 VARCHAR(14),
    TRANSACTION_DATE    DATE,
    UNITS_SOLD          NUMBER(18,0),
    REVENUE             NUMBER(18,2),
    REVENUE_USD         NUMBER(18,2),
    KG_SOLD             NUMBER(18,4),
    PROMO_FLAG          BOOLEAN,
    BRAND               VARCHAR(50),
    CATEGORY            VARCHAR(100),
    _LOADED_AT          TIMESTAMP_NTZ
)
CLUSTER BY (TRANSACTION_DATE, RETAILER_CODE);

-- The dbt model SQL (what dbt would compile and run):
-- INSERT INTO SILVER.FCT_POS_SALES
SELECT
    MD5(pos.RETAILER_CODE || '|' || pos.STORE_KEY || '|' || pos.UPC || '|' || pos.TRANSACTION_DATE)
                                                        AS POS_SALE_SK,
    pos.RETAILER_CODE,
    pos.STORE_KEY,
    pos.UPC,
    pos.TRANSACTION_DATE,
    pos.UNITS_SOLD,
    pos.REVENUE,
    pos.REVENUE_USD,
    pos.UNITS_SOLD * COALESCE(p.UNIT_WEIGHT_KG, 0)     AS KG_SOLD,
    pos.PROMO_FLAG,
    p.BRAND,
    p.CATEGORY,
    pos._LOADED_AT
FROM BRONZE.POS_CLEANSED pos
LEFT JOIN REF.DIM_PRODUCT p
    ON pos.UPC = p.UPC
    AND p.IS_CURRENT = TRUE
-- {% if is_incremental() %}
-- WHERE pos._LOADED_AT > (SELECT MAX(_LOADED_AT) FROM {{ this }})
-- {% endif %}
;
