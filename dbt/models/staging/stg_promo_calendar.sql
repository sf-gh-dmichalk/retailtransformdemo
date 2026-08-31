-- Staging view over promo calendar
SELECT
    PROMO_ID,
    PROMO_NAME,
    RETAILER_CODE,
    MATERIAL_NUMBER,
    TRY_TO_DATE(START_DATE) AS start_date,
    TRY_TO_DATE(END_DATE) AS end_date,
    PROMO_MECHANIC,
    TRY_TO_NUMBER(DISCOUNT_PCT, 5, 2) AS discount_pct,
    TRY_TO_NUMBER(TRADE_SPEND_USD, 18, 2) AS trade_spend_usd,
    _FILE_NAME AS source_file,
    _LOADED_AT AS loaded_at
FROM {{ source('raw', 'PROMO_CALENDAR') }}
