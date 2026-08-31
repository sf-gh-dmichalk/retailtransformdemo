-------------------------------------------------------------------------------
-- dbt Model: silver.fct_inventory (INCREMENTAL)
-- Unified inventory fact — daily store/product snapshots with availability
-------------------------------------------------------------------------------
-- {{ config(
--     materialized='incremental',
--     unique_key='inventory_sk',
--     incremental_strategy='merge'
-- ) }}
-------------------------------------------------------------------------------

CREATE OR REPLACE TABLE SILVER.FCT_INVENTORY (
    INVENTORY_SK        VARCHAR(64)     NOT NULL,
    RETAILER_CODE       VARCHAR(20),
    STORE_KEY           NUMBER,
    UPC                 VARCHAR(14),
    SNAPSHOT_DATE       DATE,
    ON_HAND_QTY         NUMBER(18,0),
    IN_TRANSIT_QTY      NUMBER(18,0),
    ON_ORDER_QTY        NUMBER(18,0),
    TOTAL_PIPELINE_QTY  NUMBER(18,0),
    _LOADED_AT          TIMESTAMP_NTZ
);

-- dbt compiled SQL:
-- INSERT INTO SILVER.FCT_INVENTORY
SELECT
    MD5(inv.RETAILER_CODE || '|' || inv.STORE_KEY || '|' || inv.UPC || '|' || inv.SNAPSHOT_DATE)
                                                    AS INVENTORY_SK,
    inv.RETAILER_CODE,
    inv.STORE_KEY,
    inv.UPC,
    inv.SNAPSHOT_DATE,
    inv.ON_HAND_QTY,
    inv.IN_TRANSIT_QTY,
    inv.ON_ORDER_QTY,
    inv.ON_HAND_QTY + inv.IN_TRANSIT_QTY + inv.ON_ORDER_QTY AS TOTAL_PIPELINE_QTY,
    inv._LOADED_AT
FROM BRONZE.INVENTORY_CLEANSED inv
-- {% if is_incremental() %}
-- WHERE inv._LOADED_AT > (SELECT MAX(_LOADED_AT) FROM {{ this }})
-- {% endif %}
;
