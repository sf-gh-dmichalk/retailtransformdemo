{{
  config(
    materialized='table'
  )
}}

WITH promo AS (
    SELECT * FROM {{ ref('stg_promo_calendar') }}
),

products AS (
    SELECT * FROM {{ source('ref', 'DIM_PRODUCT') }}
    WHERE IS_CURRENT = TRUE
)

SELECT
    promo.PROMO_ID,
    promo.PROMO_NAME,
    promo.RETAILER_CODE,
    promo.MATERIAL_NUMBER,
    p.UPC,
    promo.START_DATE,
    promo.END_DATE,
    promo.PROMO_MECHANIC,
    promo.DISCOUNT_PCT,
    promo.TRADE_SPEND_USD,
    DATEDIFF('day', promo.START_DATE, promo.END_DATE) + 1 AS promo_duration_days
FROM promo
LEFT JOIN products p
    ON promo.MATERIAL_NUMBER = p.MATERIAL_NUMBER
