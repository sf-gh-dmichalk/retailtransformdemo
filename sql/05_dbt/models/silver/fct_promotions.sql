-------------------------------------------------------------------------------
-- dbt Model: silver.fct_promotions (TABLE materialization)
-- Conformed promotional fact — links promos to products/stores for lift analysis
-------------------------------------------------------------------------------
-- {{ config(
--     materialized='table'
-- ) }}
-------------------------------------------------------------------------------

CREATE OR REPLACE TABLE SILVER.FCT_PROMOTIONS (
    PROMO_ID            VARCHAR(30)     NOT NULL,
    PROMO_NAME          VARCHAR(200),
    RETAILER_CODE       VARCHAR(20),
    MATERIAL_NUMBER     VARCHAR(20),
    UPC                 VARCHAR(14),
    START_DATE          DATE,
    END_DATE            DATE,
    PROMO_MECHANIC      VARCHAR(50),
    DISCOUNT_PCT        NUMBER(5,2),
    TRADE_SPEND_USD     NUMBER(18,2),
    PROMO_DURATION_DAYS NUMBER(5,0),
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- dbt compiled SQL:
-- INSERT INTO SILVER.FCT_PROMOTIONS
SELECT
    pc.PROMO_ID,
    pc.PROMO_NAME,
    pc.RETAILER_CODE,
    pc.MATERIAL_NUMBER,
    p.UPC,
    TRY_TO_DATE(pc.START_DATE)                                  AS START_DATE,
    TRY_TO_DATE(pc.END_DATE)                                    AS END_DATE,
    pc.PROMO_MECHANIC,
    TRY_TO_NUMBER(pc.DISCOUNT_PCT, 5, 2)                        AS DISCOUNT_PCT,
    TRY_TO_NUMBER(pc.TRADE_SPEND_USD, 18, 2)                    AS TRADE_SPEND_USD,
    DATEDIFF('day', TRY_TO_DATE(pc.START_DATE), TRY_TO_DATE(pc.END_DATE)) + 1
                                                                 AS PROMO_DURATION_DAYS,
    CURRENT_TIMESTAMP()                                          AS _LOADED_AT
FROM RAW.PROMO_CALENDAR pc
LEFT JOIN REF.DIM_PRODUCT p
    ON pc.MATERIAL_NUMBER = p.MATERIAL_NUMBER
    AND p.IS_CURRENT = TRUE;
