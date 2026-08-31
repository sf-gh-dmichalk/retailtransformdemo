-- Staging view over raw POS data with retailer-specific date normalization
SELECT
    RETAILER_CODE,
    STORE_ID,
    UPC,
    CASE RETAILER_CODE
        WHEN 'WMT' THEN TRY_TO_DATE(TRANSACTION_DATE, 'YYYY-MM-DD')
        WHEN 'KRO' THEN TRY_TO_DATE(TRANSACTION_DATE, 'MM/DD/YYYY')
        WHEN 'TGT' THEN TRY_TO_DATE(TRANSACTION_DATE, 'YYYYMMDD')
        ELSE TRY_TO_DATE(TRANSACTION_DATE)
    END AS transaction_date,
    TRY_TO_NUMBER(UNITS_SOLD) AS units_sold,
    TRY_TO_NUMBER(REVENUE, 18, 2) AS revenue,
    CURRENCY_CODE,
    PROMO_FLAG = 'Y' AS is_promo,
    _FILE_NAME AS source_file,
    _LOADED_AT AS loaded_at
FROM {{ source('raw', 'RETAILER_POS') }}
WHERE LENGTH(REGEXP_REPLACE(UPC, '[^0-9]', '')) IN (12, 13)
  AND TRY_TO_NUMBER(UNITS_SOLD) >= 0
