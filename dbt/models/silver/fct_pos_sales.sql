{{
  config(
    materialized='incremental',
    unique_key='pos_sale_sk',
    incremental_strategy='merge'
  )
}}

WITH pos AS (
    SELECT * FROM {{ ref('stg_retailer_pos') }}
    {% if is_incremental() %}
    WHERE loaded_at > (SELECT MAX(_loaded_at) FROM {{ this }})
    {% endif %}
),

stores AS (
    SELECT * FROM {{ source('ref', 'DIM_STORE') }}
),

products AS (
    SELECT * FROM {{ source('ref', 'DIM_PRODUCT') }}
    WHERE IS_CURRENT = TRUE
),

fx AS (
    SELECT * FROM {{ source('ref', 'DIM_FX_RATES') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['pos.RETAILER_CODE', 'st.STORE_KEY', 'pos.UPC', 'pos.TRANSACTION_DATE']) }} AS pos_sale_sk,
    pos.RETAILER_CODE,
    st.STORE_KEY,
    pos.UPC,
    pos.TRANSACTION_DATE,
    pos.UNITS_SOLD,
    pos.REVENUE,
    pos.REVENUE * COALESCE(fx.RATE_TO_USD, 1) AS revenue_usd,
    pos.UNITS_SOLD * COALESCE(p.UNIT_WEIGHT_KG, 0) AS kg_sold,
    pos.IS_PROMO AS promo_flag,
    p.BRAND,
    p.CATEGORY,
    pos.LOADED_AT AS _loaded_at
FROM pos
LEFT JOIN stores st
    ON pos.RETAILER_CODE = st.RETAILER_CODE
    AND pos.STORE_ID = st.STORE_ID
LEFT JOIN products p
    ON pos.UPC = p.UPC
LEFT JOIN fx
    ON fx.RATE_DATE = DATE_TRUNC('MONTH', pos.TRANSACTION_DATE)
    AND fx.CURRENCY_CODE = pos.CURRENCY_CODE
